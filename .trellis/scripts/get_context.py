#!/usr/bin/env python3
"""Print Trellis project context for local AI workflow skills."""

from __future__ import annotations

import argparse
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional


# Directory name that marks the project root for Trellis workflows.
TRELLIS_DIR_NAME = ".trellis"

# Task metadata filename used by Trellis task directories.
TASK_FILE_NAME = "task.json"

# Candidate files that may store the current active task slug.
CURRENT_TASK_FILES = (
    Path(".trellis/current_task"),
    Path(".trellis/workspace/current_task"),
    Path(".trellis/workspace/current-task"),
)


@dataclass(frozen=True)
class SpecEntry:
    """Describe one discovered specification index."""

    # Human-readable package or scope name for this spec index.
    package: str
    # Human-readable layer name for this spec index.
    layer: str
    # Path relative to the project root, ready to pass to cat.
    path: Path
    # First Markdown heading found in the index file.
    title: str
    # Whether this entry is a shared guide instead of a package layer.
    is_guide: bool = False


@dataclass(frozen=True)
class TaskEntry:
    """Describe one Trellis task directory."""

    # Stable directory name used by Trellis scripts.
    slug: str
    # Display title read from task.json when present.
    title: str
    # Workflow status read from task.json when present.
    status: str
    # Path relative to the project root for direct inspection.
    path: Path


def find_project_root(start: Path) -> Path:
    """Return the nearest parent directory that contains .trellis."""
    current = start.resolve()
    for candidate in (current, *current.parents):
        if (candidate / TRELLIS_DIR_NAME).is_dir():
            return candidate
    return current


def relative_to_root(path: Path, root: Path) -> Path:
    """Return a stable display path relative to the project root."""
    try:
        return path.relative_to(root)
    except ValueError:
        return path


def run_git(root: Path, *args: str) -> str:
    """Run a read-only git command and return trimmed output."""
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def read_json(path: Path) -> dict:
    """Read a JSON object, returning an empty object when missing or invalid."""
    try:
        content = path.read_text(encoding="utf-8")
        data = json.loads(content)
    except (OSError, json.JSONDecodeError):
        return {}
    if isinstance(data, dict):
        return data
    return {}


def read_first_heading(path: Path) -> str:
    """Return the first Markdown heading from a file."""
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if stripped.startswith("#"):
                return stripped.lstrip("#").strip()
    except OSError:
        pass
    return path.parent.name


def discover_specs(root: Path) -> List[SpecEntry]:
    """Discover all .trellis/spec/**/index.md files."""
    spec_dir = root / TRELLIS_DIR_NAME / "spec"
    if not spec_dir.is_dir():
        return []

    entries: List[SpecEntry] = []
    for index_path in sorted(spec_dir.glob("**/index.md")):
        relative_spec_path = index_path.relative_to(spec_dir)
        parts = relative_spec_path.parts
        if not parts:
            continue

        # Shared guides are always read in addition to task-specific specs.
        if parts[0] == "guides":
            entries.append(
                SpecEntry(
                    package="shared",
                    layer="guides",
                    path=relative_to_root(index_path, root),
                    title=read_first_heading(index_path),
                    is_guide=True,
                )
            )
            continue

        # Support both spec/frontend/index.md and spec/<package>/<layer>/index.md.
        if len(parts) == 2:
            package = "project"
            layer = parts[0]
        else:
            package = parts[0]
            layer = "/".join(parts[1:-1])

        entries.append(
            SpecEntry(
                package=package,
                layer=layer,
                path=relative_to_root(index_path, root),
                title=read_first_heading(index_path),
            )
        )
    return entries


def find_current_task_slug(root: Path) -> Optional[str]:
    """Read the active task slug from known Trellis current-task files."""
    for relative_path in CURRENT_TASK_FILES:
        task_file = root / relative_path
        if not task_file.is_file():
            continue
        slug = task_file.read_text(encoding="utf-8").strip()
        if slug:
            return slug
    return None


def normalize_task_status(data: dict) -> str:
    """Return a concise status value from task metadata."""
    status = data.get("status") or data.get("phase") or "unknown"
    return str(status)


def task_from_dir(task_dir: Path, root: Path) -> TaskEntry:
    """Build a TaskEntry from a Trellis task directory."""
    data = read_json(task_dir / TASK_FILE_NAME)
    title = data.get("title") or data.get("name") or task_dir.name
    return TaskEntry(
        slug=task_dir.name,
        title=str(title),
        status=normalize_task_status(data),
        path=relative_to_root(task_dir, root),
    )


def discover_tasks(root: Path) -> List[TaskEntry]:
    """Discover task directories that contain task.json."""
    tasks_dir = root / TRELLIS_DIR_NAME / "tasks"
    if not tasks_dir.is_dir():
        return []
    tasks = [
        task_from_dir(path, root)
        for path in sorted(tasks_dir.iterdir())
        if path.is_dir() and (path / TASK_FILE_NAME).is_file()
    ]
    return tasks


