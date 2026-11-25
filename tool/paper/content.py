"""Single source of truth for the DIP Studio research paper.

Inline markup understood by every renderer (HTML/PDF, Word, LaTeX, Markdown):
  <b>..</b>  <i>..</i>  <code>..</code>   $LaTeX math$
  [n]           numeric citation
  {fig:key} {tab:key} {eq:key} {alg:key} {sec:key}   cross references
"""

TITLE = ('DIP Studio: A Dependency-Free Cross-Platform Engine for Real-Time '
         'Digital Image Processing on Mobile and Edge Devices')
SHORT_TITLE = 'DIP STUDIO: DEPENDENCY-FREE REAL-TIME IMAGE PROCESSING ENGINE'

ABSTRACT = (
    'Classical digital image processing (DIP) operators remain essential wherever results must be '
    'deterministic, explainable, and computable on modest hardware. Bringing a complete operator suite '
    'to mobile devices, however, usually means bundling native C/C++ libraries through platform-specific '
    'bindings, which inflates application size and complicates maintenance. This paper presents DIP Studio, '
    'a cross-platform image processing engine and application written entirely in ahead-of-time (AOT) '
    'compiled Dart, with no native vision dependencies. Every operator acts directly on one contiguous '
    'RGBA8888 byte buffer, and the system is organized as a five-stage pipeline: acquisition, digitization, '
    'memory model, processing engine, and analysis. The engine covers spatial sampling and $k$-bit '
    'quantization, intensity transformations, histogram equalization, linear and order-statistic filtering, '
    'Laplacian and Sobel differentiation, Canny edge detection, Otsu thresholding, $K$-means clustering, '
    'seeded region growing, and grayscale morphology. We formalize each operator, state its complexity, '
    'and benchmark the implementation at $256^2$, $512^2$, and $1024^2$ pixels. Point operations reach '
    '280.8 MP/s and histogram computation 127.4 MP/s at one megapixel. On a synthetic phantom corrupted by '
    '10% impulse noise, a $3\\times3$ median filter raises PSNR from 14.40 dB to 31.45 dB (+17.05 dB), '
    '9.64 dB above an equally sized mean filter. The complete Android release build occupies 19.9 MB. '
    'These results show that a dependency-free, memory-safe implementation is a practical basis for '
    'interactive DIP education and lightweight edge vision.'
)

INDEX_TERMS = ('Digital image processing, spatial filtering, histogram equalization, Otsu thresholding, '
               'Canny edge detection, K-means clustering, mathematical morphology, image restoration, '
               'mobile computing, edge vision.')


def H1(title, label=None): return ('h1', title, label)
def H2(title): return ('h2', title)
def P(text, indent=True): return ('p', text, indent)
def EQ(latex, label=None): return ('eq', latex, label)
def LIST(items, numbered=False): return ('list', items, numbered)
def FIG(label, key, caption, full=False, width=None): return ('fig', label, key, caption, full, width)
def TABLE(label, caption, spec, full=False): return ('table', label, caption, spec, full)
def ALGO(label, title, lines): return ('algo', label, title, lines)


TABLE_OPERATORS = {
    'cols': ['Fam.', 'Operator', 'Parameters', 'Cost'],
    'align': ['l', 'l', 'l', 'l'],
    'widths': [0.10, 0.36, 0.27, 0.27],
    'header': [[('Fam.', 1, 1), ('Operator', 1, 1), ('Parameters', 1, 1), ('Cost', 1, 1)]],
    'rows': [
        ['A', 'Grayscale, negative, log', '\u2014', '$O(MN)$'],
        [None, 'Power-law (gamma)', '$\\gamma$, 256-entry LUT', '$O(MN+L)$'],
        [None, 'Contrast stretch', '$r_{\\min}, r_{\\max}$', '$O(MN)$'],
        [None, 'Histogram equalization', 'RGB or HSV value', '$O(MN+L)$'],
        ['B', 'Mean / Gaussian filter', '$k\\times k$, $\\sigma$', '$O(MNk^2)$'],
        [None, 'Median filter', '$k\\times k$', '$O(MNk^2\\log k)$'],
        ['C', 'Laplacian, Sobel, custom', '$3\\times3$ kernel', '$O(MN)$'],
        [None, 'Canny edge detector', '$T_{\\mathrm{low}}, T_{\\mathrm{high}}$', '$O(MN)$'],
        ['D', 'Otsu threshold', 'automatic $T^{*}$', '$O(MN+L^2)$'],
        [None, '$K$-means clustering', '$K$, iterations $I$', '$O(MNKI)$'],
        [None, 'Seeded region growing', 'seed, tolerance', '$O(MN)$'],
        ['E', 'Erosion / dilation', '$3\\times3$ or $5\\times5$', '$O(MNk^2)$'],
        [None, 'Rotate $90^{\\circ}$, flip', '\u2014', '$O(MN)$'],
    ],
}

