"""Single-source builder for the DIP Studio IEEE research paper.

Generates:
  1. paper/ieee_paper.html  +  paper/DIP_Studio_IEEE_Research_Paper.pdf
  2. paper/DIP_Studio_IEEE_Research_Paper.docx  (native OMML equations + 3x PNGs)
  3. paper/ieee_research_paper.tex              (IEEEtran LaTeX)
  4. paper/RESEARCH_PAPER_IEEE.md               (GitHub-flavored Markdown)
"""
import html as html_lib
import os
import re
import subprocess
import sys
import tempfile

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn
from docx.shared import Inches, Pt, RGBColor
from latex2mathml.converter import convert as latex_to_mathml
from lxml import etree

sys.path.insert(0, os.path.dirname(__file__))
import content
import figures

ROOT = figures.ROOT
PAPER_DIR = os.path.join(ROOT, 'paper')
EDGE = figures.EDGE
MML2OMML_XSL = r'C:\Program Files\Microsoft Office\root\Office16\MML2OMML.XSL'

ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII']
ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

_XSLT = etree.XSLT(etree.parse(MML2OMML_XSL)) if os.path.exists(MML2OMML_XSL) else None


def to_roman(n):
    return ROMAN[n - 1]


# ---------------------------------------------------------------------------
# Cross-reference resolver
# ---------------------------------------------------------------------------
def resolve_refs(body):
    """Number all sections, subsections, figures, tables, equations, algorithms."""
    refs = {}
    sec_i = 0
    sub_i = 0
    fig_i = 0
    tab_i = 0
    eq_i = 0
    alg_i = 0
    enriched = []
    for blk in body:
        kind = blk[0]
        if kind == 'h1':
            sec_i += 1
            sub_i = 0
            _, title, label = blk
            num = to_roman(sec_i)
            if label:
                refs[f'sec:{label}'] = num
            enriched.append(('h1', num, title, label))
        elif kind == 'h2':
            sub_i += 1
            _, title = blk
            letter = ALPHA[sub_i - 1]
            enriched.append(('h2', letter, title))
        elif kind == 'label':
            _, label = blk
            refs[f'sec:{label}'] = f'{to_roman(sec_i)}-{ALPHA[sub_i - 1]}'
        elif kind == 'fig':
            fig_i += 1
            _, label, key, caption, full, width = blk
            refs[f'fig:{label}'] = str(fig_i)
            enriched.append(('fig', fig_i, label, key, caption, full, width))
        elif kind == 'table':
            tab_i += 1
            _, label, caption, spec, full = blk
            refs[f'tab:{label}'] = to_roman(tab_i)
            enriched.append(('table', to_roman(tab_i), label, caption, spec, full))
        elif kind == 'eq':
            eq_i += 1
            _, latex, label = blk
            if label:
                refs[f'eq:{label}'] = str(eq_i)
            enriched.append(('eq', eq_i, latex, label))
        elif kind == 'algo':
            alg_i += 1
            _, label, title, lines = blk
            refs[f'alg:{label}'] = str(alg_i)
            enriched.append(('algo', alg_i, label, title, lines))
        else:
            enriched.append(blk)
    return enriched, refs


def sub_refs(text, refs):
    def repl(m):
        key = m.group(1)
        if key not in refs:
            raise KeyError(f'Unknown reference {{{key}}}')
        return refs[key]
    return re.sub(r'\{((?:fig|tab|eq|alg|sec):[a-zA-Z0-9_]+)\}', repl, text)


# ---------------------------------------------------------------------------
# Tokenize inline markup: <b>, <i>, <code>, $math$, plain text
# ---------------------------------------------------------------------------
_TOKEN_RE = re.compile(
    r'(<b\b[^>]*>.*?</b>|<i\b[^>]*>.*?</i>|<code\b[^>]*>.*?</code>|\$[^$]+\$)',
    re.DOTALL,
)


def tokenize_inline(text, refs):
    text = sub_refs(text, refs)
    tokens = []
    pos = 0
    for m in _TOKEN_RE.finditer(text):
        if m.start() > pos:
            tokens.append(('text', text[pos:m.start()]))
        tok = m.group(0)
        if tok.startswith('<b'):
            inner = re.sub(r'^<b[^>]*>|</b>$', '', tok)
            tokens.append(('b', inner))
        elif tok.startswith('<i'):
            inner = re.sub(r'^<i[^>]*>|</i>$', '', tok)
            tokens.append(('i', inner))
        elif tok.startswith('<code'):
            inner = re.sub(r'^<code[^>]*>|</code>$', '', tok)
            tokens.append(('code', inner))
        elif tok.startswith('$'):
            tokens.append(('math', tok[1:-1]))
        pos = m.end()
    if pos < len(text):
        tokens.append(('text', text[pos:]))
    return tokens


# ---------------------------------------------------------------------------
# Math converters
# ---------------------------------------------------------------------------
def _clean_mathml(mml):
    # Ensure display attribute and clean XML
    return mml


def math_to_html(latex, display=False):
    mml = latex_to_mathml(latex, display='block' if display else 'inline')
    return _clean_mathml(mml)


def math_to_omml_element(latex):
    mml = latex_to_mathml(latex, display='inline')
    if _XSLT is None:
        return None
    tree = etree.fromstring(mml.encode('utf-8'))
    omml_doc = _XSLT(tree)
    omml_root = omml_doc.getroot()
    # Set Cambria Math font on math runs so Word renders crisply
    m_ns = 'http://schemas.openxmlformats.org/officeDocument/2006/math'
    w_ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    for mr in omml_root.findall(f'.//{{{m_ns}}}r'):
        rpr = mr.find(f'{{{w_ns}}}rPr')
        if rpr is None:
            rpr = etree.Element(f'{{{w_ns}}}rPr')
            mr.insert(0, rpr)
        rfonts = rpr.find(f'{{{w_ns}}}rFonts')
        if rfonts is None:
            rfonts = etree.SubElement(rpr, f'{{{w_ns}}}rFonts')
        rfonts.set(f'{{{w_ns}}}ascii', 'Cambria Math')
        rfonts.set(f'{{{w_ns}}}hAnsi', 'Cambria Math')
    return omml_root


