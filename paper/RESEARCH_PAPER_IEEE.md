# DIP Studio: A Native Cross-Platform Engine for Real-Time Digital Image Processing, Mathematical Vision, and Edge Computing

**Anonymous Authors**  
*Double-Blind Review Copy — No Author Identification Included*  
*IEEE Transactions on Image Processing / IEEE Access Format*

---

### Abstract
Digital Image Processing (DIP) algorithms serve as the algorithmic backbone of modern computational vision, remote sensing, and biomedical diagnostics. However, deploying classical spatial and frequency domain image processing pipelines on mobile and edge devices has historically relied on heavyweight C++ native wrappers (e.g., OpenCV via Android NDK or iOS CocoaPods), introducing substantial binary bloat, platform-specific compilation fragmentation, and significant cold-start latency. In this paper, we present **DIP Studio**, a high-performance, native cross-platform engine and application designed for real-time digital image processing and computer vision. Implemented entirely in an ahead-of-time (AOT) compiled language without external native binaries, the engine operates directly on 32-bit linear packed ARGB/RGBA memory buffers. 

We systematically implement and analyze the canonical mathematical foundations of DIP: continuous-to-discrete spatial sampling and $k$-bit quantization ($M \times N \times k$), point transformations (logarithmic, power-law $\gamma$-correction, contrast stretching), cumulative distribution function (CDF) histogram equalization, spatial domain linear and non-linear convolution (Gaussian, Laplacian, Sobel, order-statistic median), multi-stage Canny edge localization, unsupervised $K$-Means clustering, seeded region growing, and morphological Minkowski set operations ($f \ominus B, f \oplus B$). 

Rigorous empirical benchmarking across scaled resolutions ($256 \times 256$ to $1024 \times 1024$) demonstrates exceptional performance, achieving processing throughput up to **280.83 MP/s** for point operations, **127.41 MP/s** for histogram generation, and **80.09 MP/s** for global Otsu thresholding. In objective restoration benchmarks, the median filtering engine achieves a **+17.05 dB** Peak Signal-to-Noise Ratio (PSNR) enhancement on 10% salt-and-pepper impulse degradation, outperforming linear arithmetic mean filtering by **9.64 dB** while maintaining edge boundary integrity. The entire production application compiles to a compact **19.9 MB** standalone binary with zero external native dependencies, establishing an efficient paradigm for edge vision computing and interactive pedagogical environments.

**Index Terms**—Digital Image Processing, Spatial Filtering, Histogram Equalization, Otsu's Thresholding, Canny Edge Detection, K-Means Clustering, Image Restoration, Mathematical Vision, Edge Computing, Mobile Software Engineering.

---

## I. Introduction

DIGITAL Image Processing (DIP) encompasses the algorithmic transformation, analysis, and enhancement of two-dimensional pictorial arrays discretized across space and intensity [1]. From biomedical radiography and autonomous robotics to satellite remote sensing and mobile consumer photography, DIP operations form the foundational tier upon which higher-level artificial intelligence and deep neural networks operate [2].

Despite decades of algorithmic maturation since the early foundations laid by Gonzalez, Woods, and Pratt [1], [3], the deployment of comprehensive image processing suites on edge and mobile platforms continues to encounter severe architectural trade-offs:

1. **Native Dependency Overhead**: Industry-standard computer vision libraries, predominantly written in C/C++ (such as OpenCV) [4], require complex Foreign Function Interfaces (FFI), Android Native Development Kit (NDK) toolchains, and platform-specific compilation targets (armeabi-v7a, arm64-v8a, x86_64). This introduces substantial binary overhead (frequently exceeding 60–100 MB), potential memory corruption risks at memory boundaries, and severe maintenance burdens across operating system upgrades.
2. **Loss of Determinism and Explainability**: The widespread shift toward black-box convolutional neural networks (CNNs) has frequently obscured fundamental mathematical vision concepts. In critical domains such as forensic verification, medical phantoms, and digital metrology, transparent and deterministic classical operations—such as histogram variance optimization [5], morphological set theory [6], and order-statistic noise removal [7]—remain indispensable.
3. **User Interface Latency and Visual Clutter**: Mobile image editing tools frequently struggle to balance the visualization of raw photographic pixels with high-density control panels and real-time statistical histograms, often causing severe viewport fragmentation and thermal throttling during intensive canvas rendering.

To resolve these challenges, this paper presents **DIP Studio**, a zero-native-dependency, cross-platform engine and application designed from first principles. By leveraging an Ahead-Of-Time (AOT) compiled, memory-safe language pipeline with direct linear buffer indexing, the proposed engine executes canonical spatial point operations, convolution kernels, statistical thresholding, iterative clustering, and mathematical morphology natively on CPU hardware without requiring external shared libraries.

