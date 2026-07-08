from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "delete_codex_session.py"


def run_script(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        check=False,
        text=True,
        capture_output=True,
    )


class DeleteCodexSessionTests(unittest.TestCase):
    def test_root_finds_rollout_prefixed_session_file_for_dry_run(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp_path = Path(raw_tmp)
            session_id = "019e5e37-c141-7932-95b9-92a4f09f01d8"
            session_file = (
                tmp_path
                / "2026"
                / "05"
                / "25"
                / f"rollout-2026-05-25T16-19-32-{session_id}.jsonl"
            )
            session_file.parent.mkdir(parents=True)
            session_file.write_text("{}", encoding="utf-8")

            result = run_script(session_id, "--root", str(tmp_path), "--dry-run")

            self.assertEqual(result.returncode, 0)
            self.assertIn(f"would delete: {session_file.resolve()}", result.stdout)
            self.assertTrue(session_file.exists())

    def test_scan_from_finds_nested_codex_sessions_for_dry_run(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp_path = Path(raw_tmp)
            session_id = "scan-session-001"
            session_file = (
                tmp_path
                / "project-a"
                / ".codex"
                / "sessions"
                / "2026"
                / "05"
                / "26"
                / f"{session_id}.jsonl"
            )
            session_file.parent.mkdir(parents=True)
            session_file.write_text("{}", encoding="utf-8")

            result = run_script(session_id, "--scan-from", str(tmp_path), "--dry-run")

            self.assertEqual(result.returncode, 0)
            self.assertIn(f"would delete: {session_file.resolve()}", result.stdout)
            self.assertTrue(session_file.exists())

    def test_scan_from_deletes_unique_nested_match(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp_path = Path(raw_tmp)
            session_id = "scan-session-002"
            session_file = (
                tmp_path
                / "project-b"
                / ".codex"
                / "sessions"
                / "2026"
                / "05"
                / "26"
                / f"{session_id}.jsonl"
            )
            session_file.parent.mkdir(parents=True)
            session_file.write_text("{}", encoding="utf-8")

            result = run_script(session_id, "--scan-from", str(tmp_path))

            self.assertEqual(result.returncode, 0)
            self.assertIn(f"deleted: {session_file.resolve()}", result.stdout)
            self.assertFalse(session_file.exists())

    def test_scan_from_refuses_multiple_nested_matches(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp_path = Path(raw_tmp)
            session_id = "scan-session-003"
            first = (
                tmp_path
                / "project-c"
                / ".codex"
                / "sessions"
                / "2026"
                / "05"
                / "26"
                / f"{session_id}.jsonl"
            )
            second = (
                tmp_path
                / "project-d"
                / ".codex"
                / "sessions"
                / "2026"
                / "05"
                / "26"
                / f"{session_id}.jsonl"
            )
            first.parent.mkdir(parents=True)
            second.parent.mkdir(parents=True)
            first.write_text("{}", encoding="utf-8")
            second.write_text("{}", encoding="utf-8")

            result = run_script(session_id, "--scan-from", str(tmp_path))

            self.assertEqual(result.returncode, 1)
            self.assertIn("multiple matching sessions found", result.stderr)
            self.assertTrue(first.exists())
            self.assertTrue(second.exists())


if __name__ == "__main__":
    unittest.main()
