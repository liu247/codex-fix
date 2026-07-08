# codex-fix

Codex skills for maintaining Codex Desktop Remote on Linux hosts.

## Skills

- `remote-reconnection`: diagnose and repair Codex Desktop Remote reconnection loops, stale sockets, duplicate app-server/proxy processes, and missing proxy environment.
- `remote-update`: update a remote Linux Codex CLI to the current local Codex App bundled version, then run the reconnection repair flow.
- `remote-codex-reload`: patch the remote OpenAI/Codex VS Code Webview when Remote SSH hangs on the Codex logo or renders blank.

## Default Usage

```bash
remote-update/scripts/update_remote_codex.sh <ssh-target> [proxy-url]
remote-reconnection/scripts/fix_remote_reconnection.sh <ssh-target> [proxy-url]
remote-codex-reload/scripts/patch_remote_codex_webview.sh <ssh-target>
```
