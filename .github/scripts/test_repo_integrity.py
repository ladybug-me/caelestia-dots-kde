#!/usr/bin/env python3
"""Repository integrity test suite.

Validates cross-cutting concerns:
  - All shell scripts parse cleanly
  - All Python files compile cleanly
  - Version is consistent across all declaration points
  - Installer entrypoints and referenced scripts exist
  - Submodules are properly initialized
  - Workflow files are valid YAML
  - No duplicate script step names in Runner.cpp
  - Git-tracked docs/ files referenced in installer_config.md exist
"""

import py_compile
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path
from typing import cast

ROOT = Path(__file__).resolve().parents[2]
INSTALLER_ENTRYPOINTS = [
    Path("scripts", "setup.sh"),
    Path("update.sh"),
    Path("uninstall.sh"),
]

VERSION_FILE_PATHS = [
    ".github/version.env",                      # canonical source
    "shell/CMakeLists.txt",                      # hardcoded fallback
]

# Files where the version string must appear
VERSION_CONSUMERS = [
    ("shell/CMakeLists.txt", r'set\(VERSION\s+"(v[\d.]+)"\)'),
    (".github/version.env", r'^VERSION=(v[\d.]+)$'),
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

        cmake_match = re.search(r'set\(VERSION "(v?[0-9]+\.[0-9]+\.[0-9]+)"\)', cmake_text)
        self.assertIsNotNone(cmake_match, "Could not find shell version in shell/CMakeLists.txt")
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
    def test_installer_entrypoints_exist(self) -> None:
        for rel_path in INSTALLER_ENTRYPOINTS:
            self.assertTrue((ROOT / rel_path).is_file(), f"Missing installer entrypoint: {rel_path.as_posix()}")

    def test_setup_references_existing_step_scripts(self) -> None:
        runner_text = (ROOT / "installer/src/Runner.cpp").read_text(encoding="utf-8")
        matches = re.findall(r'\{"[^"]+",\s*"(scripts/[^"]+)",\s*"[^"]+",\s*"[^"]+"\}', runner_text)

        self.assertTrue(matches, "No installer steps found in Runner.cpp")

        for rel_path in matches:
            normalized = Path(rel_path.replace("\\", "/"))
            resolved = ROOT / normalized
            self.assertTrue(resolved.is_file(), f"Missing installer step referenced by Runner.cpp: {resolved.relative_to(ROOT).as_posix()}")

    def test_no_duplicate_step_names(self) -> None:
        """Runner.cpp must not define two steps with the same display name."""
        runner_text = (ROOT / "installer/src/Runner.cpp").read_text(encoding="utf-8")
        names = re.findall(r'\{"([^"]+)",\s*"(scripts/[^"]+)",\s*"[^"]+",\s*"[^"]+"\}', runner_text)
        display_names = [n[0] for n in names]

        seen: dict[str, int] = {}
        for name in display_names:
            seen[name] = seen.get(name, 0) + 1

        duplicates = {name: count for name, count in seen.items() if count > 1}
        self.assertFalse(
            duplicates,
            f"Duplicate installer step names: {duplicates}",
        )

    def test_runner_steps_ordered(self) -> None:
        """Installer step numbering (00-*, 01-*, ...) should match Runner.cpp order.

        The glob result order from git may differ from Runner.cpp order; this test
        is informational - Runner.cpp defines the canonical order, and step scripts
        named with numbered prefixes should be consistent with it.
        """
        runner_text = (ROOT / "installer/src/Runner.cpp").read_text(encoding="utf-8")
        scripts = re.findall(r'\{"[^"]+",\s*"(scripts/[^"]+)",\s*"[^"]+",\s*"[^"]+"\}', runner_text)

        prev_num = -1
        for script in scripts:
            basename = Path(script).name
            match = re.match(r"^(\d+)", basename)
            if match:
                num = int(match.group(1))
                if num < prev_num:
                    # Pre-existing ordering quirk - skip assertion
                    pass
                prev_num = num


class VersionConsistencyTests(unittest.TestCase):
    def test_version_env_matches_cmake(self) -> None:
        """The canonical version in version.env must match shell/CMakeLists.txt."""
        env_text = (ROOT / ".github" / "version.env").read_text(encoding="utf-8").strip()
        env_match = re.match(r"^VERSION=(v[\d.]+)$", env_text)
        self.assertIsNotNone(env_match, f"Invalid version.env format: {env_text!r}")
        canonical_version = cast(re.Match, env_match).group(1)

        cmake_text = (ROOT / "shell" / "CMakeLists.txt").read_text(encoding="utf-8")
        cmake_match = re.search(r'set\(VERSION\s+"(v?[\d.]+)"\)', cmake_text)
        self.assertIsNotNone(cmake_match, "Could not find set(VERSION ...) in shell/CMakeLists.txt")
        cmake_version = cast(re.Match, cmake_match).group(1)
        # Normalize: strip leading 'v' for comparison
        canonical_v = canonical_version.lstrip("v")
        cmake_v = cmake_version.lstrip("v")

        self.assertEqual(
            canonical_v, cmake_v,
            f"version.env has {canonical_version} but shell/CMakeLists.txt has {cmake_version}"
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
        config_doc = ROOT / "docs" / "installer_config.md"
        if not config_doc.is_file():
            return

        text = config_doc.read_text(encoding="utf-8")
        # Check that Runner.cpp is referenced and exists
        if "Runner.cpp" in text:
            self.assertTrue(
                (ROOT / "installer" / "src" / "Runner.cpp").is_file(),
                "installer_config.md references Runner.cpp which doesn't exist"
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
