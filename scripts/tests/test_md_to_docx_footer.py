"""Regression tests for configurable Markdown-to-DOCX footers."""

import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from docx import Document

ROOT = Path(__file__).resolve().parents[2]
CONVERTER = ROOT / "scripts" / "generate_styled_docx.py"


def footer_text(path):
    """Collect visible text from all section footers."""
    document = Document(path)
    return "\n".join(
        paragraph.text
        for section in document.sections
        for paragraph in section.footer.paragraphs
    )


class DocxFooterTests(unittest.TestCase):
    def convert(self, directory, footer=None):
        markdown = directory / "input.md"
        output = directory / "output.docx"
        markdown.write_text("# Footer test\n\nDocument body.\n", encoding="utf-8")
        command = [sys.executable, str(CONVERTER), str(markdown), "-o", str(output)]
        if footer is not None:
            command.extend(["--footer", footer])

        before = datetime.now(timezone.utc).date().isoformat()
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        after = datetime.now(timezone.utc).date().isoformat()

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertTrue(output.exists())
        return footer_text(output), {before, after}

    def test_custom_footer_is_used_verbatim(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            text, _ = self.convert(Path(temp_dir), "Architecture Team | Internal")
        self.assertEqual(text, "Architecture Team | Internal")

    def test_date_token_expands_in_custom_footer(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            text, possible_dates = self.convert(
                Path(temp_dir), "{date} | Architecture Team | Confidential"
            )
        self.assertIn(
            text,
            {f"{date} | Architecture Team | Confidential" for date in possible_dates},
        )

    def test_omitted_footer_uses_date_based_default(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            text, possible_dates = self.convert(Path(temp_dir))
        self.assertIn(text, {f"{date}  |  Confidential" for date in possible_dates})


class FooterInstructionTests(unittest.TestCase):
    def test_both_skill_variants_require_footer_preflight(self):
        paths = [
            ROOT / "skills" / "md-to-docx" / "SKILL.md",
            ROOT / "quick" / "md-to-docx" / "SKILL.md",
        ]
        for path in paths:
            with self.subTest(path=path):
                instructions = path.read_text(encoding="utf-8")
                self.assertIn("What should the footer say?", instructions)
                self.assertIn("Do not", instructions)
                self.assertIn("required preflight answers are available", instructions)
                self.assertIn("{date}", instructions)
                self.assertIn("default", instructions)

    def test_quick_footer_input_is_required(self):
        instructions = (ROOT / "quick" / "md-to-docx" / "SKILL.md").read_text(
            encoding="utf-8"
        )
        footer_input = instructions.split("  - name: footer", 1)[1].split(
            "  - name: margins", 1
        )[0]
        self.assertIn("required: true", footer_input)


if __name__ == "__main__":
    unittest.main()
