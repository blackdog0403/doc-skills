#!/usr/bin/env python3
"""
Generate styled Word documents from markdown files.
AWS-branded styling: Calibri 11pt, AWS Orange (#FF9900) accents,
status badges, and clean table formatting.

Usage:
    python3 generate_styled_docx.py input.md [-o output.docx] [-l en|ko] [--footer "custom footer text"]
"""

import argparse
import os
import re
import sys
from datetime import date

from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_ALIGN_VERTICAL
from docx.oxml.ns import qn, nsdecls
from docx.oxml import parse_xml

# === Colors ===
AWS_ORANGE = "FF9900"
AWS_ORANGE_LIGHT = "FFF5E6"
DARK_GRAY = RGBColor(0x33, 0x33, 0x33)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
BADGE_HIGH = "DC3545"
BADGE_MEDIUM = "FF9900"
BADGE_LOW = "28A745"
BADGE_ON_ROADMAP = "0073BB"
BADGE_NOT_STARTED = "6C757D"
TABLE_HEADER_BG = "232F3E"  # AWS dark navy
TABLE_ALT_ROW = "F8F9FA"
CODE_BG = "F0F0F0"


# -- Helpers ------------------------------------------------------------------

def set_cell_shading(cell, color):
    shading = parse_xml(
        f'<w:shd {nsdecls("w")} w:fill="{color}" w:val="clear"/>'
    )
    cell._element.get_or_add_tcPr().append(shading)


def set_cell_borders(cell, top=None, bottom=None, left=None, right=None):
    tcPr = cell._element.get_or_add_tcPr()
    borders = tcPr.find(qn("w:tcBorders"))
    if borders is None:
        borders = parse_xml(f"<w:tcBorders {nsdecls('w')}/>")
        tcPr.append(borders)
    for side, val in [("top", top), ("bottom", bottom), ("left", left), ("right", right)]:
        if val:
            el = parse_xml(
                f'<w:{side} {nsdecls("w")} w:val="single" w:sz="{val[0]}" '
                f'w:space="0" w:color="{val[1]}"/>'
            )
            existing = borders.find(qn(f"w:{side}"))
            if existing is not None:
                borders.remove(existing)
            borders.append(el)


def add_paragraph_border(paragraph, side="bottom", sz="6", color=AWS_ORANGE, space="4"):
    pPr = paragraph._element.get_or_add_pPr()
    pBdr = parse_xml(
        f'<w:pBdr {nsdecls("w")}>'
        f'  <w:{side} w:val="single" w:sz="{sz}" w:space="{space}" w:color="{color}"/>'
        f'</w:pBdr>'
    )
    pPr.append(pBdr)


def add_run_shading(run, color):
    shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{color}" w:val="clear"/>')
    run._element.get_or_add_rPr().append(shading)


def set_paragraph_spacing(paragraph, before=None, after=None, line=None):
    pf = paragraph.paragraph_format
    if before is not None:
        pf.space_before = Pt(before)
    if after is not None:
        pf.space_after = Pt(after)
    if line is not None:
        pf.line_spacing = line


def set_table_full_width(tbl):
    """Set table to fill page width with proper cell margins."""
    tblPr = tbl._tbl.find(qn('w:tblPr'))
    if tblPr is None:
        tblPr = parse_xml(f'<w:tblPr {nsdecls("w")}/>')
        tbl._tbl.insert(0, tblPr)
    # Width 100%
    for tag in ('w:tblW', 'w:tblCellMar'):
        existing = tblPr.find(qn(tag))
        if existing is not None:
            tblPr.remove(existing)
    tblPr.append(parse_xml(
        f'<w:tblW {nsdecls("w")} w:type="pct" w:w="5000"/>'
    ))
    tblPr.append(parse_xml(
        f'<w:tblCellMar {nsdecls("w")}>'
        f'<w:top w:w="60" w:type="dxa"/>'
        f'<w:left w:w="120" w:type="dxa"/>'
        f'<w:bottom w:w="60" w:type="dxa"/>'
        f'<w:right w:w="120" w:type="dxa"/>'
        f'</w:tblCellMar>'
    ))


