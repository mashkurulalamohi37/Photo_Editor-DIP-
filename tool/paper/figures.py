"""Vector figure builders for the DIP Studio paper.

Every figure is produced as a standalone SVG (vector text, embedded raster
panels where needed).  The SVGs are inlined into the HTML/PDF build and are
rasterised at 3x through headless Edge for the Word and LaTeX builds.
"""
import base64
import json
import os
import subprocess
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FIG_DIR = os.path.join(ROOT, 'paper', 'figures')
PANEL_DIR = os.path.join(FIG_DIR, 'panels')
EDGE = r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'

FONT = "Arial, Helvetica, 'Segoe UI', sans-serif"

# Operator-family palette, shared by Fig. 1 and the throughput chart.
FAMILY = {
    'A': ('#1d4ed8', '#eff6ff', 'Point & intensity'),
    'B': ('#0f766e', '#f0fdfa', 'Noise & restoration'),
    'C': ('#b45309', '#fffbeb', 'Sharpening & edges'),
    'D': ('#be123c', '#fff1f2', 'Segmentation'),
    'E': ('#6d28d9', '#f5f3ff', 'Morphology & geometry'),
    'S': ('#475569', '#f8fafc', 'Statistics'),
}

INK = '#0f172a'
BODY = '#334155'
MUTED = '#64748b'
LINE = '#cbd5e1'


def _esc(s):
    return s.replace('&', '&#38;').replace('<', '&#60;').replace('>', '&#62;')


def _text(x, y, s, size=11.5, weight='normal', fill=BODY, anchor='middle',
          style='normal', extra=''):
    return (f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" '
            f'font-style="{style}" fill="{fill}" text-anchor="{anchor}" {extra}>'
            f'{s}</text>')


def _rect(x, y, w, h, fill='#ffffff', stroke=LINE, sw=1, rx=4, extra=''):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}" {extra}/>')


def _arrow(points, color='#1e293b', sw=1.8, dash=None, marker='arr'):
    d = 'M ' + ' L '.join(f'{x} {y}' for x, y in points)
    da = f' stroke-dasharray="{dash}"' if dash else ''
    return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}"'
            f'{da} marker-end="url(#{marker})"/>')


