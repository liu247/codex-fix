#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: update_remote_codex.sh <ssh-target> [proxy-url]

Updates a remote Linux Codex CLI to the current local Codex App bundled version.
Set CODEX_REMOTE_VERSION to override version detection.
Set CODEX_APP_CODEX to override the local app codex path.
Example:
  update_remote_codex.sh 106.15.104.174 http://106.15.104.174:7901
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  usage
  exit $([[ $# -lt 1 ]] && echo 1 || echo 0)
fi

SSH_TARGET=$1
PROXY_URL=${2:-}
APP_CODEX=${CODEX_APP_CODEX:-/Applications/Codex.app/Contents/Resources/codex}

if [[ -n ${CODEX_REMOTE_VERSION:-} ]]; then
  VERSION=$CODEX_REMOTE_VERSION
elif [[ -x "$APP_CODEX" ]]; then
  VERSION=$("$APP_CODEX" --version | sed -n 's/.* \([0-9][0-9A-Za-z.+-]*\)$/\1/p' | head -n 1)
else
  echo "Could not find Codex App bundled CLI at $APP_CODEX. Set CODEX_REMOTE_VERSION or CODEX_APP_CODEX." >&2
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  echo "Could not determine target Codex CLI version." >&2
  exit 1
fi

REMOTE_ARCH=$(ssh "$SSH_TARGET" 'uname -m')
case "$REMOTE_ARCH" in
  x86_64|amd64) TARGET=x86_64-unknown-linux-musl ;;
  aarch64|arm64) TARGET=aarch64-unknown-linux-musl ;;
  *) echo "Unsupported remote architecture: $REMOTE_ARCH" >&2; exit 1 ;;
esac

ASSET="codex-package-${TARGET}.tar.gz"
BASE="https://github.com/openai/codex/releases/download/rust-v${VERSION}"
WORKDIR="${TMPDIR:-/tmp}/codex-remote-update-${VERSION}-${TARGET}"
mkdir -p "$WORKDIR"

printf 'target_version=%s\n' "$VERSION"
printf 'remote_arch=%s\n' "$REMOTE_ARCH"
printf 'target=%s\n' "$TARGET"

curl -fL "$BASE/codex-package_SHA256SUMS" -o "$WORKDIR/SHA256SUMS"
curl -fL "$BASE/$ASSET" -o "$WORKDIR/$ASSET"
(
  cd "$WORKDIR"
  grep "$ASSET" SHA256SUMS | shasum -a 256 -c -
)

REMOTE_TMP="/tmp/codex-update-${VERSION}-${TARGET}"
ssh "$SSH_TARGET" "mkdir -p '$REMOTE_TMP'"
scp "$WORKDIR/SHA256SUMS" "$WORKDIR/$ASSET" "$SSH_TARGET:$REMOTE_TMP/"

ssh "$SSH_TARGET" 'bash -s' -- "$VERSION" "$TARGET" "$REMOTE_TMP" "$ASSET" <<'REMOTE'
set -euo pipefail
VERSION=$1
TARGET=$2
REMOTE_TMP=$3
ASSET=$4
DEST="$HOME/.codex/packages/standalone/releases/${VERSION}-${TARGET}"
CURRENT="$HOME/.codex/packages/standalone/current"
VISIBLE="$HOME/.local/bin/codex"

cd "$REMOTE_TMP"
grep "$ASSET" SHA256SUMS | sha256sum -c -

mkdir -p "$HOME/.codex/packages/standalone/releases" "$HOME/.local/bin"
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  mv "$DEST" "${DEST}.bak.$(date +%Y%m%d%H%M%S)"
fi
mkdir -p "$DEST"
tar -xzf "$ASSET" -C "$DEST"
chmod 0755 "$DEST/bin/codex" "$DEST/codex-path/rg"
if [ -f "$DEST/codex-resources/bwrap" ]; then chmod 0755 "$DEST/codex-resources/bwrap"; fi
ln -sfn "$DEST" "$CURRENT"
ln -sfn "$CURRENT/bin/codex" "$VISIBLE"

CURRENT_CMD=$(command -v codex || true)
patch_path() {
  local path=$1
  [ -n "$path" ] || return 0
  case "$path" in
    "$HOME"/*)
      if [ -L "$path" ] || [ -f "$path" ]; then
        local backup="$path.npm-backup"
        if [ ! -e "$backup" ]; then mv "$path" "$backup"; else rm -f "$path"; fi
        ln -s "$CURRENT/bin/codex" "$path"
      fi
      ;;
  esac
}

patch_path "$CURRENT_CMD"
if [ -n "$CURRENT_CMD" ] && [ -L "$CURRENT_CMD" ]; then
  LINK_TARGET=$(readlink "$CURRENT_CMD" || true)
  case "$LINK_TARGET" in
    /*) ABS_TARGET="$LINK_TARGET" ;;
    *) ABS_TARGET="$(cd "$(dirname "$CURRENT_CMD")" && pwd)/$LINK_TARGET" ;;
  esac
  patch_path "$ABS_TARGET"
fi

hash -r
printf 'remote_command='; command -v codex
printf 'remote_paths:\n'; type -a codex || true
printf 'remote_version='; codex --version
REMOTE

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RECONNECTION_SCRIPT="$SCRIPT_DIR/../../remote-reconnection/scripts/fix_remote_reconnection.sh"
if [[ -x "$RECONNECTION_SCRIPT" ]]; then
  "$RECONNECTION_SCRIPT" "$SSH_TARGET" "$PROXY_URL"
elif [[ -n "$PROXY_URL" ]]; then
  echo "remote-reconnection script not found at $RECONNECTION_SCRIPT; skipping reconnection repair." >&2
fi
