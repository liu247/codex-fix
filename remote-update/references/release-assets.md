# Codex CLI Release Asset Notes

Standalone Linux release assets are expected under:

```text
https://github.com/openai/codex/releases/download/rust-v<VERSION>/codex-package_<not used>
https://github.com/openai/codex/releases/download/rust-v<VERSION>/codex-package_SHA256SUMS
https://github.com/openai/codex/releases/download/rust-v<VERSION>/codex-package-x86_64-unknown-linux-musl.tar.gz
https://github.com/openai/codex/releases/download/rust-v<VERSION>/codex-package-aarch64-unknown-linux-musl.tar.gz
```

The App bundled version can be newer than the local shell `codex`. Use:

```bash
/Applications/Codex.app/Contents/Resources/codex --version
```

The remote command may hit an old npm wrapper through `/usr/local/bin/codex`. If `/usr/local/bin/codex` is root-owned but points to a user-owned path, patch the user-owned target symlink instead of requiring sudo.