# ===========================================================================
# 1. HTML + PDF BUILDER
# ===========================================================================
def render_inline_html(text, refs):
    out = []
    for kind, val in tokenize_inline(text, refs):
        if kind == 'text':
            out.append(html_lib.escape(val))
        elif kind == 'b':
            out.append(f'<b>{render_inline_html(val, refs)}</b>')
        elif kind == 'i':
            out.append(f'<i>{render_inline_html(val, refs)}</i>')
        elif kind == 'code':
            out.append(f'<code>{html_lib.escape(val)}</code>')
        elif kind == 'math':
            out.append(math_to_html(val, display=False))
    return ''.join(out)


def render_table_html(num, caption, spec, refs, full=False):
    cls = 'full-width-table' if full else 'column-width-table'
    align_map = {'l': 'left', 'r': 'right', 'c': 'center'}
    parts = [
        f'<div class="{cls}">',
        f'  <div class="table-caption">TABLE {num}<br><span class="table-title">'
        f'{render_inline_html(caption, refs)}</span></div>',
        '  <table class="ieee-table">',
        '    <thead>',
    ]
    for hrow in spec['header']:
        parts.append('      <tr>')
        for label, cs, rs in hrow:
            attrs = ''
            if cs > 1:
                attrs += f' colspan="{cs}"'
            if rs > 1:
                attrs += f' rowspan="{rs}"'
            parts.append(f'        <th{attrs}>{render_inline_html(label, refs)}</th>')
        parts.append('      </tr>')
    parts.append('    </thead>')
    parts.append('    <tbody>')

    # Pre-calculate rowspans for col 0 where subsequent cells are None
    rows = spec['rows']
    rowspans = {}
    i = 0
    while i < len(rows):
        if rows[i][0] is not None:
            j = i + 1
            while j < len(rows) and rows[j][0] is None:
                j += 1
            rowspans[i] = j - i
            i = j
        else:
            i += 1

    for r_idx, row in enumerate(rows):
        is_group_start = (r_idx > 0 and row[0] is not None)
        tr_cls = ' class="group-start"' if is_group_start else ''
        parts.append(f'      <tr{tr_cls}>')
        for c_idx, cell in enumerate(row):
            if c_idx == 0 and cell is None:
                continue
            al = align_map[spec['align'][c_idx]]
            extra = ''
            if c_idx == 0 and rowspans.get(r_idx, 1) > 1:
                extra += f' rowspan="{rowspans[r_idx]}"'
            cell_html = render_inline_html(cell, refs)
            if c_idx == 0:
                cell_html = f'<b>{cell_html}</b>'
            parts.append(f'        <td class="{al}"{extra}>{cell_html}</td>')
        parts.append('      </tr>')
    parts.append('    </tbody>')
    parts.append('  </table>')
    parts.append('</div>')
    return '\n'.join(parts)


def build_html_and_pdf(enriched, refs, figs):
    # Split body around full-width blocks so two-column flow wraps cleanly
    html_chunks = []
    in_two_col = False
    first_intro_p = True

    def open_two_col():
        nonlocal in_two_col
        if not in_two_col:
            html_chunks.append('<div class="two-column-layout">')
            in_two_col = True

    def close_two_col():
        nonlocal in_two_col
        if in_two_col:
            html_chunks.append('</div>')
            in_two_col = False

    open_two_col()
    # Abstract + Index Terms inside first column (standard IEEEtran)
    html_chunks.append(
        '<div class="abstract-box">'
        f'  <p class="no-indent"><span class="abstract-heading">Abstract\u2014</span>'
        f'{render_inline_html(content.ABSTRACT, refs)}</p>'
        f'  <p class="index-terms no-indent"><span class="index-terms-heading">Index Terms\u2014</span>'
        f'{html_lib.escape(content.INDEX_TERMS)}</p>'
        '</div>'
    )

    for blk in enriched:
        kind = blk[0]
        if kind == 'h1':
            _, num, title, label = blk
            open_two_col()
            html_chunks.append(
                f'<h2 class="section-heading">{num}. {html_lib.escape(title)}</h2>'
            )
        elif kind == 'h2':
            _, letter, title = blk
            open_two_col()
            html_chunks.append(
                f'<h3 class="subsection-heading">{letter}. {html_lib.escape(title)}</h3>'
            )
        elif kind == 'p':
            _, text, indent = blk
            open_two_col()
            rendered = render_inline_html(text, refs)
            if first_intro_p and not indent:
                first_intro_p = False
                # IEEE drop cap on first letter of Section I
                first_ch = rendered[0]
                rest = rendered[1:]
                html_chunks.append(
                    f'<p class="no-indent"><span class="drop-cap">{first_ch}</span>{rest}</p>'
                )
            else:
                cls = '' if indent else ' class="no-indent"'
                html_chunks.append(f'<p{cls}>{rendered}</p>')
        elif kind == 'list':
            _, items, numbered = blk
            open_two_col()
            tag = 'ol' if numbered else 'ul'
            lis = ''.join(f'<li>{render_inline_html(it, refs)}</li>' for it in items)
            html_chunks.append(f'<{tag}>{lis}</{tag}>')
        elif kind == 'eq':
            _, num, latex, label = blk
            open_two_col()
            html_chunks.append(
                '<div class="equation-row">'
                f'  <span class="equation-math">{math_to_html(latex, display=True)}</span>'
                f'  <span class="equation-num">({num})</span>'
                '</div>'
            )
        elif kind == 'algo':
            _, num, label, title, lines = blk
            open_two_col()
            body_lines = []
            for idx, ln in enumerate(lines, start=1):
                body_lines.append(
                    f'<div class="algo-line"><span class="algo-ln">{idx}:</span> '
                    f'<span>{render_inline_html(ln, refs)}</span></div>'
                )
            html_chunks.append(
                '<div class="algo-box">'
                f'  <div class="algo-header"><b>Algorithm {num}</b> {render_inline_html(title, refs)}</div>'
                f'  <div class="algo-body">{"".join(body_lines)}</div>'
                '</div>'
            )
        elif kind == 'fig':
            _, num, label, key, caption, full, width = blk
            svg_inline = figs[key]['inline']
            if full:
                close_two_col()
                html_chunks.append(
                    '<div class="full-width-figure">'
                    f'  <div class="fig-frame">{svg_inline}</div>'
                    f'  <div class="figure-caption"><b>Fig. {num}.</b> {render_inline_html(caption, refs)}</div>'
                    '</div>'
                )
                open_two_col()
            else:
                open_two_col()
                html_chunks.append(
                    '<div class="column-figure">'
                    f'  <div class="fig-frame">{svg_inline}</div>'
                    f'  <div class="figure-caption"><b>Fig. {num}.</b> {render_inline_html(caption, refs)}</div>'
                    '</div>'
                )
        elif kind == 'table':
            _, num, label, caption, spec, full = blk
            t_html = render_table_html(num, caption, spec, refs, full=full)
            if full:
                close_two_col()
                html_chunks.append(t_html)
                open_two_col()
            else:
                open_two_col()
                html_chunks.append(t_html)

    # References
    open_two_col()
    html_chunks.append('<h2 class="section-heading">References</h2>')
    ref_items = []
    for idx, ref in enumerate(content.REFERENCES, start=1):
        ref_items.append(
            f'<div class="reference-item"><span class="ref-num">[{idx}]</span>'
            f'<span class="ref-text">{render_inline_html(ref, refs)}</span></div>'
        )
    html_chunks.append('<div class="reference-list">' + '\n'.join(ref_items) + '</div>')
    close_two_col()

    doc_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>{html_lib.escape(content.TITLE)}</title>
