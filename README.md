# codex-fix

Codex skills for maintaining Codex Desktop Remote on Linux hosts.

## Skills

- `remote-reconnection`: diagnose and repair Codex Desktop Remote reconnection loops, stale sockets, duplicate app-server/proxy processes, and missing proxy environment.
- `remote-update`: update a remote Linux Codex CLI to the current local Codex App bundled version, then run the reconnection repair flow.

## Default Usage

```bash
remote-update/scripts/update_remote_codex.sh 106.15.104.174 http://106.15.104.174:7901
remote-reconnection/scripts/fix_remote_reconnection.sh 106.15.104.174 http://106.15.104.174:7901
```