### Key Contributions
* **Comprehensive Mathematical Pipeline**: Direct algorithmic formulation and implementation of the fundamental DIP syllabus: spatial sampling and quantization ($M \times N \times k$), power-law transformations, contrast stretching, CDF histogram equalization, spatial convolution vs. correlation, 4/8-neighbor Laplacian sharpening, Sobel gradients, Canny edge tracking, Otsu thresholding, $K$-Means vector clustering, seeded region growing, and morphological Minkowski operations.
* **Pure-Memory Direct Buffer Manipulation**: A linear 32-bit packed ARGB/RGBA memory architecture that bypasses intermediate GPU-CPU round-trips for deterministic, pixel-level manipulation with $O(MN)$ spatial complexity.
* **Empirical Benchmarks & Quality Evaluation**: Comprehensive empirical latency and throughput evaluations across multiple image resolutions ($256^2, 512^2, 1024^2$), paired with rigorous objective signal quality metrics (Mean Squared Error and Peak Signal-to-Noise Ratio) evaluating non-linear median vs. linear mean restorations under stochastic noise models.
* **Compact, Production-Grade Edge Deployment**: Compilation into a lightweight 19.9 MB standalone Android release package with a collapsible, human-factored UI drawer and interactive pixel inspector.

---

## II. Mathematical Foundations & Theoretical Framework

```
+----------------------------------------------------------------------------------------------------+
|                                    DIP STUDIO SYSTEM ARCHITECTURE                                  |
+----------------------------------------------------------------------------------------------------+
|                                                                                                    |
|   Continuous Scene f(x,y) ---> [ Sampling & Quantization ] ---> Discrete Buffer f[x,y] (M x N x k) |
|                                                                                                    |
|   +------------------------------------+------------------------------------+                      |
|   | Spatial Point & Dynamic Range      | Linear & Non-Linear Filtering      |                      |
|   |------------------------------------|------------------------------------|                      |
|   | • Grayscale (ITU-R BT.601)         | • Convolution vs Correlation (Rot) |                      |
|   | • Negative Involution              | • Box Mean & 2D Gaussian Kernel    |                      |
|   | • Logarithmic Transform            | • Order-Statistic Median Filter    |                      |
|   | • Power-Law (Gamma) Remapping      | • Laplacian (4/8-Neighbor Stencils)|                      |
|   | • Contrast Stretch & Histogram Eq  | • Sobel Orthogonal Gradients       |                      |
|   +------------------------------------+------------------------------------+                      |
|   | Advanced Segmentation & Morphology | Color, Geometry & Diagnostics      |                      |
|   |------------------------------------|------------------------------------|                      |
|   | • Otsu Between-Class Variance Opt  | • RGB <-> HSV Polar Conversion     |                      |
|   | • Multi-Stage Canny Edge Hysteresis| • 90-deg CW, Flip H, Flip V        |                      |
|   | • K-Means (K=3..6) Vector Clusters | • Euclidean, D4, D8 Metrics        |                      |
|   | • Seeded Region Growing (4/8-Conn) | • Real-Time 256-Bin Luminance Hist |                      |
|   | • Morphological Erosion & Dilation | • Dual-Pointer Coordinate Probe    |                      |
|   +------------------------------------+------------------------------------+                      |
|                                                                                                    |
|        [ Linear Packed 32-bit ARGB/RGBA Buffer ] ---> [ Clean Canvas & Drawer UI ]                 |
+----------------------------------------------------------------------------------------------------+
```

### A. Digitization: Spatial Sampling and Quantization
An analog optical scene is modeled as a continuous two-dimensional light intensity function $f(x, y)$, where $(x, y)$ denote spatial coordinates and $f$ represents radiance proportional to physical energy. Converting $f(x, y)$ into digital format requires two distinct mathematical discretization stages:
1. **Spatial Sampling**: Discretizing continuous coordinates $(x, y)$ into an $M \times N$ discrete rectilinear grid with sampling interval $\Delta x, \Delta y$.
2. **Intensity Quantization**: Discretizing continuous amplitude $f$ into $L$ discrete gray levels, where:
$$L = 2^k, \quad k \in \mathbb{Z}^+$$
where $k$ represents the bit depth per channel.

The total memory required to store an uncompressed digital image in bits is rigorously expressed by:
$$b = M \times N \times k$$
For a standard monochrome photographic frame with $M = 1024$, $N = 1024$, and $k = 8$ bits/pixel:
$$b = 1024 \times 1024 \times 8 = 8,388,608 \text{ bits} = 1,048,576 \text{ bytes} = 1.00 \text{ MB}$$

When uniform downsampling by an integer factor $S \in \{1, 2, 4, 8\}$ is applied alongside quantization bit reduction to $k' < 8$, the effective spatial coordinates and quantized intensities are derived via:
$$x' = \lfloor x / S \rfloor, \quad y' = \lfloor y / S \rfloor$$
$$f_q(x', y') = \left\lfloor \frac{f(x, y)}{256 / 2^{k'}} \right\rfloor \cdot \frac{255}{2^{k'} - 1}$$

### B. Spatial Domain Point Operations
Spatial domain point operations operate directly on individual pixel intensities independent of neighborhood context, described by the mapping:
$$s = T(r)$$
where $r$ and $s$ denote input and output pixel intensities, respectively, with $r, s \in [0, L-1]$.

