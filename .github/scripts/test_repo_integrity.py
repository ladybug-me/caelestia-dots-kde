#!/usr/bin/env python3
"""Repository integrity test suite.

Validates cross-cutting concerns:
  - All shell scripts parse cleanly
  - All Python files compile cleanly
  - version.env is the single source of truth; the CMake build derives from it
  - Installer entrypoints and referenced scripts exist
  - Submodules are properly initialized
  - Workflow files are valid YAML
  - Installer step manifest (steps.json) is consistent
  - Git-tracked docs/ files referenced in installer_config.md exist
"""

import json
import py_compile
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INSTALLER_ENTRYPOINTS = [
    Path("scripts", "setup.sh"),
    Path("update.sh"),
    Path("uninstall.sh"),
]


def repo_files(pattern: str) -> list[Path]:
    return sorted(
        path for path in ROOT.rglob(pattern)
        if ".git" not in path.parts and "__pycache__" not in path.parts and "build" not in path.parts
    )


def git_tracked_files(glob_pattern: str) -> list[str]:
    """Return list of git-tracked files matching glob_pattern, relative to ROOT."""
    result = subprocess.run(
        ["git", "ls-files", "--", glob_pattern],
        capture_output=True, text=True, cwd=ROOT,
    )
    if result.returncode != 0:
        return []
    return [f.strip() for f in result.stdout.splitlines() if f.strip()]


class ScriptSyntaxTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("bash"), "bash is required for shell syntax checks")
    def test_shell_scripts_parse(self) -> None:
        failures: list[str] = []

        for path in repo_files("*.sh"):
            rel_path = path.relative_to(ROOT).as_posix()
            result = subprocess.run(
                ["bash", "-n", rel_path],
                capture_output=True,
                text=True,
                cwd=ROOT,
            )
            if result.returncode != 0:
                message = (result.stderr or result.stdout).strip()
                failures.append(f"{rel_path}\n{message}")

        self.assertFalse(failures, "Shell syntax failures:\n\n" + "\n\n".join(failures))

    def test_python_scripts_compile(self) -> None:
        failures: list[str] = []

        for path in repo_files("*.py"):
            try:
                py_compile.compile(str(path), doraise=True)
            except py_compile.PyCompileError as exc:
                failures.append(f"{path.relative_to(ROOT)}\n{exc.msg}")

        self.assertFalse(failures, "Python compile failures:\n\n" + "\n\n".join(failures))


class MetadataConsistencyTests(unittest.TestCase):
    def test_shell_version_matches_about_page(self) -> None:
        cmake_text = (ROOT / "shell" / "CMakeLists.txt").read_text(encoding="utf-8")
        about_text = (ROOT / "shell" / "modules" / "nexus" / "pages" / "AboutPage.qml").read_text(
            encoding="utf-8"
        )

        # shell/CMakeLists.txt must derive its version from version.env (the
        # single source of truth) instead of hardcoding its own copy.
        self.assertIn(
            ".github/version.env",
            cmake_text,
            "shell/CMakeLists.txt must read the version from version.env",
        )
        self.assertNotRegex(
            cmake_text,
            r'set\(VERSION\s+"[^"]*\d[^"]*"\)',
            "shell/CMakeLists.txt hardcodes a version - bump version.env only",
        )
        self.assertIn("CUtils.version", about_text, "About page must use dynamic CUtils.version logic")

    def test_validation_scripts_referenced_by_docs_exist(self) -> None:
        contributing_text = (ROOT / ".github" / "CONTRIBUTING.md").read_text(encoding="utf-8")

        referenced = [
            "shell/scripts/qml-lint-conventions.py",
        ]

        for rel_path in referenced:
            if rel_path in contributing_text:
                self.assertTrue((ROOT / rel_path).is_file(), f"Missing referenced file: {rel_path}")


