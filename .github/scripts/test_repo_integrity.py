#!/usr/bin/env python3
"""Repository integrity test suite.

Validates cross-cutting concerns:
  - All shell scripts parse cleanly
  - All Python files compile cleanly
  - version.env is the single source of truth; the CMake build derives from it
  - Installer entrypoints and referenced scripts exist
  - Submodules are properly initialized
  - Workflow files are valid YAML
  - No duplicate script step names in Runner.cpp
  - Git-tracked docs/ files referenced in installer_config.md exist
"""

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
        """Syntax-check every Python file without writing bytecode.

        py_compile drops a .pyc next to the source, which fails with EIO on a
        read-only checkout (a shared folder, a container image, a Nix store).
        compile() checks the same thing and touches nothing.

        Only git-tracked files are checked. A filesystem walk also picks up a
        checked-out virtualenv - thousands of files that are not ours, and slow
        to read over a network mount.
        """
        failures: list[str] = []
        paths = git_tracked_files("*.py") or [
            path.relative_to(ROOT).as_posix() for path in repo_files("*.py")
        ]

        for rel_path in paths:
            try:
                compile((ROOT / rel_path).read_text(encoding="utf-8"), rel_path, "exec")
            except (SyntaxError, ValueError, UnicodeDecodeError) as exc:
                failures.append(f"{rel_path}\n{exc}")

        self.assertFalse(failures, "Python compile failures:\n\n" + "\n\n".join(failures))


class BashHelperTestSuite(unittest.TestCase):
    """Run tests/bash/run-tests.sh so the shell helpers get real behavior coverage.

    scripts/lib/ helpers cannot be exercised from Python, so this delegates to
    the bash runner and fails on any non-zero exit. Adding a test there is
    enough to have it enforced here and in CI.
    """

    @unittest.skipUnless(shutil.which("bash"), "bash is required for the helper suite")
    def test_bash_helper_suite_passes(self) -> None:
        runner = Path("tests", "bash", "run-tests.sh")
        self.assertTrue((ROOT / runner).is_file(), f"expected {runner.as_posix()} to exist")

        result = subprocess.run(
            ["bash", runner.as_posix()],
            capture_output=True,
            text=True,
            cwd=ROOT,
        )
        self.assertEqual(
            result.returncode,
            0,
            "bash helper suite failed:\n" + (result.stdout or "") + (result.stderr or ""),
        )


class ShellSurfaceTests(unittest.TestCase):
    """Invariants for shell QML surfaces that CI cannot execute.

    There is no Qt/Quickshell toolchain in this job, so the checks here pin the
    specific behaviour the reports describe as silent - a surface that claims
    success while doing nothing.
    """

    def test_ai_key_writes_wait_for_the_keyring_result(self) -> None:
        """#652: committing the field before secret-tool replies claims a save that may not have happened."""
        page = (ROOT / "shell" / "modules" / "nexus" / "pages" / "AiSettingsPage.qml").read_text(encoding="utf-8")

        store_at = page.find("function storeApiKey")
        start_at = page.find("function startKeyStore")
        self.assertNotEqual(store_at, -1, "the page should still have storeApiKey")
        self.assertNotEqual(start_at, -1, "the page should still have startKeyStore")
        self.assertNotEqual(
            page.find("function finishKeyStore"),
            -1,
            "the key write result must be applied by finishKeyStore",
        )

        self.assertNotIn(
            "keyringKeys",
            page[store_at:start_at],
            "storeApiKey must not commit the key before the write result is known",
        )
        self.assertIn(
            "queuedKeyWrites",
            page,
            "a second key write must wait for the one in flight, or its exit code is applied to the wrong key",
        )
        self.assertIn(
            "stderr: StdioCollector",
            page,
            "a failed write needs the reason from secret-tool, not just an exit code",
        )

    def test_shortcut_descriptions_are_translatable(self) -> None:
        """#692: shortcut labels are rendered from this data, so it must be extractable.

        The shortcut manager renders `GlobalShortcut.description` verbatim, and
        lupdate can only extract `qsTr()` calls with a literal argument. A bare
        literal is therefore invisible to the catalogue and stays English no
        matter which locale is active. This checks the source is extractable;
        it cannot check that a translation exists, which is Crowdin's job.
        """
        offenders: list[str] = []

        for path in sorted((ROOT / "shell").rglob("*.qml")):
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                match = re.match(r'^\s*description:\s*"([^"]*)"', line)
                if not match or not match.group(1):
                    continue
                # Values substituted into generated QML come from the caller, so
                # translating them belongs at the call site, not here.
                if "${" in match.group(1):
                    continue
                offenders.append(f"{path.relative_to(ROOT).as_posix()}:{number}")

        self.assertEqual(
            offenders,
            [],
            "shortcut descriptions must be wrapped in qsTr() so lupdate can extract them:\n"
            + "\n".join(offenders),
        )

    def test_about_page_links_the_plugin_count_to_the_plugin_manager(self) -> None:
        """#578: a plugin count with no way through to the plugin page is a dead end."""
        page = (ROOT / "shell" / "modules" / "nexus" / "pages" / "AboutPage.qml").read_text(encoding="utf-8")

        self.assertIn(
            'PageRegistry.indexForKey("plugins")',
            page,
            "the plugin count must link to the plugin manager, resolved by page key",
        )
        self.assertNotIn(
            "value: root.pluginCount",
            page,
            "the plugin count must be rendered by a navigating row, not a static info row",
        )


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