#### 1) Monochrome Luminance Mapping
Conversion from polychromatic RGB space to scalar gray levels adheres to the ITU-R BT.601 standard, weighting photopic human spectral sensitivity:
$$I(x, y) = 0.299 \cdot R(x, y) + 0.587 \cdot G(x, y) + 0.114 \cdot B(x, y)$$

#### 2) Photographic Negative
The photographic negative is an involution transformation reversing dynamic contrast:
$$s = (L - 1) - r = 255 - r$$
where $T(T(r)) = 255 - (255 - r) = r$.

#### 3) Logarithmic Compression
To expand dark pixel detail while compressing high-magnitude dynamic ranges (e.g., Fourier spectrums):
$$s = c \cdot \ln(1 + r), \quad c = \frac{L - 1}{\ln(1 + r_{\max})}$$
where $r_{\max} = 255$, yielding $c \approx 45.986$ for 8-bit displays.

#### 4) Power-Law (Gamma) Transformation
Non-linear contrast adjustment is governed by:
$$s = c \cdot r^\gamma$$
where $\gamma < 1$ dynamically brightens shadow regions by expanding dark tones, and $\gamma > 1$ compresses shadows to accentuate highlight contrasts. In the DIP Studio engine, real-time power-law remapping is accelerated via an $O(1)$ pre-computed 256-element Look-Up Table (LUT):
$$\text{LUT}[r] = \text{clamp}\left(255 \cdot \left(\frac{r}{255}\right)^\gamma, 0, 255\right)$$

#### 5) Linear Contrast Stretching
When an input image exhibits a compressed dynamic range $[r_{\min}, r_{\max}] \subset [0, L-1]$, linear stretching restores full dynamic range:
$$s = \left(\frac{r - r_{\min}}{r_{\max} - r_{\min}}\right) \cdot (L - 1)$$

### C. Dynamic Range Expansion & CDF Histogram Equalization
The intensity histogram of a digital image with gray levels in the range $[0, L-1]$ is a discrete function:
$$h(r_k) = n_k$$
where $r_k$ is the $k$-th intensity value and $n_k$ is the number of pixels with intensity $r_k$. The normalized probability density function (PDF) is given by:
$$p_r(r_k) = \frac{n_k}{M \cdot N}, \quad k = 0, 1, 2, \dots, L-1$$

Histogram equalization derives a monotonic transformation $s = T(r)$ such that the output probability distribution $p_s(s)$ approximates a uniform distribution. The discrete cumulative distribution function (CDF) mapping is formulated as:
$$s_k = T(r_k) = (L - 1) \sum_{j=0}^k p_r(r_j) = \frac{L - 1}{M \cdot N} \sum_{j=0}^k n_j$$

For full-color RGB images, directly equalizing $R, G, B$ channels independently causes severe chromatic aberration and hue shifts. DIP Studio implements two distinct equalization paradigms:
1. **Luminance-Preserving RGB Equalization**: Calculates the global scalar CDF from luminance $I$, remapping color channels proportionally:
$$R'(x, y) = \text{clamp}\left(R(x, y) \cdot \frac{T(I(x, y))}{I(x, y) + \epsilon}, 0, 255\right)$$
2. **HSV Chromaticity Preservation**: Converts RGB into polar Hue-Saturation-Value (HSV) space, applies cumulative equalization exclusively to the Value ($V$) channel, and converts back to RGB:
$$V' = T(V), \quad H' = H, \quad S' = S$$

### D. Spatial Filtering: Convolution versus Correlation
Spatial filtering computes output pixels as a linear combination of neighborhood intensities weighted by a spatial kernel $w$ of size $m \times n$ (with odd dimensions $m = 2a + 1$, $n = 2b + 1$).

#### 1) Convolution vs. Correlation
Mathematically, spatial correlation shifts the kernel across the image:
$$g(x, y) = w(x, y) \otimes f(x, y) = \sum_{s=-a}^a \sum_{t=-b}^b w(s, t) \cdot f(x + s, y + t)$$
In contrast, **true mathematical convolution** rotates the filter kernel by $180^\circ$ (flipping both horizontally and vertically) prior to spatial accumulation:
$$g(x, y) = w(x, y) \star f(x, y) = \sum_{s=-a}^a \sum_{t=-b}^b w(s, t) \cdot f(x - s, y - t)$$
For symmetric kernels (e.g., Gaussian, Box Mean), correlation and convolution yield identical results. For asymmetric derivative kernels, kernel flipping ensures associative and commutative properties.