<style>
  @page {{
    size: letter;
    margin: 0.68in 0.60in 0.70in 0.60in;
  }}
  *, *::before, *::after {{ box-sizing: border-box; }}
  body {{
    font-family: "Times New Roman", Times, Georgia, serif;
    font-size: 9.6pt;
    line-height: 1.18;
    color: #000;
    margin: 0;
    padding: 0;
    background: #fff;
  }}
  .running-header {{
    width: 100%;
    font-size: 7.8pt;
    color: #333;
    border-bottom: 0.6pt solid #444;
    padding-bottom: 2.5pt;
    margin-bottom: 12pt;
    display: flex;
    justify-content: space-between;
    text-transform: uppercase;
    letter-spacing: 0.45pt;
  }}
  .title-block {{
    text-align: center;
    margin: 0 auto 14pt auto;
    padding: 0 14pt;
  }}
  h1.paper-title {{
    font-size: 20pt;
    font-weight: bold;
    line-height: 1.18;
    margin: 0;
    color: #000;
  }}
  .two-column-layout {{
    column-count: 2;
    column-gap: 0.24in;
    text-align: justify;
    text-justify: inter-word;
    hyphens: auto;
  }}
  .abstract-box {{
    margin-bottom: 10pt;
    font-size: 8.8pt;
    line-height: 1.17;
  }}
  .abstract-heading, .index-terms-heading {{
    font-weight: bold;
    font-style: italic;
  }}
  .index-terms {{
    margin-top: 5pt;
    font-size: 8.7pt;
  }}
  h2.section-heading {{
    font-size: 9.8pt;
    font-weight: bold;
    text-align: center;
    text-transform: uppercase;
    margin: 11pt 0 4pt 0;
    letter-spacing: 0.5pt;
    break-after: avoid;
    page-break-after: avoid;
  }}
  h3.subsection-heading {{
    font-size: 9.3pt;
    font-weight: bold;
    font-style: italic;
    margin: 7.5pt 0 2.5pt 0;
    text-align: left;
    break-after: avoid;
    page-break-after: avoid;
  }}
  p {{
    margin: 0 0 4.5pt 0;
    text-indent: 13pt;
    orphans: 2;
    widows: 2;
  }}
  p.no-indent {{ text-indent: 0; }}
  .drop-cap {{
    float: left;
    font-size: 30pt;
    line-height: 24pt;
    padding: 2pt 3.5pt 0 0;
    font-weight: bold;
  }}
  code {{
    font-family: Consolas, "Courier New", monospace;
    font-size: 8.3pt;
    background: #f1f5f9;
    padding: 0.5pt 2.5pt;
    border-radius: 2pt;
  }}
  ul, ol {{
    margin: 3pt 0 6pt 0;
    padding-left: 14pt;
    font-size: 9.3pt;
  }}
  li {{
    margin-bottom: 2.5pt;
    text-align: justify;
  }}
  .equation-row {{
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin: 5pt 0;
    padding: 1pt 0;
    width: 100%;
    break-inside: avoid;
    page-break-inside: avoid;
  }}
  .equation-math {{
    flex: 1 1 auto;
    text-align: center;
    font-size: 8.7pt;
    overflow-x: visible;
  }}
  .equation-math math {{
    font-family: "Cambria Math", "STIX Two Math", "Times New Roman", serif;
    font-size: 8.7pt;
  }}
  p math, li math, td math, .figure-caption math, .table-caption math, .algo-box math {{
    font-family: "Cambria Math", "STIX Two Math", "Times New Roman", serif;
    font-size: 9.2pt;
  }}
  .equation-num {{
    flex: 0 0 auto;
    font-size: 8.8pt;
    padding-left: 6pt;
    color: #000;
  }}
  .algo-box {{
    margin: 7pt 0 8pt 0;
    border-top: 1.2pt solid #000;
    border-bottom: 1.2pt solid #000;
    padding: 4pt 2pt;
    font-size: 8.4pt;
    line-height: 1.28;
    break-inside: avoid;
    page-break-inside: avoid;
  }}
  .algo-header {{
    border-bottom: 0.7pt solid #000;
    padding-bottom: 3pt;
    margin-bottom: 3.5pt;
    font-size: 8.6pt;
  }}
  .algo-line {{
    display: flex;
    gap: 5pt;
    text-align: left;
  }}
  .algo-ln {{
    color: #555;
    width: 14pt;
    text-align: right;
    flex-shrink: 0;
    font-size: 7.8pt;
  }}
  .full-width-figure {{
    width: 100%;
    margin: 9pt 0 11pt 0;
    break-inside: avoid;
    page-break-inside: avoid;
    text-align: center;
  }}
  .full-width-figure .fig-frame svg {{
    width: 100%;
    height: auto;
    display: block;
    margin: 0 auto;
  }}
  .column-figure {{
    width: 100%;
    margin: 5pt 0 7pt 0;
    break-inside: avoid;
    page-break-inside: avoid;
    text-align: center;
  }}
  .column-figure .fig-frame svg {{
    width: 100%;
    max-width: 100%;
    height: auto;
    display: block;
    margin: 0 auto;
  }}
  .figure-caption {{
    font-size: 8.1pt;
    text-align: justify;
    margin-top: 4pt;
    color: #111;
    line-height: 1.18;
  }}
  .full-width-table {{
    width: 100%;
    margin: 9pt 0 11pt 0;
    break-inside: avoid;
    page-break-inside: avoid;
  }}
  .column-width-table {{
    width: 100%;
    margin: 7pt 0 9pt 0;
    break-inside: avoid;
    page-break-inside: avoid;
  }}
  .table-caption {{
    font-size: 8pt;
    text-align: center;
    text-transform: uppercase;
    font-weight: bold;
    margin-bottom: 4pt;
    letter-spacing: 0.4pt;
    line-height: 1.2;
  }}
  .table-caption .table-title {{
    font-weight: normal;
    text-transform: none;
    letter-spacing: 0;
    font-variant: small-caps;
    font-size: 8.2pt;
  }}
  table.ieee-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 7.8pt;
    line-height: 1.18;
  }}
  table.ieee-table thead tr:first-child th {{
    border-top: 1.2pt solid #000;
  }}
  table.ieee-table thead tr:last-child th {{
    border-bottom: 0.8pt solid #000;
  }}
  table.ieee-table th {{
    padding: 3pt 3.5pt;
    font-weight: bold;
    text-align: center;
    background: #f8fafc;
  }}
  table.ieee-table td {{
    padding: 2.2pt 3.5pt;
    border-bottom: 0.35pt solid #e2e8f0;
    vertical-align: middle;
  }}
  table.ieee-table tr.group-start td {{
    border-top: 0.6pt solid #94a3b8;
  }}
  table.ieee-table td.left {{ text-align: left; }}
  table.ieee-table td.right {{ text-align: right; font-variant-numeric: tabular-nums; }}
  table.ieee-table td.center {{ text-align: center; }}
  table.ieee-table tbody tr:last-child td {{
    border-bottom: 1.2pt solid #000;
  }}
  .reference-list {{
    font-size: 7.7pt;
    line-height: 1.14;
    margin-top: 3pt;
  }}
  .reference-item {{
    display: grid;
    grid-template-columns: 18pt 1fr;
    column-gap: 3pt;
    margin-bottom: 2pt;
    text-align: justify;
    break-inside: avoid;
    page-break-inside: avoid;
  }}
  .ref-num {{
    text-align: right;
    white-space: nowrap;
  }}
  .ref-text {{
    min-width: 0;
  }}