# -- Inline markdown rendering ------------------------------------------------

INLINE_RE = re.compile(
    r'(\*\*(.+?)\*\*)'       # group 1,2 = bold
    r'|(\*(.+?)\*)'          # group 3,4 = italic
    r'|(`(.+?)`)'            # group 5,6 = code
    r'|(\[(.+?)\]\((.+?)\))' # group 7,8,9 = link
    r'|(\^(\d+))'            # group 10,11 = footnote ref (^N)
)


def add_formatted_text(paragraph, text, base_size=11, base_bold=False,
                       base_color=DARK_GRAY, base_italic=False):
    """Render inline markdown (bold, italic, code, link, ^N footnote) into a paragraph."""
    pos = 0
    for m in INLINE_RE.finditer(text):
        if m.start() > pos:
            _plain_run(paragraph, text[pos:m.start()], base_size, base_bold,
                       base_color, base_italic)

        if m.group(1):  # **bold**
            r = paragraph.add_run(m.group(2))
            r.font.name = "Calibri"
            r.font.size = Pt(base_size)
            r.font.bold = True
            r.font.italic = base_italic
            r.font.color.rgb = base_color
        elif m.group(3):  # *italic*
            r = paragraph.add_run(m.group(4))
            r.font.name = "Calibri"
            r.font.size = Pt(base_size)
            r.font.italic = True
            r.font.color.rgb = base_color
        elif m.group(5):  # `code`
            r = paragraph.add_run(m.group(6))
            r.font.name = "Consolas"
            r.font.size = Pt(base_size - 1)
            r.font.color.rgb = RGBColor(0xC7, 0x25, 0x4E)
            add_run_shading(r, CODE_BG)
        elif m.group(7):  # [text](url)
            link_text = m.group(8)
            link_url = m.group(9)
            add_hyperlink(paragraph, link_text, link_url, font_size=base_size)
        elif m.group(10):  # ^N footnote reference
            r = paragraph.add_run(m.group(11))
            r.font.name = "Calibri"
            r.font.size = Pt(max(base_size - 2, 7))
            r.font.color.rgb = base_color
            r.font.superscript = True

        pos = m.end()

    if pos < len(text):
        _plain_run(paragraph, text[pos:], base_size, base_bold, base_color, base_italic)


def _plain_run(paragraph, text, size, bold, color, italic=False):
    r = paragraph.add_run(text)
    r.font.name = "Calibri"
    r.font.size = Pt(size)
    r.font.bold = bold
    r.font.italic = italic
    r.font.color.rgb = color


def add_hyperlink(paragraph, text, url, font_name="Calibri", font_size=11):
    """Add a clickable hyperlink to a paragraph."""
    from xml.sax.saxutils import escape as xml_escape
    from docx.opc.constants import RELATIONSHIP_TYPE as RT

    part = paragraph.part
    r_id = part.relate_to(url, RT.HYPERLINK, is_external=True)

    hyperlink = parse_xml(
        f'<w:hyperlink {nsdecls("w")} r:id="{r_id}" '
        f'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>'
    )

    sz_val = int(font_size * 2)
    escaped_text = xml_escape(text)
    new_run = parse_xml(
        f'<w:r {nsdecls("w")}>'
        f'<w:rPr>'
        f'<w:rFonts w:ascii="{font_name}" w:hAnsi="{font_name}"/>'
        f'<w:sz w:val="{sz_val}"/>'
        f'<w:color w:val="0073BB"/>'
        f'<w:u w:val="single"/>'
        f'</w:rPr>'
        f'<w:t xml:space="preserve">{escaped_text}</w:t>'
        f'</w:r>'
    )
    hyperlink.append(new_run)
    paragraph._element.append(hyperlink)