#### 2) Smoothing Kernels
* **Arithmetic Box Mean**:
$$w_{\text{mean}} = \frac{1}{m \cdot n} \begin{bmatrix} 1 & \dots & 1 \\ \vdots & \ddots & \vdots \\ 1 & \dots & 1 \end{bmatrix}$$
* **Isotropic Gaussian Filter**:
$$G(x, y) = \frac{1}{2\pi\sigma^2} \exp\left(-\frac{x^2 + y^2}{2\sigma^2}\right)$$
The discrete $3 \times 3$ Gaussian kernel with $\sigma = 1.0$ is normalized as:
$$w_{\text{gauss}} = \frac{1}{16} \begin{bmatrix} 1 & 2 & 1 \\ 2 & 4 & 2 \\ 1 & 2 & 1 \end{bmatrix}$$

### E. Non-Linear Order-Statistic Filtering: Median Filter
Linear smoothing filters attenuate high-frequency noise at the cost of blurring sharp structural edges. The non-linear **Median Filter** replaces each pixel intensity with the median of the sorted intensity values within its $(2k+1) \times (2k+1)$ neighborhood:
$$g(x, y) = \text{median}\left\{ f(x + s, y + t) \mid (s, t) \in W \right\}$$
The median filter provides superior performance against impulse noise (salt-and-pepper), which manifests as extreme outlier values ($0$ or $255$). Because the median is insensitive to unipolar outliers, isolated impulse spikes are eliminated without altering adjacent homogeneous edge boundaries.

### F. Sharpening & High-Pass Spatial Differentiation
Spatial sharpening accentuates intensity discontinuities (edges, lines) by utilizing numerical finite differences.

#### 1) Laplacian 2nd-Order Isotropic Operator
The continuous Laplacian $\nabla^2 f$ is invariant to rotation:
$$\nabla^2 f = \frac{\partial^2 f}{\partial x^2} + \frac{\partial^2 f}{\partial y^2}$$
Discretized on a digital grid using central second differences:
$$\frac{\partial^2 f}{\partial x^2} \approx f(x+1, y) + f(x-1, y) - 2f(x, y)$$
$$\frac{\partial^2 f}{\partial y^2} \approx f(x, y+1) + f(x, y-1) - 2f(x, y)$$
Yielding the standard 4-neighbor and 8-neighbor discrete convolution stencils:
$$w_{\nabla^2, 4} = \begin{bmatrix} 0 & 1 & 0 \\ 1 & -4 & 1 \\ 0 & 1 & 0 \end{bmatrix}, \quad w_{\nabla^2, 8} = \begin{bmatrix} 1 & 1 & 1 \\ 1 & -8 & 1 \\ 1 & 1 & 1 \end{bmatrix}$$
Image sharpening restores high frequencies by subtracting the discrete Laplacian:
$$g(x, y) = f(x, y) - c \cdot \nabla^2 f(x, y)$$
where $c = 1$ when the kernel center is negative.

#### 2) Sobel 1st-Order Gradient Operators
The spatial gradient vector $\nabla f = [G_x, G_y]^T$ measures magnitude and direction:
$$G_x = \begin{bmatrix} -1 & 0 & 1 \\ -2 & 0 & 2 \\ -1 & 0 & 1 \end{bmatrix} \star f, \quad G_y = \begin{bmatrix} -1 & -2 & -1 \\ 0 & 0 & 0 \\ 1 & 2 & 1 \end{bmatrix} \star f$$
$$M(x, y) = \sqrt{G_x^2 + G_y^2} \approx |G_x| + |G_y|, \quad \theta(x, y) = \arctan\left(\frac{G_y}{G_x}\right)$$

#### 3) Canny Edge Detection Pipeline
DIP Studio implements the complete 5-stage optimal Canny edge detection pipeline:
1. **Gaussian Smoothing**: Convolving with $G(x, y, \sigma)$ to eliminate noise.
2. **Gradient Computation**: Deriving $M(x, y)$ and continuous orientation $\theta(x, y)$ via Sobel operators.
3. **Non-Maximum Suppression (NMS)**: Quantizing $\theta(x, y)$ into four sectors ($0^\circ, 45^\circ, 90^\circ, 135^\circ$) and suppressing non-ridge pixels:
$$M_N(x, y) = \begin{cases} M(x, y), & \text{if } M(x, y) \ge \max(M(p), M(q)) \\ 0, & \text{otherwise} \end{cases}$$
where $p, q$ are neighbor pixels along gradient normal direction $\theta$.
4. **Double Thresholding**: Partitioning edge pixels into strong, weak, and non-edges using dual thresholds $T_{\text{high}}$ and $T_{\text{low}}$:
$$E(x, y) = \begin{cases} \text{Strong}, & M_N(x, y) \ge T_{\text{high}} \\ \text{Weak}, & T_{\text{low}} \le M_N(x, y) < T_{\text{high}} \\ 0, & M_N(x, y) < T_{\text{low}} \end{cases}$$
5. **Hysteresis Edge Tracking**: Iteratively retaining weak edge pixels if and only if they are 8-connected to at least one strong edge pixel.

### G. Image Segmentation & Morphological Set Theory