</style>
</head>
<body>
<div class="running-header">
  <span>IEEE Transactions on Image Processing</span>
  <span>{html_lib.escape(content.SHORT_TITLE)}</span>
</div>
<div class="title-block">
  <h1 class="paper-title">{html_lib.escape(content.TITLE)}</h1>
</div>
{chr(10).join(html_chunks)}
</body>
</html>
"""
    html_path = os.path.join(PAPER_DIR, 'ieee_paper.html')
    pdf_path = os.path.join(PAPER_DIR, 'DIP_Studio_IEEE_Research_Paper.pdf')
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(doc_html)
    tmpdir = tempfile.mkdtemp(prefix='dippdf_')
    subprocess.run([
        EDGE, '--headless=new', '--disable-gpu', '--no-pdf-header-footer',
        f'--user-data-dir={os.path.join(tmpdir, "profile")}',
        f'--print-to-pdf={pdf_path}',
        'file:///' + html_path.replace('\\', '/'),
    ], check=True, capture_output=True)
    return html_path, pdf_path


# ===========================================================================
# 2. MICROSOFT WORD (.DOCX) BUILDER WITH NATIVE OMML EQUATIONS
# ===========================================================================
def _set_cell_bg(cell, hex_color):
    shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
    cell._tc.get_or_add_tcPr().append(shading)


def _set_cell_borders(cell, top=None, bottom=None, left=None, right=None,
                      sz_top='6', sz_bottom='6', color='000000'):
    tcPr = cell._tc.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    for side, val, sz in [
        ('top', top, sz_top), ('bottom', bottom, sz_bottom),
        ('left', left, '4'), ('right', right, '4'),
    ]:
        el = OxmlElement(f'w:{side}')
        if val:
            el.set(qn('w:val'), val)
            el.set(qn('w:sz'), sz)
            el.set(qn('w:space'), '0')
            el.set(qn('w:color'), color)
        else:
            el.set(qn('w:val'), 'none')
        tcBorders.append(el)
    tcPr.append(tcBorders)


def _set_cell_margins(cell, top=30, bottom=30, left=60, right=60):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for side, val in [('top', top), ('bottom', bottom), ('left', left), ('right', right)]:
        node = OxmlElement(f'w:{side}')
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)


def _add_inline_docx(p, text, refs, font_size=Pt(9.8), base_bold=False, base_italic=False):
    for kind, val in tokenize_inline(text, refs):
        if kind == 'text':
            r = p.add_run(val)
            r.font.name = 'Times New Roman'
            r.font.size = font_size
            if base_bold:
                r.bold = True
            if base_italic:
                r.italic = True
        elif kind == 'b':
            _add_inline_docx(p, val, refs, font_size=font_size, base_bold=True, base_italic=base_italic)
        elif kind == 'i':
            _add_inline_docx(p, val, refs, font_size=font_size, base_bold=base_bold, base_italic=True)
        elif kind == 'code':
            r = p.add_run(val)
            r.font.name = 'Consolas'
            r.font.size = Pt(font_size.pt - 1.0)
        elif kind == 'math':
            omml = math_to_omml_element(val)
            if omml is not None:
                p._p.append(omml)
            else:
                r = p.add_run(val)
                r.italic = True
                r.font.size = font_size


def _set_section_columns(section, cols=2, space_dxa=340):
    sectPr = section._sectPr
    cols_el = sectPr.find(qn('w:cols'))
    if cols_el is None:
        cols_el = OxmlElement('w:cols')
        sectPr.append(cols_el)
    cols_el.set(qn('w:num'), str(cols))
    cols_el.set(qn('w:space'), str(space_dxa))


def _set_page_margins(section):
    section.page_width = Inches(8.5)
    section.page_height = Inches(11.0)
    section.top_margin = Inches(0.72)
    section.bottom_margin = Inches(0.76)
    section.left_margin = Inches(0.62)
    section.right_margin = Inches(0.62)


def _setup_header(section):
    section.header.is_linked_to_previous = False
    hp = section.header.paragraphs[0]
    hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    hp.paragraph_format.space_after = Pt(2)
    r = hp.add_run(f'IEEE TRANSACTIONS ON IMAGE PROCESSING  |  {content.SHORT_TITLE}')
    r.font.name = 'Times New Roman'
    r.font.size = Pt(7.8)
    r.font.color.rgb = RGBColor(0x44, 0x44, 0x44)
    pBdr = parse_xml(f'<w:pBdr {nsdecls("w")}><w:bottom w:val="single" w:sz="4" w:space="2" w:color="666666"/></w:pBdr>')
    hp._p.get_or_add_pPr().append(pBdr)


def _add_docx_table(doc, num, caption, spec, refs, total_width_in):
    p_cap = doc.add_paragraph()
    p_cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_cap.paragraph_format.space_before = Pt(7)
    p_cap.paragraph_format.space_after = Pt(3)
    p_cap.paragraph_format.keep_with_next = True
    r1 = p_cap.add_run(f'TABLE {num}\n')
    r1.bold = True
    r1.font.name = 'Times New Roman'
    r1.font.size = Pt(8.2)
    _add_inline_docx(p_cap, caption, refs, font_size=Pt(8.2))

    ncols = len(spec['cols'])
    n_hrows = len(spec['header'])
    rows = spec['rows']
    tbl = doc.add_table(rows=n_hrows + len(rows), cols=ncols)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    tbl.autofit = False

    col_widths = [Inches(total_width_in * w) for w in spec['widths']]
    align_map = {
        'l': WD_ALIGN_PARAGRAPH.LEFT,
        'r': WD_ALIGN_PARAGRAPH.RIGHT,
        'c': WD_ALIGN_PARAGRAPH.CENTER,
    }

    # Populate header rows (handling colspan / rowspan)
    occupied = set()
    for hr_i, hrow in enumerate(spec['header']):
        c_cursor = 0
        for label, cs, rs in hrow:
            while (hr_i, c_cursor) in occupied:
                c_cursor += 1
            cell = tbl.cell(hr_i, c_cursor)
            if cs > 1 or rs > 1:
                cell.merge(tbl.cell(hr_i + rs - 1, c_cursor + cs - 1))
            for rr in range(hr_i, hr_i + rs):
                for cc in range(c_cursor, c_cursor + cs):
                    occupied.add((rr, cc))
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(2)
            _add_inline_docx(p, label, refs, font_size=Pt(7.8), base_bold=True)
            _set_cell_bg(cell, 'F8FAFC')
            _set_cell_margins(cell, top=30, bottom=30, left=45, right=45)
            _set_cell_borders(
                cell,
                top='single' if hr_i == 0 else None,
                bottom='single' if (hr_i + rs) == n_hrows else None,
                sz_top='10', sz_bottom='6',
            )
            c_cursor += cs

    # Populate body rows (merging col 0 group spans)
    i = 0
    while i < len(rows):
        if rows[i][0] is not None:
            j = i + 1
            while j < len(rows) and rows[j][0] is None:
                j += 1
            if j - i > 1:
                tbl.cell(n_hrows + i, 0).merge(tbl.cell(n_hrows + j - 1, 0))
            i = j
        else:
            i += 1

    for r_i, row in enumerate(rows):
        tr_i = n_hrows + r_i
        is_last = (r_i == len(rows) - 1)
        is_group_start = (r_i > 0 and row[0] is not None)
        for c_i, val in enumerate(row):
            cell = tbl.cell(tr_i, c_i)
            cell.width = col_widths[c_i]
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            _set_cell_margins(cell, top=22, bottom=22, left=45, right=45)
            if c_i == 0 and val is None:
                continue
            p = cell.paragraphs[0]
            p.alignment = align_map[spec['align'][c_i]]
            p.paragraph_format.space_before = Pt(1.5)
            p.paragraph_format.space_after = Pt(1.5)
            _add_inline_docx(p, val or '', refs, font_size=Pt(7.8), base_bold=(c_i == 0))
            _set_cell_borders(
                cell,
                top='single' if is_group_start else None,
                bottom='single' if is_last else 'single',
                sz_top='4',
                sz_bottom='10' if is_last else '2',
                color='000000' if is_last else 'CBD5E1',
            )
            if is_group_start and not is_last:
                # Re-apply darker top border for group separator
                _set_cell_borders(cell, top='single', bottom='single', sz_top='4', sz_bottom='2', color='94A3B8')

    # Enforce column widths
    for row in tbl.rows:
        for c_i, w in enumerate(col_widths):
            row.cells[c_i].width = w


def build_docx(enriched, refs, figs):
    doc = Document()
    from docx.enum.section import WD_SECTION

    sec0 = doc.sections[0]
    _set_page_margins(sec0)
    _setup_header(sec0)
    _set_section_columns(sec0, cols=1)

    normal = doc.styles['Normal']
    normal.font.name = 'Times New Roman'
    normal.font.size = Pt(9.5)
    normal.font.color.rgb = RGBColor(0, 0, 0)
    normal.paragraph_format.line_spacing = 1.15
    normal.paragraph_format.space_after = Pt(4)

    # Title (single-column header section, no author block)
    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_title.paragraph_format.space_before = Pt(0)
    p_title.paragraph_format.space_after = Pt(12)
    r_title = p_title.add_run(content.TITLE)
    r_title.bold = True
    r_title.font.name = 'Times New Roman'
    r_title.font.size = Pt(19)

    def switch_cols(cols):
        sec = doc.add_section(WD_SECTION.CONTINUOUS)
        _set_page_margins(sec)
        _set_section_columns(sec, cols=cols)
        return sec

    in_two_col = False

    def ensure_cols(cols):
        nonlocal in_two_col
        if cols == 2 and not in_two_col:
            switch_cols(2)
            in_two_col = True
        elif cols == 1 and in_two_col:
            switch_cols(1)
            in_two_col = False

    ensure_cols(2)

    # Abstract & Index Terms
    p_abs = doc.add_paragraph()
    p_abs.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p_abs.paragraph_format.space_after = Pt(5)
    r_ah = p_abs.add_run('Abstract\u2014')
    r_ah.bold = True
    r_ah.italic = True
    r_ah.font.size = Pt(8.8)
    _add_inline_docx(p_abs, content.ABSTRACT, refs, font_size=Pt(8.8))

    p_idx = doc.add_paragraph()
    p_idx.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p_idx.paragraph_format.space_after = Pt(9)
    r_ih = p_idx.add_run('Index Terms\u2014')
    r_ih.bold = True
    r_ih.italic = True
    r_ih.font.size = Pt(8.7)
    r_it = p_idx.add_run(content.INDEX_TERMS)
    r_it.font.size = Pt(8.7)

    COL_W = 3.50  # inches per column on 8.5in page with 0.62in margins & 0.24in gap
    FULL_W = 7.22

    for blk in enriched:
        kind = blk[0]
        if kind == 'h1':
            _, num, title, label = blk
            ensure_cols(2)
            p = doc.add_paragraph()
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.space_before = Pt(10)
            p.paragraph_format.space_after = Pt(3.5)
            p.paragraph_format.keep_with_next = True
            r = p.add_run(f'{num}. {title.upper()}')
            r.bold = True
            r.font.size = Pt(9.8)
        elif kind == 'h2':
            _, letter, title = blk
            ensure_cols(2)
            p = doc.add_paragraph()
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.space_before = Pt(7.5)
            p.paragraph_format.space_after = Pt(2.5)
            p.paragraph_format.keep_with_next = True
            r = p.add_run(f'{letter}. {title}')
            r.bold = True
            r.italic = True
            r.font.size = Pt(9.3)
        elif kind == 'p':
            _, text, indent = blk
            ensure_cols(2)
            p = doc.add_paragraph()
            p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            if indent:
                p.paragraph_format.first_line_indent = Inches(0.18)
            p.paragraph_format.space_after = Pt(4)
            _add_inline_docx(p, text, refs, font_size=Pt(9.5))
        elif kind == 'list':
            _, items, numbered = blk
            ensure_cols(2)
            for idx, it in enumerate(items, start=1):
                p = doc.add_paragraph()
                p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
                p.paragraph_format.left_indent = Inches(0.20)
                p.paragraph_format.first_line_indent = Inches(-0.12)
                p.paragraph_format.space_after = Pt(2.5)
                prefix = f'{idx}) ' if numbered else '\u2022 '
                r = p.add_run(prefix)
                r.font.size = Pt(9.3)
                _add_inline_docx(p, it, refs, font_size=Pt(9.3))
        elif kind == 'eq':
            _, num, latex, label = blk
            ensure_cols(2)
            tbl = doc.add_table(rows=1, cols=2)
            tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
            tbl.autofit = False
            w_math, w_num = Inches(COL_W - 0.42), Inches(0.42)
            c0, c1 = tbl.cell(0, 0), tbl.cell(0, 1)
            c0.width, c1.width = w_math, w_num
            c0.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            c1.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            p0 = c0.paragraphs[0]
            p0.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p0.paragraph_format.space_before = Pt(3)
            p0.paragraph_format.space_after = Pt(3)
            omml = math_to_omml_element(latex)
            if omml is not None:
                p0._p.append(omml)
            else:
                r0 = p0.add_run(latex)
                r0.italic = True
            p1 = c1.paragraphs[0]
            p1.alignment = WD_ALIGN_PARAGRAPH.RIGHT
            p1.paragraph_format.space_before = Pt(3)
            p1.paragraph_format.space_after = Pt(3)
            r1 = p1.add_run(f'({num})')
            r1.font.size = Pt(8.8)
            for c in (c0, c1):
                _set_cell_borders(c)
                _set_cell_margins(c, top=15, bottom=15, left=10, right=10)
        elif kind == 'algo':
            _, num, label, title, lines = blk
            ensure_cols(2)
            tbl = doc.add_table(rows=2, cols=1)
            tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
            tbl.autofit = False
            c_hdr, c_bdy = tbl.cell(0, 0), tbl.cell(1, 0)
            c_hdr.width = c_bdy.width = Inches(COL_W)
            _set_cell_borders(c_hdr, top='single', bottom='single', sz_top='10', sz_bottom='6')
            _set_cell_borders(c_bdy, bottom='single', sz_bottom='10')
            _set_cell_margins(c_hdr, top=35, bottom=35, left=40, right=40)
            _set_cell_margins(c_bdy, top=40, bottom=40, left=40, right=40)
            ph = c_hdr.paragraphs[0]
            ph.paragraph_format.space_after = Pt(0)
            rh = ph.add_run(f'Algorithm {num}  ')
            rh.bold = True
            rh.font.size = Pt(8.5)
            _add_inline_docx(ph, title, refs, font_size=Pt(8.5))
            for idx, ln in enumerate(lines, start=1):
                pl = c_bdy.paragraphs[0] if idx == 1 else c_bdy.add_paragraph()
                pl.paragraph_format.space_after = Pt(1.5)
                pl.paragraph_format.line_spacing = 1.15
                rln = pl.add_run(f'{idx}: ')
                rln.font.size = Pt(8.0)
                rln.font.color.rgb = RGBColor(0x55, 0x55, 0x55)
                _add_inline_docx(pl, ln, refs, font_size=Pt(8.3))
        elif kind == 'fig':
            _, num, label, key, caption, full, width = blk
            png_path = figs[key]['png']
            if full:
                ensure_cols(1)
                img_w = Inches(FULL_W)
            else:
                ensure_cols(2)
                img_w = Inches(COL_W - 0.04)
            p_img = doc.add_paragraph()
            p_img.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p_img.paragraph_format.space_before = Pt(6)
            p_img.paragraph_format.space_after = Pt(2)
            p_img.paragraph_format.keep_with_next = True
            p_img.add_run().add_picture(png_path, width=img_w)

            p_cap = doc.add_paragraph()
            p_cap.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            p_cap.paragraph_format.space_after = Pt(8)
            rb = p_cap.add_run(f'Fig. {num}. ')
            rb.bold = True
            rb.font.size = Pt(8.2)
            _add_inline_docx(p_cap, caption, refs, font_size=Pt(8.2))
            if full:
                ensure_cols(2)
        elif kind == 'table':
            _, num, label, caption, spec, full = blk
            if full:
                ensure_cols(1)
                _add_docx_table(doc, num, caption, spec, refs, FULL_W)
                ensure_cols(2)
            else:
                ensure_cols(2)
                _add_docx_table(doc, num, caption, spec, refs, COL_W)

    # References
    ensure_cols(2)
    p_rh = doc.add_paragraph()
    p_rh.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_rh.paragraph_format.space_before = Pt(10)
    p_rh.paragraph_format.space_after = Pt(4)
    p_rh.paragraph_format.keep_with_next = True
    r_rh = p_rh.add_run('REFERENCES')
    r_rh.bold = True
    r_rh.font.size = Pt(9.8)

    for idx, ref in enumerate(content.REFERENCES, start=1):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        p.paragraph_format.left_indent = Inches(0.24)
        p.paragraph_format.first_line_indent = Inches(-0.24)
        p.paragraph_format.space_after = Pt(2.5)
        r_n = p.add_run(f'[{idx}] ')
        r_n.font.size = Pt(8.0)
        _add_inline_docx(p, ref, refs, font_size=Pt(8.0))

    docx_path = os.path.join(PAPER_DIR, 'DIP_Studio_IEEE_Research_Paper.docx')
    doc.save(docx_path)
    return docx_path


# ===========================================================================
# 3. LATEX (.TEX) BUILDER
# ===========================================================================
def _tex_escape(s):
    rep = [
        ('\\', r'\textbackslash{}'),
        ('&', r'\&'), ('%', r'\%'), ('#', r'\#'), ('_', r'\_'),
        ('{', r'\{'), ('}', r'\}'), ('~', r'\textasciitilde{}'),
        ('^', r'\textasciicircum{}'),
        ('\u2014', '---'), ('\u2013', '--'),
        ('\u201c', '``'), ('\u201d', "''"),
        ('\u2003', r'\quad '),
    ]
    for a, b in rep:
        s = s.replace(a, b)
    return s


def render_inline_tex(text, refs):
    out = []
    for kind, val in tokenize_inline(text, refs):
        if kind == 'text':
            out.append(_tex_escape(val))
        elif kind == 'b':
            out.append(r'\textbf{' + render_inline_tex(val, refs) + '}')
        elif kind == 'i':
            out.append(r'\textit{' + render_inline_tex(val, refs) + '}')
        elif kind == 'code':
            out.append(r'\texttt{' + _tex_escape(val) + '}')
        elif kind == 'math':
            out.append('$' + val + '$')
    return ''.join(out)


def build_tex(enriched, refs, figs):
    lines = [
        r'\documentclass[journal]{IEEEtran}',
        r'\usepackage{amsmath,amssymb,amsfonts}',
        r'\usepackage{graphicx}',
        r'\usepackage{booktabs}',
        r'\usepackage{multirow}',
        r'\usepackage{microtype}',
        r'\usepackage{url}',
        '',
        r'\begin{document}',
        f'\\title{{{_tex_escape(content.TITLE)}}}',
        r'\author{}',
        f'\\markboth{{IEEE Transactions on Image Processing}}{{{_tex_escape(content.SHORT_TITLE)}}}',
        r'\maketitle',
        '',
        r'\begin{abstract}',
        render_inline_tex(content.ABSTRACT, refs),
        r'\end{abstract}',
        '',
        r'\begin{IEEEkeywords}',
        _tex_escape(content.INDEX_TERMS),
        r'\end{IEEEkeywords}',
        '',
    ]

    for blk in enriched:
        kind = blk[0]
        if kind == 'h1':
            _, num, title, label = blk
            lines.append(f'\\section{{{_tex_escape(title)}}}')
            if label:
                lines.append(f'\\label{{sec:{label}}}')
        elif kind == 'h2':
            _, letter, title = blk
            lines.append(f'\\subsection{{{_tex_escape(title)}}}')
        elif kind == 'p':
            _, text, indent = blk
            lines.append(render_inline_tex(text, refs) + '\n')
        elif kind == 'list':
            _, items, numbered = blk
            env = 'enumerate' if numbered else 'itemize'
            lines.append(f'\\begin{{{env}}}')
            for it in items:
                lines.append('  \\item ' + render_inline_tex(it, refs))
            lines.append(f'\\end{{{env}}}\n')
        elif kind == 'eq':
            _, num, latex, label = blk
            lines.append(r'\begin{equation}')
            lines.append('  ' + latex)
            if label:
                lines.append(f'  \\label{{eq:{label}}}')
            lines.append(r'\end{equation}' + '\n')
        elif kind == 'algo':
            _, num, label, title, alg_lines = blk
            lines.append(r'\begin{table}[!t]')
            lines.append(r'\centering')
            lines.append(r'\begin{tabular}{@{}r l@{}}')
            lines.append(r'\toprule')
            lines.append(f'\\multicolumn{{2}}{{@{{}}l@{{}}}}{{\\textbf{{Algorithm {num}}} {render_inline_tex(title, refs)}}} \\\\')
            lines.append(r'\midrule')
            for idx, ln in enumerate(alg_lines, start=1):
                lines.append(f'{idx}: & {render_inline_tex(ln, refs)} \\\\')
            lines.append(r'\bottomrule')
            lines.append(r'\end{tabular}')
            lines.append(r'\end{table}' + '\n')
        elif kind == 'fig':
            _, num, label, key, caption, full, width = blk
            env = 'figure*' if full else 'figure'
            w = r'\textwidth' if full else r'\columnwidth'
            rel_png = f'figures/fig{num}_{key}.png'
            lines.append(f'\\begin{{{env}}}[!t]')
            lines.append(r'\centering')
            lines.append(f'\\includegraphics[width={w}]{{{rel_png}}}')
            lines.append(f'\\caption{{{render_inline_tex(caption, refs)}}}')
            lines.append(f'\\label{{fig:{label}}}')
            lines.append(f'\\end{{{env}}}\n')
        elif kind == 'table':
            _, num, label, caption, spec, full = blk
            env = 'table*' if full else 'table'
            colspec = ''.join(spec['align'])
            lines.append(f'\\begin{{{env}}}[!t]')
            lines.append(r'\centering')
            lines.append(f'\\caption{{{render_inline_tex(caption, refs)}}}')
            lines.append(f'\\label{{tab:{label}}}')
            lines.append(f'\\begin{{tabular}}{{{colspec}}}')
            lines.append(r'\toprule')
            for hrow in spec['header']:
                cells = []
                for lbl, cs, rs in hrow:
                    t = render_inline_tex(lbl, refs)
                    if cs > 1:
                        t = f'\\multicolumn{{{cs}}}{{c}}{{{t}}}'
                    cells.append(t)
                lines.append(' & '.join(cells) + r' \\')
            lines.append(r'\midrule')
            for r_i, row in enumerate(spec['rows']):
                if r_i > 0 and row[0] is not None:
                    lines.append(r'\addlinespace[2pt]')
                cells = [render_inline_tex(c or '', refs) for c in row]
                lines.append(' & '.join(cells) + r' \\')
            lines.append(r'\bottomrule')
            lines.append(r'\end{tabular}')
            lines.append(f'\\end{{{env}}}\n')

    lines.append(r'\begin{thebibliography}{20}')
    for idx, ref in enumerate(content.REFERENCES, start=1):
        lines.append(f'\\bibitem{{ref{idx}}} {render_inline_tex(ref, refs)}')
    lines.append(r'\end{thebibliography}')
    lines.append(r'\end{document}')

    tex_path = os.path.join(PAPER_DIR, 'ieee_research_paper.tex')
    with open(tex_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    return tex_path


# ===========================================================================
# 4. MARKDOWN (.MD) BUILDER
# ===========================================================================
def render_inline_md(text, refs):
    out = []
    for kind, val in tokenize_inline(text, refs):
        if kind == 'text':
            out.append(val)
        elif kind == 'b':
            out.append('**' + render_inline_md(val, refs) + '**')
        elif kind == 'i':
            out.append('*' + render_inline_md(val, refs) + '*')
        elif kind == 'code':
            out.append(f'`{val}`')
        elif kind == 'math':
            out.append(f'${val}$')
    return ''.join(out)


def build_markdown(enriched, refs, figs):
    lines = [
        f'# {content.TITLE}',
        '',
        '*IEEE Transactions on Image Processing Format*',
        '',
        '---',
        '',
        '### Abstract',
        render_inline_md(content.ABSTRACT, refs),
        '',
        f'**Index Terms**—{content.INDEX_TERMS}',
        '',
        '---',
        '',
    ]
    for blk in enriched:
        kind = blk[0]
        if kind == 'h1':
            _, num, title, label = blk
            lines.append(f'## {num}. {title}\n')
        elif kind == 'h2':
            _, letter, title = blk
            lines.append(f'### {letter}. {title}\n')
        elif kind == 'p':
            _, text, indent = blk
            lines.append(render_inline_md(text, refs) + '\n')
        elif kind == 'list':
            _, items, numbered = blk
            for idx, it in enumerate(items, start=1):
                pref = f'{idx}. ' if numbered else '- '
                lines.append(pref + render_inline_md(it, refs))
            lines.append('')
        elif kind == 'eq':
            _, num, latex, label = blk
            lines.append(f'$$\n{latex} \\tag{{{num}}}\n$$\n')
        elif kind == 'algo':
            _, num, label, title, alg_lines = blk
            lines.append(f'> **Algorithm {num}:** {render_inline_md(title, refs)}')
            lines.append('>')
            for idx, ln in enumerate(alg_lines, start=1):
                lines.append(f'> {idx}. {render_inline_md(ln, refs)}')
            lines.append('')
        elif kind == 'fig':
            _, num, label, key, caption, full, width = blk
            rel_png = f'figures/fig{num}_{key}.png'
            lines.append(f'![Fig. {num}]({rel_png})\n')
            lines.append(f'**Fig. {num}.** {render_inline_md(caption, refs)}\n')
        elif kind == 'table':
            _, num, label, caption, spec, full = blk
            lines.append(f'**TABLE {num}:** {render_inline_md(caption, refs)}\n')
            hdr = spec['cols']
            lines.append('| ' + ' | '.join(hdr) + ' |')
            lines.append('| ' + ' | '.join('---:' if a == 'r' else ':---' for a in spec['align']) + ' |')
            last_g = ''
            for row in spec['rows']:
                g = row[0] if row[0] is not None else last_g
                if row[0] is not None:
                    last_g = row[0]
                cells = [render_inline_md(g if c_i == 0 else (c or ''), refs) for c_i, c in enumerate(row)]
                lines.append('| ' + ' | '.join(cells) + ' |')
            lines.append('')

    lines.append('## References\n')
    for idx, ref in enumerate(content.REFERENCES, start=1):
        lines.append(f'[{idx}] {render_inline_md(ref, refs)}\n')

    md_path = os.path.join(PAPER_DIR, 'RESEARCH_PAPER_IEEE.md')
    with open(md_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    return md_path


# ===========================================================================
# MAIN
# ===========================================================================
def main():
    print('1. Building vector figures & 3x PNGs...')
    figs, metrics = figures.build_all()
    print(f'   Built {len(figs)} figures.')

    print('2. Resolving sections, equations, tables, figures, and cross-references...')
    body = content.build_body(metrics)
    enriched, refs = resolve_refs(body)
    print(f'   Resolved {len(refs)} cross-reference labels.')

    print('3. Building HTML + PDF...')
    html_path, pdf_path = build_html_and_pdf(enriched, refs, figs)
    print(f'   HTML: {html_path} ({os.path.getsize(html_path)/1024:.1f} KB)')
    print(f'   PDF:  {pdf_path} ({os.path.getsize(pdf_path)/1024:.1f} KB)')

    print('4. Building Word (.docx) with native OMML equations...')
    docx_path = build_docx(enriched, refs, figs)
    print(f'   DOCX: {docx_path} ({os.path.getsize(docx_path)/1024:.1f} KB)')

    print('5. Building LaTeX (.tex)...')
    tex_path = build_tex(enriched, refs, figs)
    print(f'   TEX:  {tex_path} ({os.path.getsize(tex_path)/1024:.1f} KB)')

    print('6. Building Markdown (.md)...')
    md_path = build_markdown(enriched, refs, figs)
    print(f'   MD:   {md_path} ({os.path.getsize(md_path)/1024:.1f} KB)')

    print('ALL FORMATS BUILT SUCCESSFULLY.')


if __name__ == '__main__':
    main()