def find_task_by_slug(tasks: Iterable[TaskEntry], slug: Optional[str]) -> Optional[TaskEntry]:
    """Return a task entry matching a slug or path value."""
    if not slug:
        return None
    normalized_slug = Path(slug).name
    for task in tasks:
        if task.slug == normalized_slug or str(task.path) == slug:
            return task
    return None


def print_specs(entries: List[SpecEntry]) -> None:
    """Print spec indexes in a compact workflow-friendly format."""
    package_entries = [entry for entry in entries if not entry.is_guide]
    guide_entries = [entry for entry in entries if entry.is_guide]

    print("Available Spec Packages")
    if package_entries:
        for entry in package_entries:
            print(f"- Package: {entry.package}")
            print(f"  Layer: {entry.layer}")
            print(f"  Index: {entry.path}")
            print(f"  Title: {entry.title}")
    else:
        print("- none")

    print()
    print("Shared Guides")
    if guide_entries:
        for entry in guide_entries:
            print(f"- Index: {entry.path}")
            print(f"  Title: {entry.title}")
    else:
        print("- none")


def print_tasks(tasks: List[TaskEntry], current_task: Optional[TaskEntry], current_slug: Optional[str]) -> None:
    """Print current and active Trellis tasks."""
    print("Current Task")
    if current_task:
        print(f"- {current_task.slug}: {current_task.title} [{current_task.status}]")
        print(f"  Path: {current_task.path}")
    elif current_slug:
        print(f"- {current_slug} (metadata not found)")
    else:
        print("- none")

    print()
    print("Active Tasks")
    if tasks:
        for task in tasks:
            marker = " (current)" if current_task and task.slug == current_task.slug else ""
            print(f"- {task.slug}: {task.title} [{task.status}]{marker}")
            print(f"  Path: {task.path}")
    else:
        print("- none")


def print_session_context(root: Path) -> None:
    """Print the default session context used by the start workflow."""
    tasks = discover_tasks(root)
    current_slug = find_current_task_slug(root)
    current_task = find_task_by_slug(tasks, current_slug)
    branch = run_git(root, "branch", "--show-current") or "unknown"
    status = run_git(root, "status", "--short")
    developer = run_git(root, "config", "user.name") or "unknown"

    print("Trellis Context")
    print(f"Project Root: {root}")
    print(f"Developer: {developer}")
    print(f"Git Branch: {branch}")
    print(f"Working Tree: {'dirty' if status else 'clean'}")
    if status:
        print("Changed Files:")
        for line in status.splitlines():
            print(f"- {line}")
    print()
    print_tasks(tasks, current_task, current_slug)
    print()
    print_specs(discover_specs(root))


def print_package_context(root: Path) -> None:
    """Print package and spec-layer context for pre-development checks."""
    print("Trellis Package Context")
    print(f"Project Root: {root}")
    print()
    print_specs(discover_specs(root))


def discover_workspace_journals(root: Path) -> List[Path]:
    """List known workspace journal files for record-session."""
    workspace_dir = root / TRELLIS_DIR_NAME / "workspace"
    if not workspace_dir.is_dir():
        return []
    return [
        relative_to_root(path, root)
        for path in sorted(workspace_dir.glob("*.md"))
        if path.is_file()
    ]


def print_record_context(root: Path) -> None:
    """Print context needed before recording completed work."""
    tasks = discover_tasks(root)
    current_slug = find_current_task_slug(root)
    current_task = find_task_by_slug(tasks, current_slug)
    branch = run_git(root, "branch", "--show-current") or "unknown"
    recent_commits = run_git(root, "log", "--oneline", "-5")
    status = run_git(root, "status", "--short")
    workspace_dir = root / TRELLIS_DIR_NAME / "workspace"

    print("Record Session Context")
    print(f"Project Root: {root}")
    print(f"Git Branch: {branch}")
    print(f"Working Tree: {'dirty' if status else 'clean'}")
    print()
    print_tasks(tasks, current_task, current_slug)
    print()
    print(f"Workspace Directory: {relative_to_root(workspace_dir, root)}")
    journals = discover_workspace_journals(root)
    print("Workspace Journals")
    if journals:
        for journal in journals:
            print(f"- {journal}")
    else:
        print("- none")
    print()
    print("Recent Commits")
    if recent_commits:
        for line in recent_commits.splitlines():
            print(f"- {line}")
    else:
        print("- none")


def build_parser() -> argparse.ArgumentParser:
    """Create the command line parser for context modes."""
    parser = argparse.ArgumentParser(
        description="Print Trellis project context for local workflow skills.",
    )
    parser.add_argument(
        "--mode",
        choices=("session", "packages", "record"),
        default="session",
        help="Context mode to print. Defaults to session.",
    )
    return parser


def main() -> int:
    """Dispatch the requested context mode."""
    parser = build_parser()
    args = parser.parse_args()
    root = find_project_root(Path.cwd())

    if args.mode == "packages":
        print_package_context(root)
    elif args.mode == "record":
        print_record_context(root)
    else:
        print_session_context(root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