# --------------------------------------------------------------------------
# Fig. 1 - system pipeline
# --------------------------------------------------------------------------
def pipeline_svg():
    W, H = 860, 400
    SPINE = 205
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
           f'width="{W}" height="{H}" font-family="{FONT}">',
           '<defs>'
           '<marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
           'markerHeight="7" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#1e293b"/></marker>'
           '<marker id="arrs" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5.5" '
           'markerHeight="5.5" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#475569"/></marker>'
           '</defs>',
           f'<rect width="{W}" height="{H}" fill="#ffffff"/>']

    stages = [  # x, width, title
        (6, 128, 'ACQUISITION'),
        (150, 128, 'DIGITIZATION'),
        (294, 128, 'MEMORY MODEL'),
        (438, 262, 'PROCESSING ENGINE'),
        (716, 138, 'ANALYSIS & UI'),
    ]
    PT, PB = 36, 352
    for i, (x, w, title) in enumerate(stages):
        out.append(_rect(x, PT, w, PB - PT, fill='#f8fafc', stroke=LINE, rx=6))
        cx = x + w / 2
        tw = len(title) * 7.4
        bx = cx - (tw + 22) / 2
        out.append(f'<circle cx="{bx + 8}" cy="20" r="8.5" fill="{INK}"/>')
        out.append(_text(bx + 8, 24, str(i + 1), 11, 'bold', '#ffffff'))
        out.append(_text(bx + 22, 24.5, _esc(title), 11.5, 'bold', INK, 'start',
                         extra='letter-spacing="0.6"'))

    def sub(x, w, label):
        out.append(_text(x + w / 2, 52, label, 10.5, 'normal', MUTED, style='italic'))

    def card(x, y, w, h, title, lines=(), tcolor=INK, dashed=False, fill='#ffffff',
             tsize=12, lsize=11.2):
        extra = 'stroke-dasharray="4 3"' if dashed else ''
        out.append(_rect(x, y, w, h, fill=fill, stroke=LINE if not dashed else '#94a3b8',
                         extra=extra))
        n = (1 if title else 0) + len(lines)
        step = 14.5
        y0 = y + h / 2 - (n - 1) * step / 2 + 4
        k = 0
        if title:
            out.append(_text(x + w / 2, y0, title, tsize, 'bold', tcolor))
            k = 1
        for j, ln in enumerate(lines):
            out.append(_text(x + w / 2, y0 + (k + j) * step, ln, lsize, 'normal', BODY))

    # ---- 1 acquisition ---------------------------------------------------
    x, w = 6, 128
    sub(x, w, 'input sources')
    for j, label in enumerate(['Camera capture', 'Gallery (JPEG/PNG)', 'Synthetic phantoms']):
        card(x + 8, 60 + j * 40, w - 16, 32, None, [label], lsize=11.2)
    out.append(_arrow([(x + w / 2, 172), (x + w / 2, 183)], marker='arrs', color='#475569', sw=1.4))
    card(x + 8, 185, w - 16, 40, None, ['Decode to', 'RGBA8888'], lsize=11.2)
    card(x + 8, 238, w - 16, 104, None,
         ['Platform codecs', 'only; no native', 'CV libraries', '(pure Dart, AOT)'],
         dashed=True, fill='#f8fafc', lsize=11)

    # ---- 2 digitization --------------------------------------------------
    x, w = 150, 128
    sub(x, w, 'discretization')
    card(x + 8, 60, w - 16, 76, 'Spatial sampling',
         ['x\u2032 = \u230Ax / S\u230B', 'S \u2208 {1, 2, 4, 8}'])
    out.append(_arrow([(x + w / 2, 136), (x + w / 2, 148)], marker='arrs', color='#475569', sw=1.4))
    card(x + 8, 150, w - 16, 76, 'Quantization',
         ['L = 2<tspan baseline-shift="super" font-size="8.5">k</tspan> gray levels',
          'k \u2208 {1, \u2026, 8} bits'])
    out.append(_arrow([(x + w / 2, 226), (x + w / 2, 238)], marker='arrs', color='#475569', sw=1.4))
    card(x + 8, 240, w - 16, 102, 'Storage cost',
         ['b = M \u00D7 N \u00D7 k', 'bits, shown live', 'in the calculator'])

    # ---- 3 memory model --------------------------------------------------
    x, w = 294, 128
    sub(x, w, 'single source of truth')
    out.append(_rect(x + 8, 60, w - 16, 282, fill='#1e293b', stroke='#1e293b', rx=5))
    cx = x + w / 2
    out.append(_text(cx, 80, 'PixelImage', 13, 'bold', '#ffffff'))
    out.append(_text(cx, 95, 'RGBA8888 Uint8List', 10.5, 'normal', '#cbd5e1'))
    gx, gy, cs = cx - 40, 106, 20
    for r in range(3):
        for c in range(4):
            hl = (r == 1 and c == 2)
            out.append(_rect(gx + c * cs, gy + r * cs, cs, cs,
                             fill='#f59e0b' if hl else '#334155',
                             stroke='#64748b', sw=0.8, rx=1.5))
    out.append(_text(gx + 2.5 * cs, gy + 1.5 * cs + 4, '(x,y)', 8.5, 'bold', INK))
    out.append(_arrow([(gx + 2.5 * cs, gy + 2 * cs + 1), (gx + 2.5 * cs, 182)],
                      color='#f59e0b', sw=1.4, marker='arrs'))
    bw = 13
    bx0 = cx - 4 * bw
    colors = ['#dc2626', '#16a34a', '#2563eb', '#94a3b8']
    for j in range(8):
        hl = j < 4
        out.append(_rect(bx0 + j * bw, 186, bw, 18, fill=colors[j % 4] if hl else '#475569',
                         stroke='#1e293b', sw=0.8, rx=1))
        out.append(_text(bx0 + j * bw + bw / 2, 199, 'RGBA'[j % 4], 10, 'bold', '#ffffff'))
    out.append(_text(cx, 226, 'i = 4(yW + x)', 12, 'bold', '#fde68a',
                     extra="font-family=\"Consolas, 'Courier New', monospace\""))
    for j, ln in enumerate(['row-major and', 'contiguous', 'O(MN) memory', 'new buffer per op']):
        out.append(_text(cx, 252 + j * 15, ln, 11, 'normal', '#e2e8f0'))
    out.append(_text(cx, 326, '\u2192 undo history', 11, 'bold', '#fde68a'))

    # ---- 4 processing engine ---------------------------------------------
    x, w = 438, 262
    sub(x, w, 'DipEngine: pure functions over the buffer')
    fams = [
        ('A', 'Point & intensity', ['Grayscale, negative, log, \u03B3-LUT', 'Stretch, histogram eq., HSV']),
        ('B', 'Noise & restoration', ['Impulse, Gaussian, speckle models', 'Mean, Gaussian, median filters']),
        ('C', 'Sharpening & edges', ['Laplacian, Sobel |\u2207f|, custom 3\u00D73', 'Canny: NMS + hysteresis']),
        ('D', 'Segmentation', ['Global and Otsu threshold T*', 'K-means, seeded region growing']),
        ('E', 'Morphology & geometry', ['Erosion \u2296, dilation \u2295', 'Rotate 90\u00B0, flip H / V']),
    ]
    cx0, cw, ch, gap, cy0 = x + 20, w - 34, 50, 8, 62
    busx, outx = x + 10, x + w - 7
    centers = []
    for j, (key, title, lines) in enumerate(fams):
        col, tint, _ = FAMILY[key]
        y = cy0 + j * (ch + gap)
        centers.append(y + ch / 2)
        out.append(_rect(cx0, y, cw, ch, fill='#ffffff', stroke=LINE))
        out.append(f'<rect x="{cx0}" y="{y}" width="6" height="{ch}" rx="2" fill="{col}"/>')
        out.append(_text(cx0 + 16, y + 17, f'{key}. {title}', 12, 'bold', col, 'start'))
        out.append(_text(cx0 + 16, y + 31, lines[0], 11, 'normal', BODY, 'start'))
        out.append(_text(cx0 + 16, y + 44, lines[1], 11, 'normal', BODY, 'start'))
    out.append(f'<line x1="{busx}" y1="{centers[0]}" x2="{busx}" y2="{centers[-1]}" '
               f'stroke="#1e293b" stroke-width="1.6"/>')
    out.append(f'<line x1="{outx}" y1="{centers[0]}" x2="{outx}" y2="{centers[-1]}" '
               f'stroke="#1e293b" stroke-width="1.6"/>')
    for c in centers:
        out.append(_arrow([(busx, c), (cx0 - 1, c)], sw=1.3, marker='arrs', color='#1e293b'))
        out.append(f'<line x1="{cx0 + cw}" y1="{c}" x2="{outx}" y2="{c}" stroke="#1e293b" stroke-width="1.3"/>')

    # ---- 5 analysis & UI -------------------------------------------------
    x, w = 716, 138
    sub(x, w, 'feedback to the user')
    ix, iw = x + 8, w - 16
    out.append(_rect(ix, 60, iw, 78))
    out.append(_text(ix + iw / 2, 76, 'Histogram &amp; stats', 12, 'bold', INK))
    hist = [3, 5, 9, 14, 20, 17, 12, 15, 22, 18, 11, 7, 5, 8, 6, 3]
    bw2 = (iw - 24) / len(hist)
    for j, v in enumerate(hist):
        out.append(f'<rect x="{ix + 12 + j * bw2:.1f}" y="{110 - v}" width="{bw2 - 1:.1f}" '
                   f'height="{v}" fill="{FAMILY["S"][0]}" opacity="0.75"/>')
    out.append(f'<line x1="{ix + 12 + 8.5 * bw2:.1f}" y1="84" x2="{ix + 12 + 8.5 * bw2:.1f}" y2="111" '
               f'stroke="#f59e0b" stroke-width="1.5" stroke-dasharray="2 2"/>')
    out.append(_text(ix + iw / 2, 128, '\u03BC, \u03C3, range, Otsu T*', 11, 'normal', BODY))
    card(ix, 146, iw, 50, 'Pixel inspector',
         ['D<tspan baseline-shift="sub" font-size="8.5">e</tspan>, '
          'D<tspan baseline-shift="sub" font-size="8.5">4</tspan>, '
          'D<tspan baseline-shift="sub" font-size="8.5">8</tspan> distances'])
    card(ix, 204, iw, 44, 'Before / after', ['hold-to-peek compare'])
    card(ix, 256, iw, 40, None, ['PNG export / share'])
    card(ix, 304, iw, 38, None, ['Undo / reset stack'])

    # ---- inter-stage arrows ---------------------------------------------
    for x1, x2 in [(134, 150), (278, 294)]:
        out.append(_arrow([(x1 - 2, SPINE), (x2 + 1, SPINE)], sw=2.2))
    out.append(_arrow([(420, SPINE), (448, SPINE)], sw=2.2))
    out.append(_arrow([(outx, SPINE), (717, SPINE)], sw=2.2))

    # ---- feedback loop ----------------------------------------------------
    lx1, lx2 = 785, 358
    out.append(_arrow([(lx1, PB), (lx1, 370), (lx2, 370), (lx2, PB + 2)],
                      color='#b45309', sw=1.6, dash='5 3'))
    out.append(_text((lx1 + lx2) / 2, 389,
                     'history loop: every result buffer can be re-fed as the next input (chained, undoable edits)',
                     11, 'normal', '#92400e', style='italic'))
    out.append('</svg>')
    return '\n'.join(out), (W, H)