#### 1) Otsu's Optimal Between-Class Variance Thresholding
Otsu's criterion calculates an optimal global threshold $T^*$ that maximizes the separability of foreground and background pixel classes without requiring empirical tuning. Given normalized histogram probabilities $p_i$, the cumulative zeroth and first-order moments for background class $C_0 = [0, T]$ and foreground class $C_1 = [T+1, L-1]$ are:
$$\omega_0(T) = \sum_{i=0}^T p_i, \quad \omega_1(T) = 1 - \omega_0(T)$$
$$\mu_0(T) = \sum_{i=0}^T \frac{i \cdot p_i}{\omega_0(T)}, \quad \mu_1(T) = \sum_{i=T+1}^{L-1} \frac{i \cdot p_i}{\omega_1(T)}, \quad \mu_T = \sum_{i=0}^{L-1} i \cdot p_i$$
The between-class variance $\sigma_B^2(T)$ is defined as:
$$\sigma_B^2(T) = \omega_0(T) \cdot (\mu_0 - \mu_T)^2 + \omega_1(T) \cdot (\mu_1 - \mu_T)^2 = \omega_0(T)\omega_1(T) \cdot [\mu_0(T) - \mu_1(T)]^2$$
The optimal threshold maximizes this variance:
$$T^* = \arg\max_{0 \le T < L-1} \sigma_B^2(T)$$

#### 2) $K$-Means Color Vector Clustering
$K$-Means partitions $N_p = M \times N$ pixel color vectors $\mathbf{x}_i = [R_i, G_i, B_i]^T \in \mathbb{R}^3$ into $K$ disjoint clusters $S = \{S_1, S_2, \dots, S_K\}$ to minimize total intra-cluster sum-of-squares (WCSS):
$$J = \sum_{j=1}^K \sum_{\mathbf{x}_i \in S_j} \|\mathbf{x}_i - \mathbf{m}_j\|^2$$
Centroid updates iterate until convergence:
$$\mathbf{m}_j^{(t+1)} = \frac{1}{|S_j^{(t)}|} \sum_{\mathbf{x}_i \in S_j^{(t)}} \mathbf{x}_i$$

#### 3) Seeded Region Growing
Starting from a designated seed pixel $(x_0, y_0)$ with intensity $f(x_0, y_0)$, neighboring pixels $(x, y)$ connected under adjacency set $\mathcal{N} \in \{N_4, N_8\}$ are iteratively absorbed into region $\mathcal{R}$ if they satisfy the distance threshold:
$$|f(x, y) - \mu_{\mathcal{R}}| \le \delta$$
where $\mu_{\mathcal{R}}$ is the dynamic mean of the segmented region.

#### 4) Morphological Minkowski Operations
Morphological processing analyzes binary or grayscale geometries via a structuring element $B$.
* **Erosion ($f \ominus B$)**: Computes the localized spatial infimum (shrinking foregrounds and eliminating narrow bridges):
$$(f \ominus B)(x, y) = \min_{(s, t) \in B} \{ f(x + s, y + t) \}$$
* **Dilation ($f \oplus B$)**: Computes the localized spatial supremum (expanding boundaries and filling small holes):
$$(f \oplus B)(x, y) = \max_{(s, t) \in B} \{ f(x - s, y - t) \}$$

### H. Distance Metrics and Spatial Neighborhood Relations
For two pixels $p = (x, y)$ and $q = (s, t)$, DIP Studio provides real-time geodesic and metric distance computations:
1. **Euclidean Distance ($D_e$)**:
$$D_e(p, q) = \sqrt{(x - s)^2 + (y - t)^2}$$
2. **City-Block / Manhattan Distance ($D_4$)**:
$$D_4(p, q) = |x - s| + |y - t|$$
3. **Chessboard Distance ($D_8$)**:
$$D_8(p, q) = \max(|x - s|, |y - t|)$$
4. **Mixed Adjacency ($m$-adjacency)**: Resolves path ambiguities present in 8-connectivity to guarantee simple topological closed contours without boundary anomalies.

---

## III. System Architecture & Native Implementation

### A. Linear 32-bit Packed ARGB Memory Model
Unlike conventional image frameworks that instantiate boxed objects per pixel or rely on deep multidimensional arrays, DIP Studio structures images using a contiguous, flat `Uint8List` byte buffer:
$$\text{Buffer Size} = \text{Width} \times \text{Height} \times 4 \text{ bytes}$$
Every pixel coordinate $(x, y)$ maps to a 4-byte segment indexed by:
$$\text{Offset}(x, y) = (y \cdot \text{Width} + x) \ll 2$$
$$R = \text{Buffer}[\text{Offset}], \quad G = \text{Buffer}[\text{Offset} + 1], \quad B = \text{Buffer}[\text{Offset} + 2], \quad A = \text{Buffer}[\text{Offset} + 3]$$

This flat memory layout delivers three major computational advantages:
1. **Maximized Cache Locality**: Sequential horizontal scans trigger CPU hardware prefetchers, avoiding memory cache misses.
2. **Zero Pointer Indirection**: Accessing color channels requires only bitwise shift and direct byte index operations without reference dereferencing.
3. **Deterministic Memory Footprint**: Allocations occur in a single contiguous block, eliminating heap fragmentation and garbage collection pauses.

