---
name: remote-reconnection
description: Diagnose and repair Codex Desktop Remote SSH reconnection loops for a remote Linux host. Use when Codex Desktop remote chat keeps reconnecting, gets stuck on Thinking, websocket closes, app-server proxy/listen processes are duplicated, the app-server socket is stale or already in use, or remote app-server logs show wham/apps, model refresh, transport channel, or proxy/network failures.
---

# Remote Reconnection

Use this skill to repair Codex Desktop Remote reconnection loops on a remote Linux host.

## Workflow

1. Identify the SSH target. Prefer the user's explicit host, otherwise inspect local `~/.ssh/config` and recent context. For this user's default host, use `106.15.104.174` as `net` on port `51` through the configured SSH alias.
2. Run the bundled repair script first:

```bash
remote-reconnection/scripts/fix_remote_reconnection.sh <ssh-target> [proxy-url]
```

Example:

```bash
remote-reconnection/scripts/fix_remote_reconnection.sh 106.15.104.174 http://106.15.104.174:7901
```

3. The script should stop only Codex Desktop Remote processes for the control socket:
   - `codex app-server --listen unix://.../desktop-ssh-websocket-v0.sock`
   - `codex app-server proxy --sock .../desktop-ssh-websocket-v0.sock`
   - parent shell wrappers that launch that proxy
4. Do not kill VS Code, Cursor, Kiro, or editor-extension app-server processes such as:
   - `.vscode-server/extensions/openai.chatgpt-.../codex app-server --analytics-default-enabled`
   - `.cursor-server/extensions/openai.chatgpt-.../codex app-server --analytics-default-enabled`
5. Verify the restarted `app-server --listen` process has proxy variables when a proxy URL is provided.
6. Verify `https://chatgpt.com/backend-api/wham/apps` through the proxy returns `405 application/json`. Treat that as success because the endpoint is reachable but rejects the method.
7. Truncate the remote Desktop app-server log after the fix and wait briefly. A zero-byte log after a few seconds is a good sign.
8. Tell the user to open a new remote chat if the old Desktop conversation still reconnects; old conversation state can be inconsistent after app-server restarts.

## Important Notes

- Avoid `pkill -f` from an SSH one-liner whose command line contains the same pattern. It can kill the remote shell running the repair.
- Prefer scripts sent over stdin (`ssh host 'bash -s'`) or the bundled script. The bundled script avoids matching its own process.
- If the long-lived `app-server --listen` lacks `http_proxy`/`https_proxy` while proxy processes have them, restart the listen process with explicit proxy environment.
- If logs show `app-server control socket is already in use`, stop duplicate listen processes, remove the stale socket, then start one listen process.
- If logs show `worker quit with fatal ... https://chatgpt.com/backend-api/wham/apps`, verify proxy reachability and restart with explicit proxy env.

## Reference

For the original incident notes and examples, read `references/troubleshooting.md` only when more detail is needed.