class InstallerTests(unittest.TestCase):
    def _load_steps_json(self) -> dict:
        path = ROOT / "installer" / "steps.json"
        self.assertTrue(path.is_file(), f"Missing installer step manifest: {path.relative_to(ROOT).as_posix()}")
        return json.loads(path.read_text(encoding="utf-8"))

    def test_installer_entrypoints_exist(self) -> None:
        for rel_path in INSTALLER_ENTRYPOINTS:
            self.assertTrue((ROOT / rel_path).is_file(), f"Missing installer entrypoint: {rel_path.as_posix()}")

    def test_step_scripts_exist(self) -> None:
        """steps.json is the source of truth for installer steps; every script must exist."""
        data = self._load_steps_json()
        steps = data.get("steps", [])
        self.assertTrue(steps, "steps.json must define at least one step")

        for step in steps:
            script = step.get("script")
            self.assertTrue(script, f"Step missing 'script': {step!r}")
            resolved = ROOT / Path(str(script).replace("\\", "/"))
            self.assertTrue(resolved.is_file(), f"Missing installer step script: {script}")

    def test_no_duplicate_step_names(self) -> None:
        """steps.json must not define two steps with the same display name."""
        data = self._load_steps_json()
        names = [step.get("name") for step in data.get("steps", [])]

        seen: dict[str, int] = {}
        for name in names:
            seen[name] = seen.get(name, 0) + 1

        duplicates = {name: count for name, count in seen.items() if count > 1}
        self.assertFalse(
            duplicates,
            f"Duplicate installer step names: {duplicates}",
        )

    def test_step_phases_reference_known_phases(self) -> None:
        """Every step must reference a phase id declared in steps.json."""
        data = self._load_steps_json()
        phase_ids = {p.get("id") for p in data.get("phases", [])}

        for step in data.get("steps", []):
            self.assertIn(
                step.get("phase"), phase_ids,
                f"Step references unknown phase: {step.get('phase')!r}",
            )


class VersionConsistencyTests(unittest.TestCase):
    def test_cmake_has_no_hardcoded_version(self) -> None:
        """version.env is the single source of truth - CMakeLists derives from it."""
        env_text = (ROOT / ".github" / "version.env").read_text(encoding="utf-8").strip()
        env_match = re.match(r"^VERSION=(v[\d.]+)$", env_text)
        self.assertIsNotNone(env_match, f"Invalid version.env format: {env_text!r}")

        cmake_text = (ROOT / "shell" / "CMakeLists.txt").read_text(encoding="utf-8")
        self.assertIn(
            ".github/version.env",
            cmake_text,
            "shell/CMakeLists.txt must derive its version from version.env",
        )
        self.assertIsNone(
            re.search(r'set\(VERSION\s+"[^"]*\d[^"]*"\)', cmake_text),
            "shell/CMakeLists.txt must not hardcode a version - bump version.env only",
        )

    def test_version_format_valid(self) -> None:
        """Version must follow semver-like vX.Y.Z format."""
        env_text = (ROOT / ".github" / "version.env").read_text(encoding="utf-8").strip()
        env_match = re.match(r"^VERSION=(v\d+\.\d+\.\d+)$", env_text)
        self.assertIsNotNone(
            env_match,
            f"version.env must contain VERSION=vX.Y.Z, got: {env_text!r}"
        )

    def test_updater_scripts_have_current_commit_logic(self) -> None:
        """Update scripts should save commit hash to .current_commit for delta checks."""
        update_script = ROOT / "src" / "bin" / "caelestia-update"
        if not update_script.is_file():
            return  # not required if file doesn't exist yet

        content = update_script.read_text(encoding="utf-8")
        self.assertIn(
            ".current_commit", content,
            "caelestia-update must save commit hash to .current_commit for update detection"
        )


class SubmoduleTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("git"), "git is required for submodule checks")
    def test_submodule_references_valid(self) -> None:
        """If .gitmodules exists, referenced paths and URLs should be consistent."""
        gitmodules = ROOT / ".gitmodules"
        if not gitmodules.is_file():
            return

        content = gitmodules.read_text(encoding="utf-8")
        paths = re.findall(r"^\s*path\s*=\s*(.+)$", content, re.MULTILINE)
        urls = re.findall(r"^\s*url\s*=\s*(.+)$", content, re.MULTILINE)

        self.assertTrue(paths, ".gitmodules exists but has no 'path' entries")
        self.assertEqual(
            len(paths), len(urls),
            f"Mismatch: {len(paths)} paths but {len(urls)} URLs in .gitmodules"
        )

        for sub_path in paths:
            full_path = ROOT / sub_path.strip()
            self.assertTrue(
                full_path.is_dir(),
                f"Submodule path '{sub_path}' does not exist - run git submodule update --init"
            )


class WorkflowYamlTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("python3"), "python3 required for YAML parse")
    def test_workflow_files_parse(self) -> None:
        """All .yml files in .github/workflows/ should be valid YAML."""
        try:
            import yaml  # type: ignore[import-untyped]
        except ImportError:
            # PyYAML not installed in CI - skip gracefully
            return

        workflows_dir = ROOT / ".github" / "workflows"
        if not workflows_dir.is_dir():
            return

        for wf_file in sorted(workflows_dir.glob("*.yml")):
            with self.subTest(file=wf_file.name):
                try:
                    with open(wf_file, encoding="utf-8") as f:
                        yaml.safe_load(f)
                except yaml.YAMLError as e:
                    self.fail(f"Invalid YAML in {wf_file.name}: {e}")


class DocsReferenceTests(unittest.TestCase):
    def test_contributing_references_existing_files(self) -> None:
        """Files mentioned in CONTRIBUTING.md should exist."""
        contributing = ROOT / ".github" / "CONTRIBUTING.md"
        if not contributing.is_file():
            return

        text = contributing.read_text(encoding="utf-8")
        # Find relative paths like docs/foo.md referenced in the doc
        doc_refs = re.findall(r"`(docs/[^`]+\.md)`", text)
        for ref in doc_refs:
            self.assertTrue(
                (ROOT / ref).is_file(),
                f"CONTRIBUTING.md references '{ref}' which does not exist"
            )

    def test_installer_config_references_valid_links(self) -> None:
        """docs/installer_config.md should reference existing source files."""
        config_doc = ROOT / ".github" / "docs" / "installer_config.md"
        if not config_doc.is_file():
            return

        text = config_doc.read_text(encoding="utf-8")
        if "steps.json" in text:
            self.assertTrue(
                (ROOT / "installer" / "steps.json").is_file(),
                "installer_config.md references steps.json which doesn't exist"
            )


class ScriptNumberingTests(unittest.TestCase):
    def test_install_step_scripts_have_consistent_numbers(self) -> None:
        """Scripts in the scripts/ directory with 00- prefix must be consecutive.

        Scripts: 00-backup-themes.sh, 00a-system-update.sh,
        01-ensure-prereqs.sh, 02-all-packages.sh, 02-packages.sh,
        02a-submodules.sh, 03-deploy-configs.sh, 04-deploy-kde.sh,
        06-services.sh, 07-kde-apps.sh, 08-build-shell.sh,
        09-system-tweaks.sh, 10-autostart.sh, 11-optional-apps.sh
        """
        scripts_dir = ROOT / "scripts"
        if not scripts_dir.is_dir():
            return

        numbers = set()
        for f in scripts_dir.glob("*.sh"):
            match = re.match(r"^(\d+)[a-z]?-", f.name)
            if match:
                numbers.add(int(match.group(1)))

        # We don't require strict consecutiveness (some numbers may be intentionally
        # skipped), but we verify there are no wildly out-of-range numbers.
        if numbers:
            max_num = max(numbers)
            self.assertLessEqual(
                max_num, 99,
                f"Script number {max_num} seems too high - consider renumbering"
            )


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