### B. Pure Cross-Platform Zero-Native Architecture
To eliminate Android NDK and iOS CocoaPod compilation friction, the entire `DipEngine` is written in standard, platform-agnostic code. When targeting physical hardware (ARM64, x86_64), the codebase is compiled ahead-of-time (AOT) directly to machine instructions. File input/output is implemented using native standard streams writing directly to platform download and media directories (`/storage/emulated/0/Download` and user desktop download paths), eliminating third-party native plugin crashes during OS updates.

### C. Collapsible Drawer UI & Viewport Optimization
Mobile viewports present constrained screen dimensions. The UI architecture incorporates:
* **Default-Hidden Collapsible Drawer**: The tool workbench initializes in a folded state, maximizing visible photo canvas area to **85%+ of the screen**.
* **One-Tap Category Expanding**: Tapping any tool tab (`Enhance`, `Filters & Noise`, `Segment`, `Digitize`, `Inspect`) or the grab handle expands the controls, automatically refolding upon user request.
* **Reactive 256-Bin Histogram Overlay**: Dynamic multi-channel plotting (RGB + Luminance) with an independent collapse chevron that condenses into a 36 px statistics badge bar (`Mean μ`, `Std σ`, `Range`, `Otsu T*`).

---

## IV. Experimental Evaluation & Empirical Results

### A. Experimental Setup & Hardware Configuration
All benchmarks were executed on an AMD Ryzen-class workstation (x86_64, 3.20 GHz, Windows 11 host) paired with ARM64 Android mobile hardware emulation. Algorithmic executions were timed using monotonic microsecond stopwatches over 5 consecutive iterations per operation across three standardized test resolutions:
1. **$256 \times 256$** (0.07 Megapixels, 65,536 pixels)
2. **$512 \times 512$** (0.26 Megapixels, 262,144 pixels)
3. **$1024 \times 1024$** (1.05 Megapixels, 1,048,576 pixels)

### B. Computational Throughput and Execution Latency
Table I summarizes the empirical latency (in milliseconds) and processing throughput (in Megapixels per second, MP/s) across core DIP algorithms.

#### TABLE I: Execution Latency (ms) and Throughput (MP/s) Across Image Resolutions
| Algorithm Category | Operation Name | $256 \times 256$ Latency (ms) | $256^2$ Throughput (MP/s) | $512 \times 512$ Latency (ms) | $512^2$ Throughput (MP/s) | $1024 \times 1024$ Latency (ms) | $1024^2$ Throughput (MP/s) |
|---|---|---|---|---|---|---|---|
| **Point Transformations** | Grayscale (BT.601) | 0.68 | 96.07 | 2.08 | 125.81 | 7.56 | 138.69 |
| | Negative Involution | 0.77 | 85.13 | 1.51 | 173.63 | 4.84 | 216.73 |
| | Log Transform ($c=1.0$) | 0.93 | 70.77 | 1.80 | 145.91 | 3.73 | 280.83 |
| | Power-Law Gamma ($\gamma=0.65$) | 0.28 | 236.42 | 1.04 | 251.43 | 4.50 | 232.80 |
| | Contrast Stretch | 2.12 | 30.97 | 4.37 | 59.94 | 12.75 | 82.21 |
| **Statistical Analysis** | 256-Bin Histogram Gen. | 0.34 | 192.08 | 2.10 | 124.75 | 8.23 | 127.41 |
| | Histogram Equalize (RGB) | 5.47 | 11.98 | 18.63 | 14.07 | 70.82 | 14.81 |
| | Otsu Thresholding (Auto) | 1.25 | 52.50 | 4.15 | 63.12 | 13.09 | 80.09 |
| **Spatial Filtering** | Box Mean ($3 \times 3$) | 6.35 | 10.32 | 20.32 | 12.90 | 86.48 | 12.12 |
| | Gaussian Blur ($3 \times 3, \sigma=1.2$) | 11.26 | 5.82 | 39.79 | 6.59 | 151.72 | 6.91 |
| | Median Filter ($3 \times 3$) | 47.82 | 1.37 | 153.10 | 1.71 | 588.55 | 1.78 |
| | Laplacian Sharpen ($3 \times 3, 8$-N) | 14.00 | 4.68 | 39.47 | 6.64 | 154.92 | 6.77 |
| | Sobel Gradient Operator | 11.35 | 5.77 | 34.09 | 7.69 | 108.10 | 9.70 |
| **Advanced Segmentation** | Canny 5-Stage Edge Pipeline | 19.99 | 3.28 | 64.14 | 4.09 | — | — |
| | $K$-Means Clustering ($K=4$) | 14.23 | 4.61 | 49.23 | 5.32 | — | — |
| | Morphological Erosion ($3 \times 3$) | 7.15 | 9.17 | 26.29 | 9.97 | — | — |
| | Morphological Dilation ($3 \times 3$) | 6.23 | 10.52 | 24.88 | 10.54 | — | — |
| **Geometry & Alignment** | Rotate $90^\circ$ Clockwise | 1.24 | 52.67 | 2.20 | 118.97 | 12.10 | 86.63 |
| | Horizontal Reflection | 1.00 | 65.24 | 2.18 | 120.48 | 5.29 | 198.13 |

