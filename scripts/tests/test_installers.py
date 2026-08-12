"""Regression tests for target-specific installation scripts."""

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SETUP = ROOT / "setup"
SKILL_NAMES = ("doc-fact-check", "md-to-docx", "stop-slop", "translate-pptx")
HANGUL = re.compile(r"[가-힣ㄱ-ㅎㅏ-ㅣ]")


class InstallerTests(unittest.TestCase):
    def run_setup(self, script, *args, home, extra_env=None):
        env = os.environ.copy()
        env["HOME"] = str(home)
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            ["bash", str(SETUP / script), *args],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def assert_kiro_install(self, home):
        skill_root = home / ".kiro" / "skills"
        for name in SKILL_NAMES:
            installed = skill_root / name
            self.assertTrue(installed.is_symlink(), installed)
            self.assertEqual(installed.resolve(), (ROOT / "skills" / name).resolve())
            self.assertTrue((installed / "SKILL.md").is_file())
        self.assertTrue(
            (skill_root / "md-to-docx" / "scripts" / "generate_styled_docx.py").is_file()
        )
        self.assertTrue(
            (skill_root / "translate-pptx" / "scripts" / "translate_pptx_native.py").is_file()
        )

    def test_link_kiro_installs_only_kiro_with_helpers(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            result = self.run_setup("link-kiro.sh", home=home)
            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
            self.assert_kiro_install(home)
            self.assertFalse((home / ".claude").exists())

            verify = self.run_setup("test-setup.sh", "--target", "kiro", home=home)
            self.assertEqual(verify.returncode, 0, verify.stderr or verify.stdout)

            wrong_target = self.run_setup("test-setup.sh", "--target", "claude", home=home)
            self.assertNotEqual(wrong_target.returncode, 0)
            self.assertIn("failed", wrong_target.stdout + wrong_target.stderr)

    def test_install_target_kiro_does_not_require_python_310_or_install_claude(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            result = self.run_setup("install.sh", "--target", "kiro", home=home)
            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
            self.assert_kiro_install(home)
            self.assertFalse((home / ".claude").exists())

    def test_quick_verifier_accepts_relative_reference_symlink(self):
        generated_helpers = (
            ROOT / "quick" / "md-to-docx" / "scripts" / "generate_styled_docx.py",
            ROOT / "quick" / "translate-pptx" / "scripts" / "translate_pptx_native.py",
        )
        existed = {path: path.exists() or path.is_symlink() for path in generated_helpers}
        try:
            with tempfile.TemporaryDirectory() as temp_dir:
                home = Path(temp_dir)
                install = self.run_setup("link-quick.sh", home=home)
                self.assertEqual(install.returncode, 0, install.stderr or install.stdout)

                references = home / ".quickwork" / "profiles" / "federate-prod" / "skills" / "stop-slop" / "references"
                self.assertTrue(references.is_symlink())
                self.assertFalse(os.readlink(references).startswith("/"))

                verify = self.run_setup("test-setup.sh", "--target", "quick", home=home)
                self.assertEqual(verify.returncode, 0, verify.stderr or verify.stdout)
        finally:
            for path in generated_helpers:
                if not existed[path] and path.is_symlink():
                    path.unlink()
                    try:
                        path.parent.rmdir()
                    except OSError:
                        pass

    def test_existing_directory_is_backed_up(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            existing = home / ".kiro" / "skills" / "md-to-docx"
            existing.mkdir(parents=True)
            marker = existing / "keep.txt"
            marker.write_text("preserve me")

            result = self.run_setup("link-kiro.sh", home=home)
            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
            backups = list(existing.parent.glob("md-to-docx.bak.*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual((backups[0] / "keep.txt").read_text(), "preserve me")
            self.assertTrue(existing.is_symlink())

    def test_cli_offline_mode_writes_all_documented_wrappers(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            bin_dir = home / "bin"
            env = {"DOC_SKILLS_BIN_DIR": str(bin_dir)}

            existing = bin_dir / "generate_styled_docx.py"
            existing.mkdir(parents=True)
            (existing / "keep.txt").write_text("preserve me")

            result = self.run_setup(
                "install-cli.sh",
                "--skip-dependencies",
                home=home,
                extra_env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
            for name in (
                "generate_styled_docx.py",
                "translate_pptx_native.py",
                "translate_pptx.py",
            ):
                wrapper = bin_dir / name
                self.assertTrue(wrapper.is_file(), wrapper)
                self.assertTrue(os.access(wrapper, os.X_OK), wrapper)
                self.assertTrue(wrapper.read_text().startswith("#!/usr/bin/env bash"))

            backups = list(bin_dir.glob("generate_styled_docx.py.bak.*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual((backups[0] / "keep.txt").read_text(), "preserve me")

            verify = self.run_setup(
                "test-setup.sh",
                "--target",
                "cli",
                home=home,
                extra_env=env,
            )
            self.assertEqual(verify.returncode, 0, verify.stderr or verify.stdout)

            second = self.run_setup(
                "install-cli.sh",
                "--skip-dependencies",
                home=home,
                extra_env=env,
            )
            self.assertEqual(second.returncode, 0, second.stderr or second.stdout)
            self.assertEqual(len(list(bin_dir.glob("translate_pptx.py.bak.*"))), 0)

    def test_uninstall_removes_only_selected_managed_agent_links(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            install = self.run_setup("link-kiro.sh", home=home)
            self.assertEqual(install.returncode, 0, install.stderr or install.stdout)

            backup = home / ".kiro" / "skills" / "keep.bak.1"
            backup.write_text("keep")
            uninstall = self.run_setup(
                "uninstall.sh",
                "--target",
                "kiro",
                "--yes",
                home=home,
            )
            self.assertEqual(uninstall.returncode, 0, uninstall.stderr or uninstall.stdout)
            for name in SKILL_NAMES:
                self.assertFalse((home / ".kiro" / "skills" / name).exists())
            self.assertEqual(backup.read_text(), "keep")
            self.assertTrue((ROOT / "skills" / "md-to-docx" / "SKILL.md").exists())

    def test_uninstall_preserves_foreign_skill_path(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            foreign = home / "foreign-skill"
            foreign.mkdir()
            target = home / ".kiro" / "skills" / "stop-slop"
            target.parent.mkdir(parents=True)
            target.symlink_to(foreign)

            uninstall = self.run_setup(
                "uninstall.sh",
                "--target",
                "kiro",
                "--yes",
                home=home,
            )
            self.assertNotEqual(uninstall.returncode, 0)
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), foreign.resolve())
            self.assertIn("PRESERVED", uninstall.stderr)

    def test_uninstall_removes_managed_cli_wrappers_and_marked_venv(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            bin_dir = home / "bin"
            venv_dir = home / "venv"
            env = {
                "DOC_SKILLS_BIN_DIR": str(bin_dir),
                "DOC_SKILLS_VENV_DIR": str(venv_dir),
            }
            install = self.run_setup(
                "install-cli.sh",
                "--skip-dependencies",
                home=home,
                extra_env=env,
            )
            self.assertEqual(install.returncode, 0, install.stderr or install.stdout)
            venv_dir.mkdir()
            (venv_dir / ".doc-skills-managed").write_text(
                "managed-by=doc-skills\nsource=test\n"
            )

            uninstall = self.run_setup(
                "uninstall.sh",
                "--target",
                "cli",
                "--remove-venv",
                "--yes",
                home=home,
                extra_env=env,
            )
            self.assertEqual(uninstall.returncode, 0, uninstall.stderr or uninstall.stdout)
            self.assertFalse(venv_dir.exists())
            for name in (
                "generate_styled_docx.py",
                "translate_pptx_native.py",
                "translate_pptx.py",
            ):
                self.assertFalse((bin_dir / name).exists())

    def test_uninstall_removes_legacy_venv_when_all_wrappers_prove_ownership(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            bin_dir = home / "bin"
            venv_dir = home / "venv"
            runtime_python = venv_dir / "bin" / "python"
            runtime_python.parent.mkdir(parents=True)
            runtime_python.write_text("")
            bin_dir.mkdir()
            scripts = {
                "generate_styled_docx.py": ROOT / "scripts" / "generate_styled_docx.py",
                "translate_pptx_native.py": ROOT / "scripts" / "translate_pptx_native.py",
                "translate_pptx.py": ROOT / "scripts" / "translate_pptx_cli.py",
            }
            for name, script in scripts.items():
                wrapper = bin_dir / name
                wrapper.write_text(
                    "#!/usr/bin/env bash\n"
                    f'exec {runtime_python} {script} "$@"\n'
                )
                wrapper.chmod(0o755)

            env = {
                "DOC_SKILLS_BIN_DIR": str(bin_dir),
                "DOC_SKILLS_VENV_DIR": str(venv_dir),
            }
            uninstall = self.run_setup(
                "uninstall.sh",
                "--target",
                "cli",
                "--remove-venv",
                "--yes",
                home=home,
                extra_env=env,
            )
            self.assertEqual(uninstall.returncode, 0, uninstall.stderr or uninstall.stdout)
            self.assertFalse(venv_dir.exists())

    def test_uninstall_preserves_unmarked_venv_and_requires_confirmation(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            venv_dir = home / "venv"
            venv_dir.mkdir()
            env = {"DOC_SKILLS_VENV_DIR": str(venv_dir)}

            no_confirmation = self.run_setup(
                "uninstall.sh",
                "--target",
                "cli",
                home=home,
                extra_env=env,
            )
            self.assertEqual(no_confirmation.returncode, 2)
            self.assertTrue(venv_dir.exists())

            uninstall = self.run_setup(
                "uninstall.sh",
                "--target",
                "cli",
                "--remove-venv",
                "--yes",
                home=home,
                extra_env=env,
            )
            self.assertNotEqual(uninstall.returncode, 0)
            self.assertTrue(venv_dir.exists())
            self.assertIn("PRESERVED", uninstall.stderr)

    def test_setup_scripts_are_english_only_and_parse_with_bash(self):
        for script in sorted(SETUP.glob("*.sh")):
            with self.subTest(script=script):
                text = script.read_text()
                self.assertIsNone(HANGUL.search(text), script)
                result = subprocess.run(
                    ["bash", "-n", str(script)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