# --------------------------------------------------------------------------
# Panel grids (Figs. 2-4)
# --------------------------------------------------------------------------
def _b64(name):
    with open(os.path.join(PANEL_DIR, name + '.png'), 'rb') as f:
        return base64.b64encode(f.read()).decode()


def panel_grid_svg(panels, cols, cell=150, gap=10, label_h=30, pixelated=False):
    rows = (len(panels) + cols - 1) // cols
    W = cols * cell + (cols - 1) * gap
    H = rows * (cell + label_h) + (rows - 1) * 4
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
           f'viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="{FONT}">',
           f'<rect width="{W}" height="{H}" fill="#ffffff"/>']
    style = ' style="image-rendering:pixelated"' if pixelated else ''
    for i, (name, label) in enumerate(panels):
        r, c = divmod(i, cols)
        x = c * (cell + gap)
        y = r * (cell + label_h + 4)
        out.append(f'<image x="{x}" y="{y}" width="{cell}" height="{cell}" '
                   f'preserveAspectRatio="none"{style} href="data:image/png;base64,{_b64(name)}"/>')
        out.append(_rect(x, y, cell, cell, fill='none', stroke='#94a3b8', sw=0.8, rx=0))
        out.append(_text(x + cell / 2, y + cell + 19, f'({chr(97 + i)}) {label}', 12.5, 'normal', INK))
    out.append('</svg>')
    return '\n'.join(out), (W, H)


