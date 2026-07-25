# Remote Reconnection Troubleshooting Reference

## Desktop Remote

Desktop Remote can use either of these user-owned control listeners:

- `~/.codex/app-server-control/app-server-control.sock`: the default listener selected by `codex app-server proxy` without `--sock`.
- `~/.codex/app-server-control/desktop-ssh-websocket-v0.sock`: the explicit Desktop SSH listener.

If a default listener survives a CLI update, it can retain an older binary and proxy environment while the explicit listener is current. Verify `/proc/<pid>/exe` and its proxy variables; restart both listeners together.

Expected network result through a supplied proxy:

```bash
curl -sS -o /tmp/wham.out \
  -w 'http=%{http_code} type=%{content_type} time=%{time_total}\n' \
  --connect-timeout 5 --max-time 15 \
  https://chatgpt.com/backend-api/wham/apps
```

`405 application/json` means the endpoint is reachable.

## VS Code Extension Only

If ChatGPT App Remote works but the VS Code OpenAI/Codex panel shows `Reconnecting`, inspect the extension log at:

```text
~/.vscode-server/data/logs/<session>/exthost*/openai.chatgpt/Codex.log
```

Relevant signatures:

- `failed to connect to websocket: ... Connection refused`
- `stream disconnected before completion`
- `tunnel error: failed to create underlying connection`

The extension's `codex app-server --analytics-default-enabled` is separate from Desktop Remote and must not be killed by generic repair. Inspect its `/proc/<pid>/environ`; conflicting lower- and upper-case proxy variables can route requests to different proxies.

When `~/.vscode-server/data/Machine/settings.json` has a stale `http.proxy` or `remote.SSH.*Proxy`, use `--sync-vscode-proxy`, then reload the VS Code window. The sync makes a timestamped backup before changing only the three proxy settings.

## Proxy Hygiene

- Always inject lower- and upper-case `http_proxy`/`https_proxy` values into long-lived app-server processes.
- A proxy's TCP connect success alone is insufficient; verify an HTTPS request reaches `wham/apps`.
- If shell startup prints status output, gate it with `[ -t 1 ]` to avoid protocol pollution.
