---
name: remote-reconnection
description: Use when Codex Desktop Remote SSH or the VS Code OpenAI/Codex extension repeatedly reconnects, remains on Thinking, reports stream disconnected, or has stale app-server sockets, proxy settings, or extension-host environment.
---

# Remote Reconnection

Repair Codex Remote failures by identifying which client owns the failing app-server before restarting anything. Desktop and the VS Code extension use separate remote processes.

## Required Intake

Before running a command, require both values in the current user message:

- SSH target.
- Proxy URL, or an explicit `无代理`.

Do not infer either value from history, SSH config, or defaults. If missing, ask:

```text
请提供远程 SSH 目标（IP/主机名/SSH alias）以及代理 URL；如果不需要代理，请回复“无代理”。
```

## Choose the Path

1. **Codex Desktop Remote fails**: run the repair script first.
2. **ChatGPT App remote works but VS Code fails**: inspect the VS Code extension process and its `Codex.log` before changing anything. If it contains `Connection refused`, `stream disconnected`, or proxy failures, run the repair script with `--sync-vscode-proxy`.
3. **Both fail**: run the repair script, then test `wham/apps` through the supplied proxy. A `405 application/json` response is successful reachability.

## Commands

```bash
remote-reconnection/scripts/fix_remote_reconnection.sh <ssh-target> [proxy-url]
```

For a VS Code-only failure:

```bash
remote-reconnection/scripts/fix_remote_reconnection.sh --sync-vscode-proxy <ssh-target> <proxy-url>
```

The script manages only user-owned Codex Remote listeners and proxy helpers:

- `~/.codex/app-server-control/app-server-control.sock` (the default control socket used by `codex app-server proxy` without `--sock`)
- `~/.codex/app-server-control/desktop-ssh-websocket-v0.sock`

It restarts both listeners with the supplied proxy in all four `http_proxy`/`https_proxy` cases. It does **not** stop VS Code, Cursor, Kiro, or editor extension app-servers such as `openai.chatgpt-.../codex app-server --analytics-default-enabled`.

With `--sync-vscode-proxy`, the script backs up and updates these remote VS Code Server settings only:

- `http.proxy`
- `remote.SSH.httpProxy`
- `remote.SSH.httpsProxy`

The running extension host retains its old environment. Tell the user to run `Developer: Reload Window` or reconnect Remote SSH, then create a new Codex conversation.

## Verification

Confirm all of the following before reporting success:

- Both control sockets are owned by current `codex` listeners.
- Listener environments contain the supplied proxy in lower- and upper-case variables.
- `wham/apps` through the proxy returns `405 application/json`.
- Listener logs remain empty after a brief wait.
- For VS Code, the new extension process no longer contains conflicting proxy values and `Codex.log` has no fresh `Connection refused` message.

## Guardrails

- Never use `pkill -f` from an SSH command that contains the target pattern.
- Never stop extension app-server processes as part of generic Desktop repair.
- Never overwrite VS Code proxy settings unless `--sync-vscode-proxy` was requested after a VS Code-specific diagnosis.
- Read [references/troubleshooting.md](references/troubleshooting.md) only for detailed signatures and recovery notes.