def digitization_svg(m):
    d = m['digitization']
    def lab(key):
        e = d[key]
        return f"S={e['S']}, k={e['k']}"
    return panel_grid_svg([
        ('dig_a_s1_k8', lab('dig_a_s1_k8') + ' (ref.)'),
        ('dig_b_s8_k8', lab('dig_b_s8_k8')),
        ('dig_c_s1_k3', lab('dig_c_s1_k3')),
        ('dig_d_s1_k1', lab('dig_d_s1_k1')),
    ], cols=2, cell=160, pixelated=True)


def restoration_svg(m):
    r = m['restoration']
    return panel_grid_svg([
        ('rest_a_clean', 'Ground truth'),
        ('rest_b_sp', f"10% impulse, {r['sp_noisy']['psnr']:.2f} dB"),
        ('rest_c_sp_mean', f"Mean 3\u00D73, {r['sp_mean']['psnr']:.2f} dB"),
        ('rest_d_sp_median', f"Median 3\u00D73, {r['sp_median']['psnr']:.2f} dB"),
        ('rest_e_gauss', f"Gauss. \u03C3=20, {r['gauss_noisy']['psnr']:.2f} dB"),
        ('rest_f_gauss_filtered', f"Gauss. filter, {r['gauss_gaussian']['psnr']:.2f} dB"),
    ], cols=2, cell=160)