As evidenced by Table I, LUT-accelerated point operations scale linearly with total pixel count, exceeding **280 MP/s** throughput. Full-frame 1024×1024 grayscale conversion completes in **7.56 ms**, and Otsu automatic thresholding executes in **13.09 ms**, operating well within 60 FPS real-time interactive thresholds.

### C. Objective Noise Restoration Performance (MSE & PSNR)
To quantitatively evaluate restoration performance, the standard phantom image ($256 \times 256$) was corrupted by two stochastic noise processes:
1. **Additive Salt-and-Pepper Impulse Noise** ($d = 0.10$, 10% pixel corruption).
2. **Zero-Mean Additive Gaussian Noise** ($\sigma = 20.0$).

Restoration quality was quantified using Mean Squared Error (MSE) and Peak Signal-to-Noise Ratio (PSNR):
$$\text{MSE} = \frac{1}{3MN} \sum_{x=0}^{M-1} \sum_{y=0}^{N-1} \sum_{c \in \{R,G,B\}} \left[ f(x, y, c) - \hat{f}(x, y, c) \right]^2$$
$$\text{PSNR} = 10 \cdot \log_{10}\left( \frac{255^2}{\text{MSE}} \right) \text{ dB}$$

#### TABLE II: Objective Restoration Quality Metrics on Noisy Phantoms
| Degradation Process | Restoration Operator | Measured MSE | Measured PSNR (dB) | Improvement $\Delta$PSNR (dB) |
|---|---|---|---|---|
| **Salt & Pepper ($d=0.10$)** | Unprocessed Corrupted Image | 2363.62 | 14.40 dB | Baseline |
| | Arithmetic Mean ($3 \times 3$) | 429.00 | 21.81 dB | +7.41 dB |
| | **Order-Statistic Median ($3 \times 3$)** | **46.57** | **31.45 dB** | **+17.05 dB** |
| **Gaussian Noise ($\sigma=20.0$)** | Unprocessed Corrupted Image | 361.64 | 22.55 dB | Baseline |
| | Arithmetic Mean ($3 \times 3$) | 134.55 | 26.84 dB | +4.29 dB |
| | **Gaussian Blur ($3 \times 3, \sigma=1.2$)** | **122.85** | **27.24 dB** | **+4.69 dB** |

Table II confirms the mathematical superiority of non-linear order statistics over linear spatial smoothing for impulse noise. While the $3 \times 3$ mean filter smears the impulse spikes across the neighborhood (yielding an MSE of 429.00), the **median filter reduces MSE to 46.57**, achieving an exceptional **+17.05 dB PSNR improvement** (+9.64 dB higher than arithmetic mean). Conversely, for Gaussian noise, Gaussian weighted spatial filtering achieves the lowest reconstruction error (MSE 122.85, PSNR 27.24 dB).

### D. Dynamic Range and Contrast Expansion Evaluation
Table III evaluates histogram equalization on a deliberately degraded, low-contrast photographic phantom.

#### TABLE III: Dynamic Range Expansion and Intensity Dispersion
| Image State | Intensity Range $[r_{\min}, r_{\max}]$ | Total Dynamic Range (Levels) | Mean Intensity $\mu$ | Standard Deviation $\sigma$ |
|---|---|---|---|---|
| **Original Low-Contrast Phantom** | $[96, 148]$ | 52 levels | 120.45 | 16.82 |
| **CDF Histogram Equalized** | $[0, 255]$ | **255 levels** | 127.80 | **88.67** |

Equalization successfully spreads the narrow 52-level distribution across the complete $[0, 255]$ spectrum, increasing intensity standard deviation $\sigma$ from **16.82 to 88.67** (a 427% increase in global image contrast).

---

## V. Discussion & Comparative Analysis

### A. Architectural Comparison with Native C++ Wrappers
Compared with conventional OpenCV Android NDK configurations, DIP Studio provides marked operational advantages:
1. **Binary Size Reduction**: The final production release APK measures **19.9 MB**, representing a 65–80% reduction compared to standard OpenCV mobile distributions incorporating multi-architecture `.so` native libraries.
2. **Portability and Maintenance**: By executing entirely within a memory-safe execution sandbox, the engine compiles identically across Android, iOS, Windows, macOS, Linux, and Web targets without requiring platform-specific C++ toolchains.
3. **Deterministic Memory Safety**: Eliminates JNI/FFI pointer marshalling overhead and boundary memory leaks, ensuring zero crashes across varied mobile OEM Android builds.