_B = [  # name, fam, (ms, MP/s) at 256, 512, 1024
    ('Point', 'Grayscale (BT.601)', ('0.68', '96.07'), ('2.08', '125.81'), ('7.56', '138.69')),
    (None, 'Negative', ('0.77', '85.13'), ('1.51', '173.63'), ('4.84', '216.73')),
    (None, 'Log transform', ('0.93', '70.77'), ('1.80', '145.91'), ('3.73', '<b>280.83</b>')),
    (None, 'Gamma LUT ($\\gamma=0.65$)', ('0.28', '236.42'), ('1.04', '251.43'), ('4.50', '232.80')),
    (None, 'Contrast stretch', ('2.12', '30.97'), ('4.37', '59.94'), ('12.75', '82.21')),
    ('Statistics', '256-bin histogram', ('0.34', '192.08'), ('2.10', '124.75'), ('8.23', '127.41')),
    (None, 'Histogram equalization', ('5.47', '11.98'), ('18.63', '14.07'), ('70.82', '14.81')),
    (None, 'Otsu threshold', ('1.25', '52.50'), ('4.15', '63.12'), ('13.09', '80.09')),
    ('Filtering', 'Mean $3\\times3$', ('6.35', '10.32'), ('20.32', '12.90'), ('86.48', '12.12')),
    (None, 'Gaussian $3\\times3$, $\\sigma=1.2$', ('11.26', '5.82'), ('39.79', '6.59'), ('151.72', '6.91')),
    (None, 'Median $3\\times3$', ('47.82', '1.37'), ('153.10', '1.71'), ('588.55', '1.78')),
    (None, 'Laplacian sharpen (8-N)', ('14.00', '4.68'), ('39.47', '6.64'), ('154.92', '6.77')),
    (None, 'Sobel gradient', ('11.35', '5.77'), ('34.09', '7.69'), ('108.10', '9.70')),
    ('Segmentation', 'Canny edge detector', ('19.99', '3.28'), ('64.14', '4.09'), ('\u2014', '\u2014')),
    (None, '$K$-means ($K=4$, $I=5$)', ('14.23', '4.61'), ('49.23', '5.32'), ('\u2014', '\u2014')),
    (None, 'Erosion $3\\times3$', ('7.15', '9.17'), ('26.29', '9.97'), ('\u2014', '\u2014')),
    (None, 'Dilation $3\\times3$', ('6.23', '10.52'), ('24.88', '10.54'), ('\u2014', '\u2014')),
    ('Geometry', 'Rotate $90^{\\circ}$ clockwise', ('1.24', '52.67'), ('2.20', '118.97'), ('12.10', '86.63')),
    (None, 'Horizontal flip', ('1.00', '65.24'), ('2.18', '120.48'), ('5.29', '198.13')),
]

TABLE_BENCH = {
    'cols': ['Group', 'Operator', 't256', 'r256', 't512', 'r512', 't1024', 'r1024'],
    'align': ['l', 'l', 'r', 'r', 'r', 'r', 'r', 'r'],
    'widths': [0.13, 0.25, 0.10, 0.10, 0.10, 0.10, 0.11, 0.11],
    'header': [
        [('Group', 1, 2), ('Operator', 1, 2), ('$256\\times256$ (0.07 MP)', 2, 1),
         ('$512\\times512$ (0.26 MP)', 2, 1), ('$1024\\times1024$ (1.05 MP)', 2, 1)],
        [('ms', 1, 1), ('MP/s', 1, 1), ('ms', 1, 1), ('MP/s', 1, 1), ('ms', 1, 1), ('MP/s', 1, 1)],
    ],
    'rows': [[g, n, a[0], a[1], b[0], b[1], c[0], c[1]] for g, n, a, b, c in _B],
}


