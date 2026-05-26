"""Regression tests for the Trellis context helper."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "get_context.py"


class GetContextScriptTest(unittest.TestCase):
    """Verify the project context helper stays compatible with workflow skills."""

    def setUp(self) -> None:
        """Create an isolated Trellis project fixture."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.project_dir = Path(self.temp_dir.name)
        spec_dir = self.project_dir / ".trellis" / "spec" / "frontend"
        guides_dir = self.project_dir / ".trellis" / "spec" / "guides"
        spec_dir.mkdir(parents=True)
        guides_dir.mkdir(parents=True)
        (spec_dir / "index.md").write_text(
            "# Frontend Spec Index\n\n## Pre-Development Checklist\n\n"
            "1. Read [TV Mode](tv-mode.md).\n",
            encoding="utf-8",
        )
        (guides_dir / "index.md").write_text("# Guides Index\n", encoding="utf-8")
        tasks_dir = self.project_dir / ".trellis" / "tasks" / "active-task"
        tasks_dir.mkdir(parents=True)
        (tasks_dir / "task.json").write_text(
            json.dumps({"title": "Active Task", "status": "in_progress"}),
            encoding="utf-8",
        )
        (self.project_dir / ".trellis" / "current_task").write_text(
            "active-task\n",
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        """Remove the isolated Trellis project fixture."""
        self.temp_dir.cleanup()

    def run_script(self, *args: str) -> subprocess.CompletedProcess[str]:
        """Run the context helper inside the fixture project."""
        return subprocess.run(
            [sys.executable, str(SCRIPT_PATH), *args],
            cwd=self.project_dir,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_packages_mode_lists_spec_layers_and_indexes(self) -> None:
        """Packages mode should expose spec indexes used by workflow skills."""
        result = self.run_script("--mode", "packages")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("frontend", result.stdout)
        self.assertIn(".trellis/spec/frontend/index.md", result.stdout)
        self.assertIn(".trellis/spec/guides/index.md", result.stdout)

    def test_default_mode_reports_current_task(self) -> None:
        """Default mode should show the current task and active task list."""
        result = self.run_script()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Current Task", result.stdout)
        self.assertIn("Active Task", result.stdout)
        self.assertIn("active-task", result.stdout)

    def test_record_mode_reports_journal_and_tasks(self) -> None:
        """Record mode should expose task and workspace journal context."""
        result = self.run_script("--mode", "record")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Record Session Context", result.stdout)
        self.assertIn("active-task", result.stdout)
        self.assertIn(".trellis/workspace", result.stdout)


if __name__ == "__main__":
    unittest.main()
