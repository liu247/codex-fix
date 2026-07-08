#!/usr/bin/env python3
"""Delete a local Codex session JSONL file by exact session ID."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys


def default_codex_home() -> Path:
    raw_home = os.environ.get("CODEX_HOME")
    if raw_home:
        return Path(raw_home).expanduser()
    return Path.home() / ".codex"


def default_sessions_root() -> Path:
    return default_codex_home() / "sessions"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Find and permanently delete a Codex session JSONL file by exact session ID."
    )
    parser.add_argument("session_id", nargs="?", help="Exact Codex session ID, without .jsonl")
    parser.add_argument(
        "--root",
        default=None,
        help="Codex sessions root. Defaults to $CODEX_HOME/sessions or ~/.codex/sessions.",
    )
    parser.add_argument(
        "--scan-from",
        default=None,
        help="Directory to scan for nested .codex/sessions roots.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show the matching file without deleting it.",
    )
    parser.add_argument(
        "--sessions-root",
        action="store_true",
        help="Print the default sessions root and exit.",
    )
    return parser.parse_args()


def validate_session_id(session_id: str) -> str:
    cleaned = session_id.strip()
    if not cleaned:
        raise ValueError("session ID must not be empty")
    if "/" in cleaned or "\\" in cleaned:
        raise ValueError("session ID must be a filename stem, not a path")
    if cleaned in {".", ".."}:
        raise ValueError("session ID must not be a relative path marker")
    if cleaned.endswith(".jsonl"):
        cleaned = cleaned[:-6]
    if not cleaned:
        raise ValueError("session ID must not be empty")
    return cleaned


def resolve_root(raw_root: str) -> Path:
    root = Path(raw_root).expanduser().resolve()
    if not root.exists():
        raise FileNotFoundError(f"sessions root does not exist: {root}")
    if not root.is_dir():
        raise NotADirectoryError(f"sessions root is not a directory: {root}")
    return root


def resolve_scan_root(raw_scan_root: str) -> Path:
    scan_root = Path(raw_scan_root).expanduser().resolve()
    if not scan_root.exists():
        raise FileNotFoundError(f"scan root does not exist: {scan_root}")
    if not scan_root.is_dir():
        raise NotADirectoryError(f"scan root is not a directory: {scan_root}")
    return scan_root


def find_sessions_roots(scan_root: Path) -> list[Path]:
    roots: set[Path] = set()
    if scan_root.name == "sessions" and scan_root.parent.name == ".codex":
        roots.add(scan_root)
    for path in scan_root.rglob("sessions"):
        if path.is_dir() and path.parent.name == ".codex":
            roots.add(path.resolve())
    return sorted(roots)


def find_matches(root: Path, session_id: str) -> list[Path]:
    exact_name = f"{session_id}.jsonl"
    suffix = f"-{session_id}.jsonl"
    return sorted(
        path
        for path in root.rglob("*.jsonl")
        if path.is_file() and (path.name == exact_name or path.name.endswith(suffix))
    )


def find_matches_in_roots(roots: list[Path], session_id: str) -> list[Path]:
    matches: list[Path] = []
    for root in roots:
        matches.extend(find_matches(root, session_id))
    return sorted(matches)


def ensure_inside_root(root: Path, path: Path) -> None:
    resolved = path.resolve()
    if root not in (resolved, *resolved.parents):
        raise ValueError(f"refusing to delete outside sessions root: {resolved}")


def ensure_inside_any_root(roots: list[Path], path: Path) -> None:
    for root in roots:
        try:
            ensure_inside_root(root, path)
        except ValueError:
            continue
        return
    raise ValueError(f"refusing to delete outside discovered sessions roots: {path.resolve()}")


def main() -> int:
    args = parse_args()
    if args.sessions_root:
        print(default_sessions_root())
        return 0

    if args.session_id is None:
        print("error: session_id is required", file=sys.stderr)
        return 2

    try:
        session_id = validate_session_id(args.session_id)
        if args.scan_from is not None:
            scan_root = resolve_scan_root(args.scan_from)
            roots = find_sessions_roots(scan_root)
            matches = find_matches_in_roots(roots, session_id)
        else:
            root = resolve_root(args.root or str(default_sessions_root()))
            roots = [root]
            matches = find_matches(root, session_id)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if not matches:
        print(f"not found: {session_id}")
        if args.scan_from is not None:
            print(f"scanned from: {scan_root}")
            if roots:
                print("searched sessions roots:")
                for root in roots:
                    print(root)
            else:
                print("searched sessions roots: none found")
        else:
            print(f"searched: {roots[0]}")
        return 1

    if len(matches) > 1:
        print(f"error: multiple matching sessions found for {session_id}", file=sys.stderr)
        for match in matches:
            print(match, file=sys.stderr)
        return 1

    match = matches[0]
    try:
        ensure_inside_any_root(roots, match)
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if args.dry_run:
        print(f"would delete: {match}")
        return 0

    try:
        match.unlink()
    except OSError as error:
        print(f"error: failed to delete {match}: {error}", file=sys.stderr)
        return 1

    print(f"deleted: {match}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
