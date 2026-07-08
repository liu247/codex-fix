#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: patch_remote_codex_webview.sh [--revert] <ssh-target> [extension-dir]

Patches the remote OpenAI/Codex VS Code extension Webview to avoid Remote SSH
resource-loading hangs by disabling Vite preload and inlining CSS.

Examples:
  patch_remote_codex_webview.sh my-remote-host
  patch_remote_codex_webview.sh --revert my-remote-host
  patch_remote_codex_webview.sh my-remote-host ~/.vscode-server/extensions/openai.chatgpt-<version>-linux-x64
USAGE
}

REVERT=0
if [[ ${1:-} == "--revert" ]]; then
  REVERT=1
  shift
fi

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  usage
  exit $([[ $# -lt 1 ]] && echo 1 || echo 0)
fi

SSH_TARGET=$1
EXT_DIR=${2:-}

ssh "$SSH_TARGET" 'bash -s' -- "$REVERT" "$EXT_DIR" <<'REMOTE'
set -euo pipefail

REVERT=$1
EXT_DIR=${2:-}
STAMP=remote-codex-reload

if [ -z "$EXT_DIR" ]; then
  EXT_DIR=$(find "$HOME/.vscode-server/extensions" -maxdepth 1 -type d -name 'openai.chatgpt-*-linux-*' | sort | tail -1)
fi

if [ -z "$EXT_DIR" ] || [ ! -d "$EXT_DIR" ]; then
  echo "OpenAI/Codex VS Code extension directory not found." >&2
  exit 1
fi

WEBVIEW="$EXT_DIR/webview"
INDEX="$WEBVIEW/index.html"

HELPER=$(find "$WEBVIEW/assets" -maxdepth 1 -type f -name 'preload-helper-*.js' | sort | head -1)
if [ -z "$HELPER" ] || [ ! -f "$HELPER" ]; then
  echo "preload-helper asset not found under $WEBVIEW/assets." >&2
  exit 1
fi

INDEX_BAK="$INDEX.bak-$STAMP"
HELPER_BAK="$HELPER.bak-$STAMP"

if [ "$REVERT" = "1" ]; then
  [ -f "$INDEX_BAK" ] || { echo "Missing backup: $INDEX_BAK" >&2; exit 1; }
  [ -f "$HELPER_BAK" ] || { echo "Missing backup: $HELPER_BAK" >&2; exit 1; }
  cp "$INDEX_BAK" "$INDEX"
  cp "$HELPER_BAK" "$HELPER"
  printf 'reverted_extension=%s\n' "$EXT_DIR"
  exit 0
fi

if [ ! -f "$INDEX_BAK" ]; then
  cp "$INDEX" "$INDEX_BAK"
fi
if [ ! -f "$HELPER_BAK" ]; then
  cp "$HELPER" "$HELPER_BAK"
fi

python3 - "$WEBVIEW" "$INDEX_BAK" "$INDEX" "$HELPER" <<'PY'
from pathlib import Path
import sys

webview = Path(sys.argv[1])
index_backup = Path(sys.argv[2])
index = Path(sys.argv[3])
helper = Path(sys.argv[4])

html = index_backup.read_text()
css_parts = []
for css_path in sorted((webview / "assets").glob("*.css")):
    css = css_path.read_text()
    css = css.replace("url(./", "url(./assets/")
    css_parts.append(f"\n/* {css_path.name} */\n{css}\n")

style = "\n<style id=\"codex-inline-css-remote-reload\">" + "\n".join(css_parts) + "</style>\n"
needle = '<script type="module" crossorigin src="./assets/index-DgDolWYM.js"></script>'
if needle not in html:
    import re
    match = re.search(r'<script type="module" crossorigin src="\./assets/index-[^"]+\.js"></script>', html)
    if not match:
        raise SystemExit("Could not find main module script tag in index.html")
    needle = match.group(0)

if "codex-inline-css-remote-reload" not in html:
    html = html.replace(needle, style + needle, 1)

index.write_text(html)
helper.write_text("var r=function(r,i,a){return r()};export{r as t};\n")
print(f"css_files={len(css_parts)}")
print(f"index_bytes={index.stat().st_size}")
print(f"helper_bytes={helper.stat().st_size}")
PY

printf 'patched_extension=%s\n' "$EXT_DIR"
printf 'index_backup=%s\n' "$INDEX_BAK"
printf 'helper_backup=%s\n' "$HELPER_BAK"
REMOTE