def add_badge(paragraph, label, bg_color):
    """Insert a small coloured badge (pill) inline."""
    r = paragraph.add_run(f"  {label}  ")
    r.font.name = "Calibri"
    r.font.size = Pt(8)
    r.font.bold = True
    r.font.color.rgb = WHITE
    add_run_shading(r, bg_color)
    paragraph.add_run(" ")


# -- Badge rules --------------------------------------------------------------

BADGE_RULES_EN = {
    "on the roadmap": ("ON ROADMAP", BADGE_ON_ROADMAP),
    "on our roadmap": ("ON ROADMAP", BADGE_ON_ROADMAP),
    "not today": ("NOT TODAY", BADGE_NOT_STARTED),
    "not directly": ("LIMITED", BADGE_NOT_STARTED),
    "cannot": ("LIMITATION", BADGE_NOT_STARTED),
}

BADGE_RULES_KO = {
    "로드맵에 있": ("ON ROADMAP", BADGE_ON_ROADMAP),
    "로드맵": ("ON ROADMAP", BADGE_ON_ROADMAP),
    "현재는 미지원": ("NOT TODAY", BADGE_NOT_STARTED),
    "현재는 불가": ("NOT TODAY", BADGE_NOT_STARTED),
    "직접적으로는 불가": ("LIMITED", BADGE_NOT_STARTED),
    "접근 불가": ("LIMITATION", BADGE_NOT_STARTED),
}

PRIORITY_BADGE = {
    "High": BADGE_HIGH, "높음": BADGE_HIGH,
    "Medium": BADGE_MEDIUM, "중간": BADGE_MEDIUM,
    "Low": BADGE_LOW, "낮음": BADGE_LOW,
}


# -- Document builder ---------------------------------------------------------