def segmentation_svg(m):
    c = m['contrast']
    return panel_grid_svg([
        ('seg_a_lowcontrast', f"Input, \u03C3={c['before']['std']:.1f}"),
        ('seg_b_equalized', f"Equalized, \u03C3={c['after']['std']:.1f}"),
        ('seg_c_otsu', f"Otsu, T*={m['segmentation']['otsu_threshold']}"),
        ('seg_d_canny', 'Canny edges'),
        ('seg_g_opening', 'Opening 5\u00D75 of (c)'),
        ('seg_f_kmeans', 'K-means, K=4'),
    ], cols=2, cell=160)


# --------------------------------------------------------------------------
# Throughput chart
# --------------------------------------------------------------------------
THROUGHPUT_512 = [  # (label, family, MP/s at 512x512)
    ('Gamma LUT', 'A', 251.43), ('Negative', 'A', 173.63), ('Log transform', 'A', 145.91),
    ('Grayscale', 'A', 125.81), ('Contrast stretch', 'A', 59.94), ('Hist. equalization', 'A', 14.07),
    ('256-bin histogram', 'S', 124.75),
    ('Mean 3\u00D73', 'B', 12.90), ('Gaussian 3\u00D73', 'B', 6.59), ('Median 3\u00D73', 'B', 1.71),
    ('Sobel', 'C', 7.69), ('Laplacian sharpen', 'C', 6.64), ('Canny', 'C', 4.09),
    ('Otsu threshold', 'D', 63.12), ('K-means (K=4)', 'D', 5.32),
    ('Flip horizontal', 'E', 120.48), ('Rotate 90\u00B0', 'E', 118.97),
    ('Dilation 3\u00D73', 'E', 10.54), ('Erosion 3\u00D73', 'E', 9.97),
]