def build_body(m):
    """Return the ordered list of body blocks.  `m` holds engine-measured metrics."""
    r = m['restoration']
    cb, ca = m['contrast']['before'], m['contrast']['after']
    otsu_t = m['segmentation']['otsu_threshold']
    d = m['digitization']

    table_restoration = {
        'cols': ['Noise', 'Output', 'MSE', 'PSNR (dB)', '$\\Delta$ (dB)'],
        'align': ['l', 'l', 'r', 'r', 'r'],
        'widths': [0.20, 0.30, 0.15, 0.17, 0.18],
        'header': [[('Noise', 1, 1), ('Output', 1, 1), ('MSE', 1, 1), ('PSNR (dB)', 1, 1),
                    ('$\\Delta$PSNR', 1, 1)]],
        'rows': [
            ['Impulse 10%', 'Noisy input', f"{r['sp_noisy']['mse']:.2f}", f"{r['sp_noisy']['psnr']:.2f}", '\u2014'],
            [None, 'Mean $3\\times3$', f"{r['sp_mean']['mse']:.2f}", f"{r['sp_mean']['psnr']:.2f}",
             f"+{r['sp_mean']['psnr'] - r['sp_noisy']['psnr']:.2f}"],
            [None, '<b>Median $3\\times3$</b>', f"<b>{r['sp_median']['mse']:.2f}</b>",
             f"<b>{r['sp_median']['psnr']:.2f}</b>",
             f"<b>+{r['sp_median']['psnr'] - r['sp_noisy']['psnr']:.2f}</b>"],
            ['Gaussian $\\sigma=20$', 'Noisy input', f"{r['gauss_noisy']['mse']:.2f}",
             f"{r['gauss_noisy']['psnr']:.2f}", '\u2014'],
            [None, 'Mean $3\\times3$', f"{r['gauss_mean']['mse']:.2f}", f"{r['gauss_mean']['psnr']:.2f}",
             f"+{r['gauss_mean']['psnr'] - r['gauss_noisy']['psnr']:.2f}"],
            [None, '<b>Gaussian $3\\times3$</b>', f"<b>{r['gauss_gaussian']['mse']:.2f}</b>",
             f"<b>{r['gauss_gaussian']['psnr']:.2f}</b>",
             f"<b>+{r['gauss_gaussian']['psnr'] - r['gauss_noisy']['psnr']:.2f}</b>"],
        ],
    }

    table_contrast = {
        'cols': ['Image', 'Range', 'Spread', 'Levels', 'Mean', 'Std'],
        'align': ['l', 'r', 'r', 'r', 'r', 'r'],
        'widths': [0.22, 0.17, 0.14, 0.14, 0.16, 0.17],
        'header': [[('Image', 1, 1), ('$[r_{\\min}, r_{\\max}]$', 1, 1), ('Spread', 1, 1),
                    ('Levels', 1, 1), ('$\\mu$', 1, 1), ('$\\sigma$', 1, 1)]],
        'rows': [
            ['Input', f"[{cb['min']}, {cb['max']}]", str(cb['spread']), str(cb['occupiedLevels']),
             f"{cb['mean']:.2f}", f"{cb['std']:.2f}"],
            ['Equalized', f"[{ca['min']}, {ca['max']}]", f"<b>{ca['spread']}</b>", str(ca['occupiedLevels']),
             f"{ca['mean']:.2f}", f"<b>{ca['std']:.2f}</b>"],
        ],
    }

    gain_sp = r['sp_median']['psnr'] - r['sp_noisy']['psnr']
    med_vs_mean = r['sp_median']['psnr'] - r['sp_mean']['psnr']
    std_gain = 100.0 * (ca['std'] / cb['std'] - 1.0)

    return [
        # ------------------------------------------------------------- I
        H1('Introduction', 'intro'),
        P('Digital image processing (DIP) studies the transformation, enhancement, and analysis of '
          'two-dimensional signals that have been discretized in both space and amplitude [1]. Although '
          'learned models now dominate high-level recognition, classical operators such as intensity '
          'mappings, spatial filters, thresholding, and mathematical morphology remain the first stage of '
          'almost every vision pipeline, and they are the core of DIP teaching [1], [3], [12]. Their '
          'behaviour is deterministic and fully explainable, which matters in forensic, metrological, and '
          'medical settings where every pixel change must be justified [5], [6].', indent=False),
        P('Deploying a complete operator suite on phones and tablets is nevertheless awkward. Mature '
          'libraries such as OpenCV [4] are written in C/C++ and reach mobile applications through '
          'foreign-function interfaces and per-ABI native binaries. This adds build complexity, enlarges the '
          'installed package, and moves memory safety outside the guarantees of the host language. '
          'Interactive teaching tools face a second problem: the user must see the image, the controls, '
          'and live statistics such as the histogram on a small screen at once.'),
        P('This paper presents <b>DIP Studio</b>, an engine and application that implements the standard '
          'DIP curriculum in pure, AOT-compiled Dart on top of the Flutter toolkit, with no native vision '
          'library. All operators read and write one contiguous RGBA8888 buffer, so a result can be '
          'displayed, measured, exported, or fed into the next operator without conversion. The '
          'contributions are as follows.'),
        LIST([
            '<b>Architecture.</b> A five-stage pipeline (acquisition, digitization, memory model, processing '
            'engine, analysis) built around a single linear pixel buffer and pure operator functions '
            '(Section {sec:arch}, Fig. {fig:pipeline}).',
            '<b>Formulation.</b> A unified mathematical description of 20+ operators in five families, '
            'with their asymptotic cost (Section {sec:math}, Table {tab:ops}).',
            '<b>Evaluation.</b> Latency and throughput at three resolutions, together with MSE/PSNR '
            'restoration and contrast measurements computed by the same engine (Section {sec:eval}).',
            '<b>Deployment.</b> A 19.9 MB Android release build with a canvas-first interface that hides '
            'tool panels until they are needed (Section {sec:ui}).',
        ]),
        P('Section {sec:related} reviews related work. Section {sec:arch} describes the architecture, '
          'Section {sec:math} the operators, and Section {sec:eval} the experiments. Section {sec:disc} '
          'discusses limitations, and Section {sec:concl} concludes.'),

        # ------------------------------------------------------------- II
        H1('Related Work', 'related'),
        H2('Image Processing Libraries'),
        P('OpenCV [4] is the de facto standard for native computer vision and provides highly optimized, '
          'often SIMD-accelerated, kernels. On Android it is used through Java or JNI wrappers around '
          'per-architecture shared libraries. Python ecosystems such as scikit-image [19] favour readable, '
          'NumPy-based implementations and are widely used for teaching and research, but they are not '
          'designed for on-device mobile deployment. ImageJ [20] offers an extensible desktop workbench for '
          'scientific imaging. DIP Studio targets the gap between these tools: a self-contained mobile '
          'application whose operators are as readable as a textbook yet compiled to native code.',
          indent=False),
        H2('Classical Operators'),
        P('The engine implements well-established methods: histogram equalization and its adaptive '
          'variants [10], order-statistic median filtering [7], Laplacian and gradient-based edge '
          'detection [18], the Canny detector [8], Otsu thresholding [5], $K$-means clustering [9], seeded '
          'region growing [14], and mathematical morphology [6], [13]. Our aim is not new operators; it is a '
          'transparent, dependency-free implementation that reproduces the textbook formulation exactly '
          'and is fast enough for interactive use.', indent=False),

        # ------------------------------------------------------------- III
        H1('System Architecture', 'arch'),
        P('Fig. {fig:pipeline} summarizes the pipeline. Data flows left to right through five stages, and '
          'the history loop at the bottom lets any result become the next input.', indent=False),
        FIG('pipeline', 'pipeline',
            'Architecture of DIP Studio. Images from three sources are decoded once, optionally '
            're-digitized, and stored in a single RGBA8888 buffer. Five operator families (A\u2013E) map '
            'buffers to new buffers, and the analysis layer reports histogram statistics, pixel-level '
            'measurements, and before/after comparisons. Each result is pushed onto an undo stack and can be '
            'chained into the next operation.', full=True),
        H2('Acquisition and Digitization'),
        P('Images enter from the camera, the gallery (JPEG/PNG), or one of four analytic phantoms generated '
          'on the device (a sunset scene, a low-contrast ring phantom, a coin/cell scene, and a test card). '
          'The phantoms give reproducible inputs for teaching and benchmarking. Platform codecs decode every '
          'source into RGBA8888. The digitization stage then simulates spatial sampling with factor $S$ and '
          'intensity quantization with $k$ bits (Section {sec:math}-A) and reports the storage cost live.',
          indent=False),
        H2('Memory Model'),
        P('An image is a <code>PixelImage</code>: width $W$, height $H$, and a <code>Uint8List</code> of '
          '$4WH$ bytes in row-major order. Channel $c\\in\\{0,1,2,3\\}$ of pixel $(x, y)$ is stored at',
          indent=False),
        EQ('i(x, y, c) = 4\\,(yW + x) + c,', 'offset'),
        P('so neighbourhood access is plain integer arithmetic and a raster scan touches memory '
          'sequentially, which suits hardware prefetchers. Operators never mutate their input; each returns '
          'a new buffer. This makes undo trivial, keeps the operators free of side effects, and lets the UI '
          'compare any two states.', indent=False),
        H2('Processing Engine'),
        P('The engine is a set of static, pure functions grouped into five families (Table {tab:ops}). '
          'Point operators that depend only on the input intensity are compiled into 256-entry look-up '
          'tables (LUTs), so their per-pixel cost is a single indexed load. Neighbourhood operators use '
          'replicated borders. Colour images are processed per channel, except where a luminance or HSV '
          'formulation is required to avoid hue shifts.', indent=False),
        TABLE('ops', 'Operator families implemented in DIP Studio and their asymptotic cost '
              '($M\\times N$ image, $k\\times k$ window, $L=256$ levels)', TABLE_OPERATORS),
        H2('Analysis and Interaction Layer', ),
        P('After every operation the engine recomputes red, green, blue, and luminance histograms together '
          'with the mean $\\mu$, standard deviation $\\sigma$, intensity range, and Otsu threshold $T^{*}$. '
          'A pixel inspector reports RGB and gray values and the Euclidean, city-block, and chessboard '
          'distances between two probed points. The user can hold the canvas to peek at the original image, '
          'export the result as PNG, and undo or reset the history.', indent=False),
        ('label', 'ui'),
        P('The interface is canvas-first. Tools are grouped into five tabs (<i>Enhance</i>, <i>Filters & '
          'Noise</i>, <i>Segment</i>, <i>Digitize</i>, <i>Inspect</i>) inside a drawer that stays collapsed '
          'by default, and the histogram can shrink to a single row of statistics. The image therefore keeps '
          'most of the screen, and the controls appear only when requested.'),

        # ------------------------------------------------------------- IV
        H1('Mathematical Formulation', 'math'),
        H2('Digitization'),
        P('A continuous scene $f(x, y)$ is sampled on an $M\\times N$ grid and each sample is quantized to '
          '$L$ levels. With $k$ bits per sample,', indent=False),
        EQ('L = 2^{k}, \\qquad b = M \\times N \\times k', 'bits'),
        P('where $b$ is the storage in bits; a $1024\\times1024$ 8-bit image needs $b = 8{,}388{,}608$ bits '
          '(1 MiB). DIP Studio simulates coarser sampling with factor $S$ and coarser quantization with '
          '$k\' < 8$ bits:', indent=False),
        EQ('f_q(x, y) = \\left\\lfloor \\frac{f(S\\lfloor x/S \\rfloor,\\, S\\lfloor y/S \\rfloor)}{256/2^{k\'}} '
           '\\right\\rfloor \\cdot \\frac{255}{2^{k\'}-1}', 'quant'),
        P(f'Fig. {{fig:digit}} shows both effects. Sampling with $S=8$ produces block artefacts '
          f'({d["dig_b_s8_k8"]["psnr"]:.2f} dB PSNR against the reference), whereas $k=3$ introduces false '
          f'contours in smooth gradients ({d["dig_c_s1_k3"]["psnr"]:.2f} dB) and $k=1$ leaves a binary image '
          f'per channel ({d["dig_d_s1_k1"]["psnr"]:.2f} dB).'),
        FIG('digit', 'digitization',
            'Spatial sampling and intensity quantization computed by the engine on the sunset phantom: '
            '(a) reference, (b) sampling factor $S=8$, (c) $k=3$ bits per channel, and (d) $k=1$ bit per '
            'channel.'),
        H2('Point Operations'),
        P('A point operation $s = T(r)$ maps an input level $r\\in[0, L-1]$ to an output level $s$ '
          'independently of the neighbourhood. Luminance follows ITU-R BT.601 [11]:', indent=False),
        EQ('Y = 0.299R + 0.587G + 0.114B', 'gray'),
        P('The negative, logarithmic, and power-law (gamma) transformations are', indent=False),
        EQ('s = (L-1) - r, \\qquad s = c\\,\\ln(1+r), \\qquad s = (L-1)\\left(\\frac{r}{L-1}\\right)^{\\gamma}', 'point'),
        P('where $c = (L-1)/\\ln(1+r_{\\max})$ maps the brightest input to $L-1$. Contrast stretching maps '
          'the occupied range $[r_{\\min}, r_{\\max}]$ linearly onto the full scale:', indent=False),
        EQ('s = \\frac{r - r_{\\min}}{r_{\\max} - r_{\\min}}\\,(L-1)', 'stretch'),
        H2('Histogram Equalization'),
        P('Let $n_k$ be the number of pixels with level $r_k$. The normalized histogram and the '
          'equalizing transformation are [1], [10]', indent=False),
        EQ('p_r(r_k) = \\frac{n_k}{MN}, \\qquad s_k = (L-1)\\sum_{j=0}^{k} p_r(r_j)', 'he'),
        P('Equalizing $R$, $G$, and $B$ independently shifts hues, so colour images are equalized either on '
          'luminance, with all channels scaled by $T(Y)/Y$, or on the HSV value channel with hue and '
          'saturation unchanged.'),
        H2('Spatial Filtering'),
        P('A $(2a+1)\\times(2b+1)$ kernel $w$ is applied by correlation; convolution is the same operation '
          'with the kernel rotated by $180^{\\circ}$:', indent=False),
        EQ('g(x, y) = \\sum_{s=-a}^{a}\\sum_{t=-b}^{b} w(s, t)\\, f(x+s,\\, y+t)', 'corr'),
        P('The engine provides box (mean) filters, sampled Gaussian kernels', indent=False),
        EQ('G(x, y) = \\frac{1}{2\\pi\\sigma^{2}} \\exp\\!\\left(-\\frac{x^{2}+y^{2}}{2\\sigma^{2}}\\right)', 'gauss'),
        P('normalized to unit sum, and arbitrary user-defined $3\\times3$ kernels. The median filter replaces '
          'each pixel with the median of its window $W$ [7]:', indent=False),
        EQ('g(x, y) = \\operatorname{median}\\{\\, f(x+s,\\, y+t) : (s, t) \\in W \\,\\}', 'median'),
        P('Impulse noise sets isolated pixels to 0 or 255; these values fall at the ends of the sorted window '
          'and never become the median, so the filter removes them without averaging them into neighbouring '
          'edges.'),
        H2('Sharpening and Edge Detection'),
        P('The Laplacian $\\nabla^2 f = \\partial^2 f/\\partial x^2 + \\partial^2 f/\\partial y^2$ is '
          'discretized with the 4- or 8-neighbour kernels', indent=False),
        EQ('w_4 = \\begin{bmatrix} 0 & 1 & 0 \\\\ 1 & -4 & 1 \\\\ 0 & 1 & 0 \\end{bmatrix}, \\qquad '
           'w_8 = \\begin{bmatrix} 1 & 1 & 1 \\\\ 1 & -8 & 1 \\\\ 1 & 1 & 1 \\end{bmatrix}', 'lap'),
        P('and the image is sharpened by $g = f - c\\,\\nabla^2 f$. Sobel derivatives $G_x$ and $G_y$ give '
          'the gradient magnitude and direction', indent=False),
        EQ('|\\nabla f| = \\sqrt{G_x^{2} + G_y^{2}}, \\qquad \\theta = \\operatorname{atan2}(G_y, G_x)', 'sobel'),
        P('The Canny detector [8] chains Gaussian smoothing, Sobel gradients, non-maximum suppression along '
          '$\\theta$ quantized to $0^{\\circ}$, $45^{\\circ}$, $90^{\\circ}$, and $135^{\\circ}$, double '
          'thresholding with $T_{\\mathrm{low}}=35$ and $T_{\\mathrm{high}}=85$, and 8-connected hysteresis.'),
        H2('Segmentation'),
        P('Otsu\'s method [5] chooses the threshold that maximizes the between-class variance of the '
          'luminance histogram:', indent=False),
        EQ('\\sigma_B^{2}(T) = \\omega_0(T)\\,\\omega_1(T)\\,[\\mu_0(T) - \\mu_1(T)]^{2}', 'otsu'),
        P('and selects $T^{*} = \\operatorname{arg\\,max}_{T}\\,\\sigma_B^{2}(T)$, where $\\omega_i$ and $\\mu_i$ '
          'are the probability and mean of the two classes. Algorithm {alg:otsu} lists the single-pass '
          'procedure used by the engine. $K$-means [9] clusters the RGB vectors $\\mathbf{x}_i$ by '
          'minimizing the within-cluster sum of squares', indent=False),
        EQ('J = \\sum_{j=1}^{K} \\sum_{\\mathbf{x}_i \\in C_j} \\lVert \\mathbf{x}_i - \\mathbf{m}_j \\rVert^{2}', 'kmeans'),
        P('with Lloyd iterations, and seeded region growing [14] adds 4- or 8-connected neighbours whose '
          'intensity lies within a tolerance of the seed.'),
        ALGO('otsu', 'Otsu threshold selection from a 256-bin histogram', [
            '<b>Input:</b> luminance histogram $h[0..L-1]$, pixel count $N$',
            '$p_i \\leftarrow h[i]/N$;  $\\mu_T \\leftarrow \\sum_i i\\,p_i$',
            '$\\omega \\leftarrow 0$;  $\\mu \\leftarrow 0$;  $\\sigma^{*} \\leftarrow 0$;  $T^{*} \\leftarrow 0$',
            '<b>for</b> $T = 0$ <b>to</b> $L-2$ <b>do</b>',
            '\u2003$\\omega \\leftarrow \\omega + p_T$;  $\\mu \\leftarrow \\mu + T\\,p_T$',
            '\u2003<b>if</b> $\\omega = 0$ <b>or</b> $\\omega = 1$ <b>then continue</b>',
            '\u2003$\\sigma_B^{2} \\leftarrow (\\mu_T\\,\\omega - \\mu)^{2} / (\\omega(1-\\omega))$',
            '\u2003<b>if</b> $\\sigma_B^{2} > \\sigma^{*}$ <b>then</b> $\\sigma^{*} \\leftarrow \\sigma_B^{2}$;  $T^{*} \\leftarrow T$',
            '<b>return</b> $T^{*}$',
        ]),
        H2('Morphology and Distance Metrics'),
        P('Grayscale erosion and dilation with a flat structuring element $B$ are [6], [13]', indent=False),
        EQ('(f \\ominus B)(x, y) = \\min_{(s,t)\\in B} f(x+s,\\, y+t)', 'erode'),
        EQ('(f \\oplus B)(x, y) = \\max_{(s,t)\\in B} f(x-s,\\, y-t)', 'dilate'),
        P('and opening, erosion followed by dilation, removes structures smaller than $B$. For two pixels '
          '$p=(x, y)$ and $q=(s, t)$ the inspector reports Euclidean, city-block, and chessboard distances:', indent=False),
        EQ('D_e = \\sqrt{(x-s)^{2} + (y-t)^{2}}', 'dist_e'),
        EQ('D_4 = |x-s| + |y-t|, \\;\\; D_8 = \\max(|x-s|, |y-t|)', 'dist_48'),

        # ------------------------------------------------------------- V
        H1('Experimental Evaluation', 'eval'),
        H2('Setup'),
        P('All measurements were produced by the engine itself through two scripts in the repository: '
          '<code>tool/benchmark_suite.dart</code> for timing and <code>tool/export_paper_figures.dart</code> '
          'for the figures and quality metrics. Timing runs used the Dart VM on a laptop with an AMD Ryzen 5 '
          '7520U (x86-64, up to 2.8 GHz base clock), single-threaded. Each value is the mean of five '
          'consecutive runs after a warm-up call, on the synthetic sunset scene at $256^2$, $512^2$, and '
          '$1024^2$ pixels. Times exclude decoding and display. Canny, $K$-means, and morphology were '
          'benchmarked only up to $512^2$.', indent=False),
        H2('Latency and Throughput'),
        P('Table {tab:bench} lists latency and throughput, and Fig. {fig:thr} compares all operators at '
          '$512^2$. Point operators and geometric transforms run at roughly 60 to 280 MP/s, so even a '
          '1-MP image is processed in 4 to 13 ms. LUT-based gamma correction is the fastest operator at the '
          'two smaller sizes, and throughput generally rises with resolution as fixed per-call overhead is '
          'amortized. Neighbourhood operators are one to two orders of magnitude slower, as their '
          '$O(MNk^2)$ cost predicts. The median filter is the slowest (1.7 MP/s) because it sorts nine '
          'values per pixel and channel; a $512^2$ image still takes 153 ms, fast enough for interactive '
          'use.', indent=False),
        TABLE('bench', 'Execution latency (ms) and throughput (MP/s) of the DIP Studio engine; mean of five '
              'runs, single thread', TABLE_BENCH, full=True),
        FIG('thr', 'throughput',
            'Throughput of each operator at $512\\times512$ on a logarithmic axis, coloured by operator family '
            'as in Fig. 1. Point and geometric operators exceed 100 MP/s in most cases; windowed operators '
            'fall to 2\u201313 MP/s.'),
        H2('Noise Restoration'),
        P('Restoration quality is measured against the clean image with', indent=False),
        EQ('\\mathrm{MSE} = \\frac{1}{3MN}\\sum_{x,y,c} \\big[f(x,y,c) - \\hat{f}(x,y,c)\\big]^{2}', 'mse'),
        EQ('\\mathrm{PSNR} = 10\\log_{10}\\!\\left(\\frac{255^{2}}{\\mathrm{MSE}}\\right)\\;\\mathrm{dB}', 'psnr'),
        P(f'on the $256\\times256$ coin/cell phantom. Table {{tab:rest}} and Fig. {{fig:rest}} show the '
          f'results. For 10% impulse noise the $3\\times3$ median filter lowers the MSE from '
          f'{r["sp_noisy"]["mse"]:.2f} to {r["sp_median"]["mse"]:.2f}, a PSNR gain of {gain_sp:.2f} dB, and '
          f'it beats the mean filter of the same size by {med_vs_mean:.2f} dB. The mean filter spreads each '
          f'impulse over its neighbours and blurs the object boundaries. For additive Gaussian noise with '
          f'$\\sigma=20$ the ranking reverses: linear smoothing suits this noise model, and the Gaussian kernel '
          f'($\\sigma=1.2$) gives the best result, {r["gauss_gaussian"]["psnr"]:.2f} dB.'),
        TABLE('rest', 'Objective restoration quality on the $256\\times256$ coin/cell phantom',
              table_restoration),
        FIG('rest', 'restoration',
            'Restoration on the coin/cell phantom (PSNR against the ground truth): (a) ground truth, '
            '(b) 10% impulse noise, (c) mean filter, (d) median filter, (e) Gaussian noise with $\\sigma=20$, '
            '(f) Gaussian filter with $\\sigma=1.2$ applied to (e).'),
        H2('Contrast Enhancement and Segmentation'),
        P(f'Table {{tab:contrast}} reports the effect of equalization on the low-contrast ring phantom, '
          f'whose luminance occupies only [{cb["min"]}, {cb["max"]}]. Equalization stretches it across the '
          f'full [0, 255] range and raises the standard deviation from {cb["std"]:.2f} to {ca["std"]:.2f}, '
          f'an increase of {std_gain:.0f}%. The number of occupied gray levels falls slightly, from '
          f'{cb["occupiedLevels"]} to {ca["occupiedLevels"]}: the discrete CDF mapping can merge levels but '
          f'never creates new ones, so contrast comes from spacing the existing levels further apart.'),
        TABLE('contrast', 'Luminance statistics of the low-contrast phantom before and after histogram '
              'equalization', table_contrast),
        P(f'Fig. {{fig:seg}} illustrates the remaining families. Otsu\'s method selects $T^{{*}}={otsu_t}$ on '
          f'the coin/cell phantom and separates all five objects. Canny produces thin, closed contours '
          f'covering {m["segmentation"]["canny_edge_pixel_ratio"]:.2f}% of the pixels. A $5\\times5$ '
          f'opening removes the thin ring fragment left by thresholding, and $K$-means with $K=4$ reduces the '
          f'sunset scene to four colour regions.'),
        FIG('seg', 'segmentation',
            'Enhancement and segmentation computed by the engine: (a) low-contrast phantom, (b) after '
            'histogram equalization, (c) Otsu thresholding of the coin/cell phantom, (d) Canny edges, '
            '(e) $5\\times5$ morphological opening of (c), (f) $K$-means clustering ($K=4$) of the sunset '
            'scene.'),

        # ------------------------------------------------------------- VI
        H1('Discussion', 'disc'),
        P('<i>Footprint and portability.</i> Because every operator is ordinary Dart code, the same source '
          'runs on Android, iOS, desktop, and the web, and the Android release APK is 19.9 MB, most of it the '
          'Flutter runtime. No per-ABI native libraries or JNI bindings must be built, shipped, or kept in '
          'step with OS updates, and out-of-bounds access is caught by the language runtime instead of '
          'corrupting memory.', indent=False),
        P('<i>Transparency.</i> Each operator is a short function that mirrors its equation in Section '
          '{sec:math}, and the UI shows the histogram, statistics, and storage cost immediately after every '
          'step. This makes the application useful as a teaching companion: students can relate a '
          'formula, its parameters, and its visual and statistical effect directly.'),
        P('<i>Limitations.</i> The engine is single-threaded and does not use SIMD or the GPU, so it will '
          'not match optimized native libraries on large images; the median filter in particular would '
          'benefit from histogram-based or separable algorithms [7]. The quality experiments use synthetic '
          'phantoms, which give exact ground truth but are simpler than natural photographs. Timing was '
          'measured on a laptop CPU with the Dart VM, so absolute numbers on phones will differ, although '
          'the relative cost of the operator families should hold.'),

        # ------------------------------------------------------------- VII
        H1('Conclusion', 'concl'),
        P(f'We presented DIP Studio, a dependency-free engine and mobile application that implements the '
          f'classical DIP operator set on a single linear RGBA buffer. The five-stage architecture keeps '
          f'acquisition, digitization, processing, and analysis cleanly separated while allowing results to '
          f'be chained and undone. Point operations reach 280.8 MP/s, the median filter restores impulse-noise '
          f'images by {gain_sp:.2f} dB, and the full application fits in a 19.9 MB release build. Future work '
          f'includes multi-threaded and SIMD kernels, frequency-domain filtering with the 2-D FFT, wavelet '
          f'multiresolution analysis, perceptual metrics such as SSIM [15], and evaluation on natural-image '
          f'benchmarks and mobile hardware.', indent=False),
    ]