### B. Educational and Research Utility
In academic computer vision instruction, students frequently treat high-level functions as opaque black boxes. DIP Studio exposes real-time mathematical feedback:
* Dynamic display of operational durations ($t$ in ms) per execution step.
* Dual-coordinate interactive probing displaying exact Euclidean, City-Block ($D_4$), and Chessboard ($D_8$) metrics.
* Visual verification of the mathematical divergence between correlation and convolution.

---

## VI. Conclusion & Future Work

In this paper, we presented **DIP Studio**, a native cross-platform engine and application for real-time digital image processing and mathematical vision. Operating on linear 32-bit packed memory buffers without third-party C++ native libraries, the engine delivers high throughput across the foundational DIP curriculum: point remappings, CDF equalization, spatial convolution, order-statistic median restoration, Canny edge detection, Otsu variance optimization, and mathematical morphology. 

Empirical benchmarks demonstrate point processing speeds exceeding 280 MP/s and a +17.05 dB PSNR restoration gain on impulse noise, packaged within a compact 19.9 MB application binary.

### Future Work
Future extensions include:
1. **2D Frequency Domain Processing**: Implementing Fast Fourier Transforms (FFT) for Butterworth, Gaussian, and ideal 2D high-pass and low-pass frequency filtering.
2. **GPU Compute Shader Acceleration**: Leveraging Vulkan and Metal compute pipelines for real-time 4K video-rate spatial convolution.
3. **Wavelet Multiresolution Decomposition**: Incorporating Haar and Daubechies discrete wavelet transforms for progressive image compression.

---

## References

[1] R. C. Gonzalez and R. E. Woods, *Digital Image Processing*, 4th ed. New York, NY, USA: Pearson, 2018.  
[2] R. Szeliski, *Computer Vision: Algorithms and Applications*, 2nd ed. Cham, Switzerland: Springer, 2022.  
[3] W. K. Pratt, *Digital Image Processing: PIKS Scientific Inside*, 4th ed. Hoboken, NJ, USA: John Wiley & Sons, 2007.  
[4] G. Bradski and A. Kaehler, *Learning OpenCV: Computer Vision with the OpenCV Library*. Sebastopol, CA, USA: O'Reilly Media, 2008.  
[5] N. Otsu, "A threshold selection method from gray-level histograms," *IEEE Transactions on Systems, Man, and Cybernetics*, vol. 9, no. 1, pp. 62–66, Jan. 1979, doi: 10.1109/TSMC.1979.4310076.  
[6] J. Serra, *Image Analysis and Mathematical Morphology*. London, UK: Academic Press, 1982.  
[7] T. S. Huang, G. J. Yang, and G. Y. Tang, "A fast two-dimensional median filtering algorithm," *IEEE Transactions on Acoustics, Speech, and Signal Processing*, vol. 27, no. 1, pp. 13–18, Feb. 1979.  
[8] J. Canny, "A modern approach to edge detection," *IEEE Transactions on Pattern Analysis and Machine Intelligence*, vol. PAMI-8, no. 6, pp. 679–698, Nov. 1986, doi: 10.1109/TPAMI.1986.4767851.  
[9] J. MacQueen, "Some methods for classification and analysis of multivariate observations," in *Proc. 5th Berkeley Symp. Math. Statist. Prob.*, vol. 1, 1967, pp. 281–297.  
[10] S. M. Pizer et al., "Adaptive histogram equalization and its variations," *Computer Vision, Graphics, and Image Processing*, vol. 39, no. 3, pp. 355–368, Sep. 1987.  
[11] ITU-R Recommendation BT.601-7, "Studio encoding parameters of digital television for standard 4:3 and wide-screen 16:9 aspect ratios," International Telecommunication Union, Geneva, Switzerland, 2011.  
[12] A. K. Jain, *Fundamentals of Digital Image Processing*. Englewood Cliffs, NJ, USA: Prentice-Hall, 1989.  
[13] P. Soille, *Morphological Image Analysis: Principles and Applications*, 2nd ed. Berlin, Germany: Springer, 2004.  
[14] R. Adams and L. Bischof, "Seeded region growing," *IEEE Transactions on Pattern Analysis and Machine Intelligence*, vol. 16, no. 6, pp. 641–647, Jun. 1994, doi: 10.1109/34.295913.  
[15] Z. Wang, A. C. Bovik, H. R. Sheikh, and E. P. Simoncelli, "Image quality assessment: From error visibility to structural similarity," *IEEE Transactions on Image Processing*, vol. 13, no. 4, pp. 600–612, Apr. 2004.  
[16] E. H. Land and J. J. McCann, "Lightness and retinex theory," *Journal of the Optical Society of America*, vol. 61, no. 1, pp. 1–11, Jan. 1971.  
[17] A. Rosenfeld and J. L. Pfaltz, "Sequential operations in digital picture processing," *Journal of the ACM*, vol. 13, no. 4, pp. 471–494, Oct. 1966.  
[18] D. Marr and E. Hildreth, "Theory of edge detection," *Proceedings of the Royal Society of London. Series B. Biological Sciences*, vol. 207, no. 1167, pp. 187–217, Feb. 1980.
