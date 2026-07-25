#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: fix_remote_reconnection.sh [--sync-vscode-proxy] <ssh-target> [proxy-url]

Restarts user-owned Codex Remote control listeners. With --sync-vscode-proxy,
also updates the remote VS Code Server proxy settings after a VS Code-specific diagnosis.
USAGE
}

SYNC_VSCODE_PROXY=0
if [[ ${1:-} == '--sync-vscode-proxy' ]]; then
  SYNC_VSCODE_PROXY=1
  shift
fi

if [[ ${1:-} == '-h' || ${1:-} == '--help' || $# -lt 1 ]]; then
  usage
  exit $([[ $# -lt 1 ]] && echo 1 || echo 0)
fi

SSH_TARGET=$1
PROXY_URL=${2:-}

if [[ $SYNC_VSCODE_PROXY -eq 1 && -z $PROXY_URL ]]; then
  echo '--sync-vscode-proxy requires a proxy URL.' >&2
  exit 1
fi

ssh "$SSH_TARGET" 'bash -s' -- "$PROXY_URL" "$SYNC_VSCODE_PROXY" <<'REMOTE'
set -euo pipefail
PROXY_URL=${1:-}
SYNC_VSCODE_PROXY=$2
CONTROL_DIR="$HOME/.codex/app-server-control"
DEFAULT_SOCK="$CONTROL_DIR/app-server-control.sock"
DESKTOP_SOCK="$CONTROL_DIR/desktop-ssh-websocket-v0.sock"
DEFAULT_LOG="$CONTROL_DIR/app-server-default.log"
DESKTOP_LOG="$CONTROL_DIR/app-server.log"
mkdir -p "$CONTROL_DIR"

collect_pids() {
  local kind=$1
  ps -eo pid=,ppid=,args= | while read -r pid ppid args; do
    case "$kind:$args" in
      desktop-listen:*"codex app-server --listen unix://$DESKTOP_SOCK"*) printf '%s\n' "$pid" ;;
      default-listen:*"codex app-server --listen unix://") printf '%s\n' "$pid" ;;
      desktop-proxy:*"codex app-server proxy --sock $DESKTOP_SOCK"*) printf '%s\n' "$pid" ;;
      default-proxy:*"codex app-server proxy") printf '%s\n' "$pid" ;;
      proxy-shell:*"/bin/sh -c"*"codex app-server proxy"*) printf '%s\n' "$pid" ;;
    esac
  done
}

DEFAULT_LISTEN_PIDS=$(collect_pids default-listen || true)
DESKTOP_LISTEN_PIDS=$(collect_pids desktop-listen || true)
DEFAULT_PROXY_PIDS=$(collect_pids default-proxy || true)
DESKTOP_PROXY_PIDS=$(collect_pids desktop-proxy || true)
PROXY_SHELL_PIDS=$(collect_pids proxy-shell || true)

printf 'stopping_default_listen=%s\n' "${DEFAULT_LISTEN_PIDS:-none}"
printf 'stopping_desktop_listen=%s\n' "${DESKTOP_LISTEN_PIDS:-none}"
printf 'stopping_proxy=%s\n' "${DEFAULT_PROXY_PIDS:-none} ${DESKTOP_PROXY_PIDS:-none} ${PROXY_SHELL_PIDS:-none}"

for pids in "$DEFAULT_LISTEN_PIDS" "$DESKTOP_LISTEN_PIDS" "$DEFAULT_PROXY_PIDS" "$DESKTOP_PROXY_PIDS" "$PROXY_SHELL_PIDS"; do
  if [[ -n $pids ]]; then kill $pids 2>/dev/null || true; fi
done
sleep 1
for pids in "$DEFAULT_LISTEN_PIDS" "$DESKTOP_LISTEN_PIDS" "$DEFAULT_PROXY_PIDS" "$DESKTOP_PROXY_PIDS" "$PROXY_SHELL_PIDS"; do
  for pid in $pids; do
    if kill -0 "$pid" 2>/dev/null; then kill -9 "$pid" 2>/dev/null || true; fi
  done
done

rm -f "$DEFAULT_SOCK" "$DESKTOP_SOCK"
: > "$DEFAULT_LOG"
: > "$DESKTOP_LOG"

ENV_ARGS=(PATH="$HOME/.local/bin:$HOME/node-v22.14.0-linux-x64/bin:$PATH")
if [[ -n $PROXY_URL ]]; then
  ENV_ARGS+=(http_proxy="$PROXY_URL" https_proxy="$PROXY_URL" HTTP_PROXY="$PROXY_URL" HTTPS_PROXY="$PROXY_URL")
fi

nohup env "${ENV_ARGS[@]}" codex app-server --listen unix:// >> "$DEFAULT_LOG" 2>&1 &
DEFAULT_PID=$!
nohup env "${ENV_ARGS[@]}" codex app-server --listen "unix://$DESKTOP_SOCK" >> "$DESKTOP_LOG" 2>&1 &
DESKTOP_PID=$!
sleep 1

printf 'new_default_pid=%s\n' "$DEFAULT_PID"
printf 'new_desktop_pid=%s\n' "$DESKTOP_PID"
printf 'version='; codex --version
ls -l "$DEFAULT_SOCK" "$DESKTOP_SOCK"
printf 'default_env:\n'
tr '\0' '\n' < "/proc/$DEFAULT_PID/environ" | grep -Ei '^(http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY)=' || true
printf 'desktop_env:\n'
tr '\0' '\n' < "/proc/$DESKTOP_PID/environ" | grep -Ei '^(http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY)=' || true

if [[ $SYNC_VSCODE_PROXY -eq 1 ]]; then
  SETTINGS="$HOME/.vscode-server/data/Machine/settings.json"
  if [[ -f $SETTINGS ]]; then
    BACKUP="$SETTINGS.bak-proxy-$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS" "$BACKUP"
    node - "$SETTINGS" "$PROXY_URL" <<'NODE'
const fs = require('fs');
const [settingsPath, proxy] = process.argv.slice(2);
const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
settings['http.proxy'] = proxy;
settings['remote.SSH.httpProxy'] = proxy;
settings['remote.SSH.httpsProxy'] = proxy;
const temporary = `${settingsPath}.tmp-${process.pid}`;
fs.writeFileSync(temporary, `${JSON.stringify(settings, null, 2)}\n`, { mode: 0o600 });
fs.renameSync(temporary, settingsPath);
NODE
    printf 'vscode_proxy_backup=%s\n' "$BACKUP"
  else
    printf 'vscode_proxy_sync=skipped_settings_missing\n'
  fi
fi

if [[ -n $PROXY_URL ]]; then
  printf 'wham_test='
  http_proxy="$PROXY_URL" https_proxy="$PROXY_URL" curl -sS -o /tmp/codex-wham-apps.out -w 'http=%{http_code} type=%{content_type} time=%{time_total}\n' --connect-timeout 5 --max-time 15 https://chatgpt.com/backend-api/wham/apps || true
fi

sleep 5
printf 'default_log_bytes='; wc -c < "$DEFAULT_LOG"
printf 'desktop_log_bytes='; wc -c < "$DESKTOP_LOG"
printf 'active_remote_listeners:\n'
ps -p "$DEFAULT_PID","$DESKTOP_PID" -o pid,ppid,user,stat,etime,cmd
REMOTE