REFERENCES = [
    'R. C. Gonzalez and R. E. Woods, <i>Digital Image Processing</i>, 4th ed. New York, NY, USA: Pearson, 2018.',
    'R. Szeliski, <i>Computer Vision: Algorithms and Applications</i>, 2nd ed. Cham, Switzerland: Springer, 2022.',
    'W. K. Pratt, <i>Digital Image Processing: PIKS Scientific Inside</i>, 4th ed. Hoboken, NJ, USA: Wiley, 2007.',
    'G. Bradski and A. Kaehler, <i>Learning OpenCV: Computer Vision with the OpenCV Library</i>. Sebastopol, CA, USA: O\'Reilly Media, 2008.',
    'N. Otsu, \u201cA threshold selection method from gray-level histograms,\u201d <i>IEEE Trans. Syst., Man, Cybern.</i>, vol. SMC-9, no. 1, pp. 62\u201366, Jan. 1979.',
    'J. Serra, <i>Image Analysis and Mathematical Morphology</i>. London, U.K.: Academic Press, 1982.',
    'T. S. Huang, G. J. Yang, and G. Y. Tang, \u201cA fast two-dimensional median filtering algorithm,\u201d <i>IEEE Trans. Acoust., Speech, Signal Process.</i>, vol. ASSP-27, no. 1, pp. 13\u201318, Feb. 1979.',
    'J. Canny, \u201cA computational approach to edge detection,\u201d <i>IEEE Trans. Pattern Anal. Mach. Intell.</i>, vol. PAMI-8, no. 6, pp. 679\u2013698, Nov. 1986.',
    'J. MacQueen, \u201cSome methods for classification and analysis of multivariate observations,\u201d in <i>Proc. 5th Berkeley Symp. Math. Statist. Probab.</i>, vol. 1, 1967, pp. 281\u2013297.',
    'S. M. Pizer <i>et al.</i>, \u201cAdaptive histogram equalization and its variations,\u201d <i>Comput. Vis., Graph., Image Process.</i>, vol. 39, no. 3, pp. 355\u2013368, Sep. 1987.',
    '<i>Studio Encoding Parameters of Digital Television for Standard 4:3 and Wide-Screen 16:9 Aspect Ratios</i>, ITU-R Recommendation BT.601-7, Mar. 2011.',
    'A. K. Jain, <i>Fundamentals of Digital Image Processing</i>. Englewood Cliffs, NJ, USA: Prentice-Hall, 1989.',
    'P. Soille, <i>Morphological Image Analysis: Principles and Applications</i>, 2nd ed. Berlin, Germany: Springer, 2003.',
    'R. Adams and L. Bischof, \u201cSeeded region growing,\u201d <i>IEEE Trans. Pattern Anal. Mach. Intell.</i>, vol. 16, no. 6, pp. 641\u2013647, Jun. 1994.',
    'Z. Wang, A. C. Bovik, H. R. Sheikh, and E. P. Simoncelli, \u201cImage quality assessment: From error visibility to structural similarity,\u201d <i>IEEE Trans. Image Process.</i>, vol. 13, no. 4, pp. 600\u2013612, Apr. 2004.',
    'E. H. Land and J. J. McCann, \u201cLightness and retinex theory,\u201d <i>J. Opt. Soc. Amer.</i>, vol. 61, no. 1, pp. 1\u201311, Jan. 1971.',
    'A. Rosenfeld and J. L. Pfaltz, \u201cSequential operations in digital picture processing,\u201d <i>J. ACM</i>, vol. 13, no. 4, pp. 471\u2013494, Oct. 1966.',
    'D. Marr and E. Hildreth, \u201cTheory of edge detection,\u201d <i>Proc. Roy. Soc. London B</i>, vol. 207, no. 1167, pp. 187\u2013217, Feb. 1980.',
    'S. van der Walt <i>et al.</i>, \u201cscikit-image: Image processing in Python,\u201d <i>PeerJ</i>, vol. 2, Art. no. e453, Jun. 2014.',
    'C. A. Schneider, W. S. Rasband, and K. W. Eliceiri, \u201cNIH Image to ImageJ: 25 years of image analysis,\u201d <i>Nature Methods</i>, vol. 9, no. 7, pp. 671\u2013675, Jul. 2012.',
]
