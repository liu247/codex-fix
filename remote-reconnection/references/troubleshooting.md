# Remote Reconnection Troubleshooting Reference

Known failure pattern:

- Codex Desktop Remote connects over SSH, then chat stays on Thinking and cycles through Reconnecting.
- VS Code/Cursor Codex may still work because they run separate extension app-server processes.
- Desktop Remote uses a control socket such as `~/.codex/app-server-control/desktop-ssh-websocket-v0.sock`.
- Logs at `~/.codex/app-server-control/app-server.log` may show:
  - `app-server control socket is already in use`
  - `worker quit with fatal ... https://chatgpt.com/backend-api/wham/apps`
  - `failed to refresh available models: timeout waiting for child process to exit`

Network check:

```bash
curl -sS -o /tmp/wham.out \
  -w "http=%{http_code} type=%{content_type} time=%{time_total}\n" \
  --connect-timeout 10 --max-time 20 \
  https://chatgpt.com/backend-api/wham/apps
```

A proxy-mediated `405 application/json` response is acceptable and means the endpoint is reachable.

Proxy hygiene:

- If `.bashrc` prints `terminal proxy on`, gate output with `[ -t 1 ] && echo ...` to avoid protocol pollution.
- Make sure both long-lived listen and proxy processes inherit `http_proxy`/`https_proxy`.
