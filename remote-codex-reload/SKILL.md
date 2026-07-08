---
name: remote-codex-reload
description: Use when the OpenAI/Codex VS Code extension over Remote SSH hangs on the logo, renders blank, shows broken styles, or makes the local VS Code window stop responding while the remote extension host and codex app-server are otherwise healthy.
---

# Remote Codex Reload

Use this skill to diagnose and apply the verified Webview workaround for the OpenAI/Codex VS Code extension when Remote SSH loads the panel but stalls in the startup logo.

## Required Intake

Before running any command, check whether the current user message explicitly includes:

- SSH target, such as an IP address, hostname, or SSH config alias.
- Proxy URL, or an explicit statement that no proxy is needed. The patch script does not use the proxy, but ask for it anyway so the operator has the full remote context before continuing.

If either value is missing, stop and ask the user for the missing value(s). Do not inspect history, infer a default host, read `~/.ssh/config`, or execute remote commands until the user replies. Use a concise question such as:

```text
请提供远程 SSH 目标（IP/主机名/SSH alias）以及代理 URL；如果不需要代理，请回复“无代理”。
```

## Root Cause Pattern

The failure is usually not the remote Codex backend. The remote OpenAI/Codex extension activates and starts `codex app-server`, but the local VS Code renderer freezes while loading Webview assets from the remote extension package.

Evidence that matches this pattern:

- VS Code Remote-SSH works, but the Codex panel stays on the logo or blank view.
- Remote logs show `openai.chatgpt` activation and `CodexMcpConnection Initialize received`.
- Local renderer logs show `loadResource` listener leak or the macOS window reports not responding.
- A no-preload test lets the Webview progress past the logo, but CSS link loading can still re-trigger the hang.

## Safe Workflow

1. Use only the SSH target and proxy URL supplied by the user in the current intake. Do not assume a host.
2. Confirm the remote OpenAI/Codex extension directory:

```bash
ssh <ssh-target> 'find ~/.vscode-server/extensions -maxdepth 1 -type d -name "openai.chatgpt-*-linux-*" | sort | tail -1'
```

3. Check logs before patching:

```bash
ssh <ssh-target> 'find ~/.vscode-server/data/logs -path "*openai.chatgpt/Codex.log" -type f -printf "%T@ %p\n" | sort -n | tail -3'
```

4. Apply the bundled patch script:

```bash
remote-codex-reload/scripts/patch_remote_codex_webview.sh <ssh-target>
```

5. Ask the user to reload the VS Code window or reconnect Remote-SSH, then open the Codex panel.

## What the Patch Does

- Backs up `webview/index.html`.
- Backs up `webview/assets/preload-helper-*.js`.
- Replaces the Vite preload helper with a no-op helper so startup does not issue bulk JS/CSS preload requests.
- Inlines `webview/assets/*.css` into `webview/index.html` before the main module script so CSS does not trigger the Remote Webview resource-loading path.
- Rewrites CSS `url(./...)` references to `url(./assets/...)` so fonts and images still resolve from the inlined CSS context.

## Revert

Use:

```bash
remote-codex-reload/scripts/patch_remote_codex_webview.sh --revert <ssh-target>
```

Revert before updating or reinstalling the extension if you need to compare against the upstream package.

## Important Notes

- This is a workaround for VS Code Remote Webview resource loading, not an upstream fix.
- Do not patch `/Applications/Visual Studio Code.app`; modifying the macOS app can break signing and quarantine checks.
- Disable local VS Code extension auto-update if the user wants the remote patch to survive routine use.
- Do not hard-code personal hosts, usernames, proxy URLs, or private repository paths in this skill.