class StyledDocxBuilder:
    def __init__(self, lang="en", footer_text=None):
        self.doc = Document()
        self.lang = lang
        self.footer_text = footer_text
        self.badge_rules = BADGE_RULES_EN if lang == "en" else BADGE_RULES_KO
        self.footnotes = {}
        self.extra_notes = []
        self._setup_styles()

    def _setup_styles(self):
        style = self.doc.styles["Normal"]
        style.font.name = "Calibri"
        style.font.size = Pt(11)
        style.font.color.rgb = DARK_GRAY
        pf = style.paragraph_format
        pf.space_after = Pt(6)
        pf.line_spacing = 1.15

        for section in self.doc.sections:
            section.top_margin = Cm(2.54)
            section.bottom_margin = Cm(2.54)
            section.left_margin = Cm(2.54)
            section.right_margin = Cm(2.54)

        sizes = {1: 22, 2: 15, 3: 12}
        befores = {1: 0, 2: 18, 3: 12}
        afters = {1: 6, 2: 6, 3: 4}
        for lvl in (1, 2, 3):
            hs = self.doc.styles[f"Heading {lvl}"]
            hs.font.name = "Calibri"
            hs.font.size = Pt(sizes[lvl])
            hs.font.bold = True
            hs.font.color.rgb = DARK_GRAY
            hs.paragraph_format.space_before = Pt(befores[lvl])
            hs.paragraph_format.space_after = Pt(afters[lvl])

    # -- public API -----------------------------------------------------------

    def build(self, md_path, out_path):
        with open(md_path, encoding="utf-8") as f:
            lines = f.read().splitlines()
        self.footnotes, self.extra_notes, skip_lines = self._extract_footnotes(lines)
        i = 0
        in_code_block = False
        code_block_lines = []
        code_block_lang = ""
        while i < len(lines):
            if i in skip_lines:
                i += 1
                continue
            line = lines[i]

            # -- Fenced code block handling --
            fence_m = re.match(r"^(`{3,})(.*)?$", line.strip())
            if fence_m:
                if not in_code_block:
                    in_code_block = True
                    code_block_lang = (fence_m.group(2) or "").strip()
                    code_block_lines = []
                    i += 1
                    continue
                else:
                    # End of code block — render it
                    self._render_code_block(code_block_lines, code_block_lang)
                    in_code_block = False
                    code_block_lines = []
                    code_block_lang = ""
                    i += 1
                    continue

            if in_code_block:
                code_block_lines.append(line)
                i += 1
                continue

            # render horizontal rules as thin separator
            if re.match(r"^---+$", line.strip()):
                self._render_horizontal_rule()
                i += 1
                continue

            # -- Heading --
            hm = re.match(r"^(#{1,6})\s+(.+)$", line)
            if hm:
                level = len(hm.group(1))
                text = hm.group(2)
                # H4-H6: render as bold paragraph (python-docx only supports H1-H3 natively)
                if level <= 3:
                    p = self.doc.add_heading(level=level)
                    p.clear()
                    size = {1: 22, 2: 15, 3: 12}[level]
                    add_formatted_text(p, text, base_size=size,
                                       base_bold=True, base_color=DARK_GRAY)
                    if level == 1:
                        add_paragraph_border(p, sz="8", color=AWS_ORANGE, space="6")
                    elif level == 2:
                        add_paragraph_border(p)
                else:
                    p = self.doc.add_paragraph()
                    size = {4: 11, 5: 11, 6: 10}.get(level, 11)
                    add_formatted_text(p, text, base_size=size,
                                       base_bold=True, base_color=DARK_GRAY)
                    set_paragraph_spacing(p, before=10, after=4)
                i += 1
                continue

            # -- Blockquote block --
            if line.startswith(">"):
                bq_lines = []
                while i < len(lines) and lines[i].startswith(">"):
                    bq_lines.append(re.sub(r"^>\s?", "", lines[i]))
                    i += 1
                joined = " ".join(bq_lines)
                if "Key Takeaways" in joined or "핵심 요약" in joined:
                    self._render_key_takeaways(bq_lines)
                elif self._is_footer_metadata(bq_lines):
                    self._render_footer_metadata(bq_lines)
                else:
                    self._render_blockquote(bq_lines)
                continue

            # -- Table --
            if "|" in line and i + 1 < len(lines) and re.match(r"^\|[\s\-:|]+\|$", lines[i + 1].strip()):
                table_lines = []
                while i < len(lines) and "|" in lines[i]:
                    table_lines.append(lines[i])
                    i += 1
                self._render_table(table_lines)
                continue

            # -- Numbered list --
            nm = re.match(r"^(\d+)\.\s+(.+)$", line)
            if nm:
                items = []
                while i < len(lines):
                    nm2 = re.match(r"^(\d+)\.\s+(.+)$", lines[i])
                    if nm2:
                        items.append(lines[i])
                        i += 1
                    elif lines[i].startswith("   "):
                        items.append(lines[i])
                        i += 1
                    else:
                        break
                self._render_numbered_list(items)
                continue

            # -- Bullet list --
            bm = re.match(r"^(\s*)- (.+)$", line)
            if bm:
                items = []
                while i < len(lines):
                    bm2 = re.match(r"^(\s*)- (.+)$", lines[i])
                    if bm2:
                        items.append((len(bm2.group(1)) // 2, bm2.group(2)))
                        i += 1
                    else:
                        break
                self._render_bullet_list(items)
                continue

            # -- Metadata lines (Author, Date, Attendees) --
            meta_m = re.match(r"^\*\*(.+?):\*\*\s*(.+)$", line)
            if meta_m:
                p = self.doc.add_paragraph()
                set_paragraph_spacing(p, before=0, after=2)
                r = p.add_run(f"{meta_m.group(1)}: ")
                r.font.name = "Calibri"
                r.font.size = Pt(10)
                r.font.bold = True
                r.font.color.rgb = RGBColor(0x66, 0x66, 0x66)
                add_formatted_text(p, meta_m.group(2), base_size=10,
                                   base_color=RGBColor(0x66, 0x66, 0x66))
                i += 1
                continue

            # -- Normal paragraph --
            if line.strip():
                p = self.doc.add_paragraph()
                add_formatted_text(p, line)
                self._maybe_add_badge(p, line)
                i += 1
                continue

            # blank line
            i += 1

        # -- Endnotes + Footer --
        self._render_endnotes()
        self._add_footer()
        self.doc.save(out_path)
        print(f"  -> {out_path}")

    def _extract_footnotes(self, lines):
        """Scan for '**Notes:**' / 'Notes:' sections and extract footnote defs.

        Returns ({n: text}, [extra unnumbered notes], set of line indices to skip).
        Only matches exact 'Notes:' headers — 'Important Notes:' etc. are left alone.
        Consumes the whole Notes block (contiguous bullets + blank lines) until a
        non-bullet, non-blank line — so bullets without a ^N prefix still get lifted
        into the endnotes block instead of being rendered as body.
        """
        footnotes = {}
        extras = []
        skip = set()
        header_re = re.compile(r'^\s*(?:\*\*Notes:\*\*|Notes:)\s*$')
        num_item_re = re.compile(
            r'^\s*-\s+\*\*\^(\d+)(?:\s+([^:*]+?))?:?\*\*\s*(.*)$'
        )
        bullet_re = re.compile(r'^\s*-\s+(.+)$')
        i = 0
        while i < len(lines):
            if header_re.match(lines[i]):
                block_indices = [i]
                j = i + 1
                found_any = False
                while j < len(lines):
                    mm = num_item_re.match(lines[j])
                    if mm:
                        n = int(mm.group(1))
                        label = (mm.group(2) or "").strip()
                        body = mm.group(3).strip()
                        footnotes[n] = f"{label}: {body}" if label else body
                        block_indices.append(j)
                        found_any = True
                        j += 1
                        continue
                    bm = bullet_re.match(lines[j])
                    if bm:
                        extras.append(bm.group(1).strip())
                        block_indices.append(j)
                        found_any = True
                        j += 1
                        continue
                    if lines[j].strip() == "":
                        block_indices.append(j)
                        j += 1
                        continue
                    break
                if found_any:
                    skip.update(block_indices)
                    i = j
                    continue
            i += 1
        return footnotes, extras, skip

    def _render_endnotes(self):
        """Render extracted footnotes as a styled endnotes block at document end."""
        if not self.footnotes and not self.extra_notes:
            return

        gray = RGBColor(0x66, 0x66, 0x66)

        p = self.doc.add_paragraph()
        set_paragraph_spacing(p, before=18, after=4)
        add_paragraph_border(p, side="top", sz="4", color="D0D0D0", space="6")

        for n in sorted(self.footnotes):
            p = self.doc.add_paragraph()
            set_paragraph_spacing(p, before=1, after=1)
            r = p.add_run(str(n))
            r.font.name = "Calibri"
            r.font.size = Pt(8)
            r.font.superscript = True
            r.font.color.rgb = gray
            p.add_run(" ").font.size = Pt(9)
            add_formatted_text(p, self.footnotes[n], base_size=9,
                               base_color=gray, base_italic=True)

        for note in self.extra_notes:
            p = self.doc.add_paragraph()
            set_paragraph_spacing(p, before=1, after=1)
            r = p.add_run("  •  ")
            r.font.name = "Calibri"
            r.font.size = Pt(9)
            r.font.color.rgb = gray
            add_formatted_text(p, note, base_size=9,
                               base_color=gray, base_italic=True)

    # -- Renderers ------------------------------------------------------------

    def _render_key_takeaways(self, bq_lines):
        """Render Key Takeaways as an AWS-orange accented box using a 1-cell table."""
        tbl = self.doc.add_table(rows=1, cols=1)
        tbl.alignment = 1  # center
        set_table_full_width(tbl)
        cell = tbl.cell(0, 0)

        set_cell_borders(cell,
                         left=("24", AWS_ORANGE),
                         top=("4", "E0E0E0"),
                         bottom=("4", "E0E0E0"),
                         right=("4", "E0E0E0"))
        set_cell_shading(cell, AWS_ORANGE_LIGHT)
        cell.paragraphs[0].clear()

        first = True
        for line in bq_lines:
            line = line.strip()
            if not line:
                continue

            # Title line
            if "Key Takeaways" in line or "핵심 요약" in line:
                p = cell.paragraphs[0] if first else cell.add_paragraph()
                first = False
                title = "Key Takeaways" if self.lang == "en" else "핵심 요약"
                r = p.add_run(title)
                r.font.name = "Calibri"
                r.font.size = Pt(13)
                r.font.bold = True
                r.font.color.rgb = RGBColor(0xFF, 0x99, 0x00)
                set_paragraph_spacing(p, before=4, after=6)
                continue

            # Bullet point
            if line.startswith("- "):
                p = cell.add_paragraph()
                first = False
                r = p.add_run("  \u2022  ")
                r.font.name = "Calibri"
                r.font.size = Pt(11)
                r.font.color.rgb = RGBColor(0xFF, 0x99, 0x00)
                r.font.bold = True
                add_formatted_text(p, line[2:], base_size=10)
                set_paragraph_spacing(p, before=2, after=2)

        # Spacing after the table
        p = self.doc.add_paragraph()
        set_paragraph_spacing(p, before=0, after=0)

    def _render_blockquote(self, bq_lines):
        """Render a general blockquote with a gray left border."""
        tbl = self.doc.add_table(rows=1, cols=1)
        tbl.alignment = 1
        set_table_full_width(tbl)
        cell = tbl.cell(0, 0)

        set_cell_borders(cell,
                         left=("18", "CCCCCC"),
                         top=("2", "E8E8E8"),
                         bottom=("2", "E8E8E8"),
                         right=("2", "E8E8E8"))
        set_cell_shading(cell, "F9F9F9")
        cell.paragraphs[0].clear()

        first = True
        for line in bq_lines:
            line = line.strip()
            if not line:
                continue
            p = cell.paragraphs[0] if first else cell.add_paragraph()
            first = False
            add_formatted_text(p, line, base_size=10, base_color=RGBColor(0x55, 0x55, 0x55))
            set_paragraph_spacing(p, before=2, after=2)

        p = self.doc.add_paragraph()
        set_paragraph_spacing(p, before=0, after=0)

    def _render_code_block(self, code_lines, lang=""):
        """Render a fenced code block as a shaded monospace box."""
        tbl = self.doc.add_table(rows=1, cols=1)
        tbl.alignment = 1
        set_table_full_width(tbl)
        cell = tbl.cell(0, 0)

        set_cell_borders(cell,
                         top=("2", "D0D0D0"),
                         bottom=("2", "D0D0D0"),
                         left=("2", "D0D0D0"),
                         right=("2", "D0D0D0"))
        set_cell_shading(cell, "F5F5F5")
        cell.paragraphs[0].clear()

        # Optional language label
        first = True
        if lang:
            p = cell.paragraphs[0]
            first = False
            r = p.add_run(lang.upper())
            r.font.name = "Consolas"
            r.font.size = Pt(7)
            r.font.bold = True
            r.font.color.rgb = RGBColor(0x99, 0x99, 0x99)
            set_paragraph_spacing(p, before=2, after=0)

        for line in code_lines:
            p = cell.paragraphs[0] if first else cell.add_paragraph()
            first = False
            r = p.add_run(line if line else " ")
            r.font.name = "Consolas"
            r.font.size = Pt(9)
            r.font.color.rgb = RGBColor(0x33, 0x33, 0x33)
            set_paragraph_spacing(p, before=0, after=0)

        p = self.doc.add_paragraph()
        set_paragraph_spacing(p, before=0, after=4)

    def _render_table(self, table_lines):
        """Render a markdown table with styled header and alternating rows."""
        rows_raw = []
        for tl in table_lines:
            if re.match(r"^\|[\s\-:|]+\|$", tl.strip()):
                continue
            cells = [c.strip() for c in tl.strip().strip("|").split("|")]
            rows_raw.append(cells)

        if not rows_raw:
            return

        n_cols = len(rows_raw[0])
        n_rows = len(rows_raw)

        tbl = self.doc.add_table(rows=n_rows, cols=n_cols)
        tbl.alignment = 1
        tbl.autofit = True
        set_table_full_width(tbl)

        # Style header row
        for j, val in enumerate(rows_raw[0]):
            cell = tbl.cell(0, j)
            cell.text = ""
            p = cell.paragraphs[0]
            add_formatted_text(p, val, base_size=10, base_bold=True, base_color=WHITE)
            set_cell_shading(cell, TABLE_HEADER_BG)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            set_paragraph_spacing(p, before=4, after=4)

        # Data rows
        for i in range(1, n_rows):
            for j in range(n_cols):
                cell = tbl.cell(i, j)
                cell.text = ""
                p = cell.paragraphs[0]

                val = rows_raw[i][j].strip() if j < len(rows_raw[i]) else ""

                if val in PRIORITY_BADGE:
                    add_badge(p, val, PRIORITY_BADGE[val])
                else:
                    add_formatted_text(p, val, base_size=10)

                if i % 2 == 0:
                    set_cell_shading(cell, TABLE_ALT_ROW)

                cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
                set_paragraph_spacing(p, before=3, after=3)

        # Set thin borders on all cells
        for row in tbl.rows:
            for cell in row.cells:
                set_cell_borders(cell,
                                 top=("2", "D0D0D0"),
                                 bottom=("2", "D0D0D0"),
                                 left=("2", "D0D0D0"),
                                 right=("2", "D0D0D0"))

        p = self.doc.add_paragraph()
        set_paragraph_spacing(p, before=0, after=4)

    def _render_numbered_list(self, items):
        for item in items:
            nm = re.match(r"^(\d+)\.\s+(.+)$", item)
            if nm:
                p = self.doc.add_paragraph()
                set_paragraph_spacing(p, before=2, after=2)
                r = p.add_run(f"{nm.group(1)}.  ")
                r.font.name = "Calibri"
                r.font.size = Pt(11)
                r.font.bold = True
                r.font.color.rgb = RGBColor(0xFF, 0x99, 0x00)
                add_formatted_text(p, nm.group(2))
                self._maybe_add_badge(p, nm.group(2))
            elif item.strip().startswith("- "):
                p = self.doc.add_paragraph()
                set_paragraph_spacing(p, before=1, after=1)
                p.paragraph_format.left_indent = Cm(1.2)
                r = p.add_run("\u2022  ")
                r.font.name = "Calibri"
                r.font.size = Pt(10)
                r.font.color.rgb = RGBColor(0x99, 0x99, 0x99)
                add_formatted_text(p, item.strip()[2:], base_size=10)
            elif item.strip():
                # Continuation text under a numbered item
                p = self.doc.add_paragraph()
                set_paragraph_spacing(p, before=1, after=1)
                p.paragraph_format.left_indent = Cm(0.8)
                add_formatted_text(p, item.strip(), base_size=10)

    def _render_bullet_list(self, items):
        for indent_level, text in items:
            p = self.doc.add_paragraph()
            left = Cm(0.6 * indent_level)
            p.paragraph_format.left_indent = left
            set_paragraph_spacing(p, before=2, after=2)

            bullet_char = "\u2022" if indent_level == 0 else "\u25E6"
            r = p.add_run(f"  {bullet_char}  ")
            r.font.name = "Calibri"
            r.font.size = Pt(11)
            if indent_level == 0:
                r.font.color.rgb = RGBColor(0xFF, 0x99, 0x00)
            else:
                r.font.color.rgb = RGBColor(0x99, 0x99, 0x99)

            add_formatted_text(p, text)
            self._maybe_add_badge(p, text)

    def _render_horizontal_rule(self):
        """Render a horizontal rule as a thin gray separator line."""
        p = self.doc.add_paragraph()
        set_paragraph_spacing(p, before=6, after=6)
        add_paragraph_border(p, side="bottom", sz="4", color="D0D0D0", space="0")

    def _is_footer_metadata(self, bq_lines):
        """Check if blockquote is document footer metadata."""
        joined = " ".join(bq_lines)
        markers = ["Author:", "작성자:", "Source:", "출처:",
                    "Last updated:", "최종 업데이트:"]
        return sum(1 for m in markers if m in joined) >= 2

    def _render_footer_metadata(self, bq_lines):
        """Render footer metadata with subtle, compact styling."""
        # Thin top separator
        p = self.doc.add_paragraph()
        set_paragraph_spacing(p, before=16, after=4)
        add_paragraph_border(p, side="bottom", sz="4", color="D0D0D0", space="4")

        for line in bq_lines:
            line = line.strip()
            if not line:
                continue
            p = self.doc.add_paragraph()
            set_paragraph_spacing(p, before=1, after=1)
            # Split on first colon to highlight the label
            colon_idx = line.find(":")
            if colon_idx > 0:
                label = line[:colon_idx + 1]
                value = line[colon_idx + 1:].strip()
                r = p.add_run(label + " ")
                r.font.name = "Calibri"
                r.font.size = Pt(8)
                r.font.bold = True
                r.font.color.rgb = RGBColor(0x99, 0x99, 0x99)
                add_formatted_text(p, value, base_size=8,
                                   base_color=RGBColor(0x99, 0x99, 0x99))
            else:
                r = p.add_run(line)
                r.font.name = "Calibri"
                r.font.size = Pt(8)
                r.font.color.rgb = RGBColor(0x99, 0x99, 0x99)

    def _maybe_add_badge(self, paragraph, text):
        """Check badge rules and append a badge if text matches."""
        for trigger, (label, color) in self.badge_rules.items():
            if trigger.lower() in text.lower():
                paragraph.add_run("  ")
                add_badge(paragraph, label, color)
                break

    def _add_footer(self):
        """Add a styled footer separator and credit line."""
        p = self.doc.add_paragraph()
        set_paragraph_spacing(p, before=24, after=4)
        add_paragraph_border(p, side="top", sz="4", color="D0D0D0", space="8")

        section = self.doc.sections[-1]
        footer = section.footer
        footer.is_linked_to_previous = False
        fp = footer.paragraphs[0]
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER

        if self.footer_text:
            txt = self.footer_text
        else:
            today = date.today().isoformat()
            txt = f"Generated from Markdown  |  {today}  |  Confidential"

        r = fp.add_run(txt)
        r.font.name = "Calibri"
        r.font.size = Pt(8)
        r.font.color.rgb = RGBColor(0x99, 0x99, 0x99)


# -- Main ---------------------------------------------------------------------

def detect_lang(md_path):
    """Auto-detect language from filename convention (-ko suffix)."""
    base = os.path.splitext(os.path.basename(md_path))[0]
    if base.endswith("-ko"):
        return "ko"
    return "en"


def main():
    parser = argparse.ArgumentParser(
        description="Convert markdown files to styled Word documents with AWS branding."
    )
    parser.add_argument("input", nargs="+", help="Input markdown file path(s)")
    parser.add_argument("-o", "--output", help="Output .docx file path (only valid with single input file)")
    parser.add_argument("-l", "--lang", choices=["en", "ko"], default=None,
                        help="Language for badge rules and labels (default: auto-detect from filename)")
    parser.add_argument("--footer", default=None,
                        help="Custom footer text (default: auto-generated with date)")

    args = parser.parse_args()

    if args.output and len(args.input) > 1:
        print("Error: -o/--output can only be used with a single input file.", file=sys.stderr)
        sys.exit(1)

    for md_path in args.input:
        if not os.path.isfile(md_path):
            print(f"Error: Input file not found: {md_path}", file=sys.stderr)
            sys.exit(1)

        out_path = args.output if args.output else os.path.splitext(md_path)[0] + ".docx"
        lang = args.lang if args.lang else detect_lang(md_path)

        print(f"Generating styled Word document (lang={lang})...")
        builder = StyledDocxBuilder(lang=lang, footer_text=args.footer)
        builder.build(md_path, out_path)

    print("Done!")


if __name__ == "__main__":
    main()