def throughput_svg():
    import math
    W = 430
    left, right = 122, W - 40
    top = 52
    bh, bg = 11, 4
    n = len(THROUGHPUT_512)
    H = top + n * (bh + bg) + 46
    lo, hi = 0.0, 3.0  # log10 domain: 1 .. 1000 MP/s

    def X(v):
        return left + (math.log10(v) - lo) / (hi - lo) * (right - left)

    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" '
           f'height="{H}" font-family="{FONT}">', f'<rect width="{W}" height="{H}" fill="#ffffff"/>']
    # legend
    keys = ['A', 'B', 'C', 'D', 'E', 'S']
    for i, k in enumerate(keys):
        col, _, name = FAMILY[k]
        lx = 8 + (i % 3) * 142
        ly = 10 + (i // 3) * 17
        out.append(f'<rect x="{lx}" y="{ly}" width="11" height="11" rx="2" fill="{col}"/>')
        out.append(_text(lx + 16, ly + 10, _esc(name), 11.5, 'normal', BODY, 'start'))
    # grid
    yb = top + n * (bh + bg)
    for e in range(0, 4):
        gx = X(10 ** e)
        out.append(f'<line x1="{gx}" y1="{top - 6}" x2="{gx}" y2="{yb}" stroke="#e2e8f0" stroke-width="1"/>')
        out.append(_text(gx, yb + 15, str(10 ** e), 11.5, 'normal', BODY))
        if e < 3:
            for m in range(2, 10):
                mx = X(m * 10 ** e)
                out.append(f'<line x1="{mx}" y1="{yb}" x2="{mx}" y2="{yb + 3}" stroke="#94a3b8" stroke-width="0.8"/>')
    out.append(f'<line x1="{left}" y1="{yb}" x2="{right}" y2="{yb}" stroke="#475569" stroke-width="1"/>')
    out.append(f'<line x1="{left}" y1="{top - 6}" x2="{left}" y2="{yb}" stroke="#475569" stroke-width="1"/>')
    for i, (label, fam, v) in enumerate(THROUGHPUT_512):
        y = top + i * (bh + bg)
        col = FAMILY[fam][0]
        out.append(_text(left - 6, y + bh - 1.5, _esc(label), 11.5, 'normal', INK, 'end'))
        out.append(f'<rect x="{left}" y="{y}" width="{X(v) - left:.1f}" height="{bh}" fill="{col}"/>')
        out.append(_text(X(v) + 4, y + bh - 1.5, f'{v:.1f}', 10.5, 'normal', BODY, 'start'))
    out.append(_text((left + right) / 2, yb + 33, 'Throughput at 512 \u00D7 512 (MP/s, log scale)',
                     12, 'bold', INK))
    out.append('</svg>')
    return '\n'.join(out), (W, H)


# --------------------------------------------------------------------------
def build_all():
    with open(os.path.join(PANEL_DIR, 'metrics.json'), encoding='utf-8') as f:
        metrics = json.load(f)
    figs = {
        'pipeline': pipeline_svg(),
        'digitization': digitization_svg(metrics),
        'restoration': restoration_svg(metrics),
        'segmentation': segmentation_svg(metrics),
        'throughput': throughput_svg(),
    }
    paths = {}
    for i, (key, (svg, size)) in enumerate(figs.items(), start=1):
        base = os.path.join(FIG_DIR, f'fig{i}_{key}')
        with open(base + '.svg', 'w', encoding='utf-8') as f:
            f.write(svg)
        rasterize(svg, size, base + '.png')
        paths[key] = {'svg': base + '.svg', 'png': base + '.png', 'size': size,
                      'inline': svg}
    return paths, metrics


def rasterize(svg, size, png_path, scale=3):
    W, H = size
    html = ('<!DOCTYPE html><html><head><meta charset="utf-8"><style>'
            'html,body{margin:0;padding:0;background:#fff;overflow:hidden}'
            f'svg{{display:block;width:{W}px;height:{H}px}}</style></head><body>'
            f'{svg}</body></html>')
    tmpdir = tempfile.mkdtemp(prefix='dipfig_')
    page = os.path.join(tmpdir, 'fig.html')
    with open(page, 'w', encoding='utf-8') as f:
        f.write(html)
    if os.path.exists(png_path):
        os.remove(png_path)
    subprocess.run([
        EDGE, '--headless=new', '--disable-gpu', '--hide-scrollbars',
        f'--user-data-dir={os.path.join(tmpdir, "profile")}',
        f'--force-device-scale-factor={scale}', f'--window-size={W},{H}',
        f'--screenshot={png_path}', 'file:///' + page.replace('\\', '/'),
    ], check=True, capture_output=True)
    if not os.path.exists(png_path):
        raise RuntimeError(f'rasterisation failed for {png_path}')


if __name__ == '__main__':
    p, _ = build_all()
    for k, v in p.items():
        print(k, v['png'], os.path.getsize(v['png']))
