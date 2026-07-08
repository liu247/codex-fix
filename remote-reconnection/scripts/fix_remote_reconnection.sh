#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: fix_remote_reconnection.sh <ssh-target> [proxy-url]

Repairs Codex Desktop Remote reconnection loops on a remote Linux host.
Example:
  fix_remote_reconnection.sh my-remote-host http://127.0.0.1:7890
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  usage
  exit $([[ $# -lt 1 ]] && echo 1 || echo 0)
fi

SSH_TARGET=$1
PROXY_URL=${2:-}
SOCK_REL='.codex/app-server-control/desktop-ssh-websocket-v0.sock'

ssh "$SSH_TARGET" 'bash -s' -- "$PROXY_URL" "$SOCK_REL" <<'REMOTE'
set -euo pipefail
PROXY_URL=${1:-}
SOCK_REL=${2:-.codex/app-server-control/desktop-ssh-websocket-v0.sock}
SOCK="$HOME/$SOCK_REL"
CONTROL_DIR=$(dirname "$SOCK")
LOG="$CONTROL_DIR/app-server.log"
mkdir -p "$CONTROL_DIR"

collect_pids() {
  local pattern=$1
  ps -eo pid=,ppid=,args= | while read -r pid ppid args; do
    case "$args" in
      *"$pattern"*) printf '%s\n' "$pid" ;;
    esac
  done
}

LISTEN_PATTERN="codex app-server --listen unix://$SOCK"
PROXY_PATTERN="codex app-server proxy --sock $SOCK"
SHELL_PATTERN="codex app-server proxy --sock"

LISTEN_PIDS=$(collect_pids "$LISTEN_PATTERN" || true)
PROXY_PIDS=$(collect_pids "$PROXY_PATTERN" || true)
SHELL_PIDS=$(ps -eo pid=,ppid=,args= | while read -r pid ppid args; do
  case "$args" in
    *"/bin/sh -c"*"$SHELL_PATTERN"*"desktop-ssh-websocket-v0.sock"*) printf '%s\n' "$pid" ;;
  esac
done || true)

printf 'stopping_listen=%s\n' "${LISTEN_PIDS:-none}"
printf 'stopping_proxy=%s\n' "${PROXY_PIDS:-none}"
printf 'stopping_proxy_shell=%s\n' "${SHELL_PIDS:-none}"

for pids in "$LISTEN_PIDS" "$PROXY_PIDS" "$SHELL_PIDS"; do
  if [ -n "$pids" ]; then
    kill $pids 2>/dev/null || true
  fi
done
sleep 1
for pids in "$LISTEN_PIDS" "$PROXY_PIDS" "$SHELL_PIDS"; do
  if [ -n "$pids" ]; then
    for pid in $pids; do
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
      fi
    done
  fi
done

rm -f "$SOCK"
: > "$LOG"

ENV_ARGS=(PATH="$HOME/.local/bin:$HOME/node-v22.14.0-linux-x64/bin:$PATH")
if [ -n "$PROXY_URL" ]; then
  ENV_ARGS+=(http_proxy="$PROXY_URL" https_proxy="$PROXY_URL" HTTP_PROXY="$PROXY_URL" HTTPS_PROXY="$PROXY_URL")
fi

nohup env "${ENV_ARGS[@]}" codex app-server --listen "unix://$SOCK" >> "$LOG" 2>&1 &
NEW_PID=$!
sleep 1

printf 'new_listen_pid=%s\n' "$NEW_PID"
ps -p "$NEW_PID" -o pid,ppid,user,stat,etime,cmd
ls -l "$SOCK"
printf 'version='; codex --version

printf 'listen_env:\n'
tr '\0' '\n' < "/proc/$NEW_PID/environ" | grep -Ei '^(http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY|PATH)=' || true

if [ -n "$PROXY_URL" ]; then
  printf 'wham_test='
  http_proxy="$PROXY_URL" https_proxy="$PROXY_URL" curl -sS -o /tmp/codex-wham-apps.out -w 'http=%{http_code} type=%{content_type} time=%{time_total}\n' --connect-timeout 5 --max-time 15 https://chatgpt.com/backend-api/wham/apps || true
fi

sleep 5
printf 'log_bytes='
wc -c < "$LOG"
printf 'log_tail:\n'
tail -50 "$LOG" || true
printf 'active_desktop_processes:\n'
ps -eo pid,ppid,user,stat,etime,cmd | grep -E "codex app-server --listen unix://$SOCK|codex app-server proxy --sock $SOCK" | grep -v grep || true
REMOTE