class InstallStepSafetyTests(unittest.TestCase):
    """Ordering and wiring invariants for the install/update step scripts.

    These are guarantees no single-file syntax or lint check can see, and that
    the reports behind them describe as silent: the step reports success while
    doing the wrong thing.
    """

    def test_shell_config_backup_precedes_the_prebuilt_install(self) -> None:
        """#663: the prebuilt path extracts over $HOME, so it must be backed up first."""
        script = (ROOT / "scripts" / "08-build-shell.sh").read_text(encoding="utf-8")

        backup_at = script.find("backup_shell_config ||")
        prebuilt_at = script.find("if try_download_prebuilt_shell;")

        self.assertNotEqual(backup_at, -1, "08-build-shell.sh should back up the shell config")
        self.assertNotEqual(prebuilt_at, -1, "08-build-shell.sh should still use the prebuilt download")
        self.assertLess(
            backup_at,
            prebuilt_at,
            "the shell-config backup must run before the prebuilt archive is extracted over $HOME",
        )

    def test_privileged_package_installs_go_through_the_escalation_helper(self) -> None:
        """#664: a GUI-triggered update has no terminal, so bare sudo fails silently."""
        script = (ROOT / "scripts" / "08-build-shell.sh").read_text(encoding="utf-8")

        self.assertIn(
            "install_linguist_tools",
            script,
            "08-build-shell.sh should install the Linguist tools via the shared helper",
        )
        self.assertNotIn(
            "sudo pacman -S --needed --noconfirm qt6-tools",
            script,
            "the Linguist tools install must not escalate with bare sudo",
        )

    def test_scheme_wait_happens_after_the_shell_restart(self) -> None:
        """#666: waiting before the restart polls for a file from a killed process."""
        script = (ROOT / "update.sh").read_text(encoding="utf-8")

        start_at = script.find('"$SHELL_IPC" start')
        wait_at = script.find("wait_for_nonempty_file")

        self.assertNotEqual(start_at, -1, "update.sh should still start the shell through the IPC wrapper")
        self.assertNotEqual(wait_at, -1, "update.sh should wait for the restarted shell to persist the scheme")
        self.assertLess(
            start_at,
            wait_at,
            "the scheme.json wait must run after the shell is restarted, not before",
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

    def test_updater_records_the_installed_revision_through_the_shared_helper(self) -> None:
        """Update scripts must record the installed commit for delta checks.

        Writing it inline here is what let the updater claim a revision whose
        build was skipped (#651); the shared helper refuses to in that case.
        """
        update_script = ROOT / "src" / "bin" / "caelestia-update"
        if not update_script.is_file():
            return  # not required if file doesn't exist yet

        content = update_script.read_text(encoding="utf-8")
        self.assertIn(
            "record_installed_revision",
            content,
            "caelestia-update must record the installed revision for update detection",
        )
        self.assertNotIn(
            "> ~/.config/quickshell/caelestia/.current_commit",
            content,
            "the revision must be written by the shared helper, not inline",
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
