---
name: remote-update
description: Update a remote Linux Codex CLI to match the current local Codex App bundled CLI version, especially for Codex Desktop Remote compatibility errors such as minimum CLI version required. Use when the user asks to check app version, update remote CLI, sync remote backend, fix remote after update, or resolve remote reconnection caused by a stale Codex CLI.
---

# Remote Update

Use this skill to update a remote Linux host's `codex` command to the current local Codex App bundled CLI version and then repair Desktop Remote reconnection.

## Workflow

1. Determine the local App bundled version:

```bash
/Applications/Codex.app/Contents/Resources/codex --version
```

2. Run the bundled updater:

```bash
remote-update/scripts/update_remote_codex.sh <ssh-target> [proxy-url]
```

Example:

```bash
remote-update/scripts/update_remote_codex.sh 106.15.104.174 http://106.15.104.174:7901
```

3. The updater should:
   - Detect the local App bundled `codex-cli` version unless `CODEX_REMOTE_VERSION` is explicitly set.
   - Detect remote CPU architecture with `uname -m`.
   - Download the matching `rust-v<version>` Linux package on the local machine.
   - Verify SHA256 using the release `codex-package_SHA256SUMS` file.
   - Copy the package to the remote host.
   - Install under `~/.codex/packages/standalone/releases/<version>-<target>`.
   - Update `~/.codex/packages/standalone/current` and `~/.local/bin/codex`.
   - Patch a home-owned wrapper path when `/usr/local/bin/codex` points through a user-owned Node/npm install.
   - Verify remote `codex --version`.
   - Invoke `remote-reconnection/scripts/fix_remote_reconnection.sh` when available and a proxy URL is provided.

## Constraints

- Do not use `npm install -g @openai/codex` for preview/alpha CLI updates; npm registry access may fail with 403 and old wrappers may not match Desktop Remote requirements.
- Do not rely on the remote host reaching GitHub release assets. If the remote host gets 504 from GitHub, download locally and `scp` the verified archive.
- If the local App bundled version has no public Linux release asset, stop and report that mismatch instead of installing another version silently.
- After updating, always run the reconnection repair or at least verify the Desktop app-server process inherited proxy settings.

## Coordination With Remote Reconnection

After a successful CLI update, use `$remote-reconnection` or run:

```bash
../remote-reconnection/scripts/fix_remote_reconnection.sh <ssh-target> [proxy-url]
```

This handles stale sockets, duplicate proxy processes, and missing proxy environment on the long-lived app-server.
