# DIP Studio — Digital Image Processing & Photo Editor

[![Flutter](https://img.shields.io/badge/Flutter-3.29.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.7.0-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SQA Tests](https://img.shields.io/badge/SQA%20Tests-29%2F29%20Passed-success)](test/sqa_verification_test.dart)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)](#installation--running)

**DIP Studio** is an interactive, full-featured **Digital Image Processing (DIP) Lab and Photo Editor** built with Flutter. It implements fundamental DIP textbook algorithms and mathematical principles from the ground up in pure Dart, operating directly on 2D pixel buffers ($M \times N \times 4$ RGBA).

Whether exploring image sampling, intensity quantization, spatial filtering, non-linear noise restoration, or image segmentation, DIP Studio bridges academic image processing theory with a tactile, user-friendly mobile photo editing workbench.

---

## Table of Contents

- [Core Principles & Theory Implemented](#core-principles--theory-implemented)
  - [1. Fundamental Steps in DIP](#1-fundamental-steps-in-dip)
  - [2. Digitization: Sampling, Quantization & Bit-Size](#2-digitization-sampling-quantization--bit-size)
  - [3. Spatial Domain Point Operations & Enhancement](#3-spatial-domain-point-operations--enhancement)
  - [4. Noise Models & Spatial Filtering](#4-noise-models--spatial-filtering)
  - [5. Segmentation Approaches & Morphology](#5-segmentation-approaches--morphology)
  - [6. Distance Measures & Neighborhood Metrics](#6-distance-measures--neighborhood-metrics)
- [Application Features](#application-features)
- [Project Architecture](#project-architecture)
- [Software Quality Assurance (SQA)](#software-quality-assurance-sqa)
- [Installation & Running](#installation--running)
- [Building the Release APK](#building-the-release-apk)
- [Author & License](#author--license)

---

## Core Principles & Theory Implemented

### 1. Fundamental Steps in DIP

| Step | Function | Real-World Analogy | DIP Studio Implementation |
|---|---|---|---|
| **Image Acquisition** | Capture & digitize image signals | Taking the photo | Camera, Gallery, and 4 procedural test phantoms |
| **Preprocessing / Enhancement** | Contrast adjustment, noise removal | Cleaning a dirty window | Point ops, Histogram Equalization, Mean/Gaussian |
| **Image Restoration** | Reversing degradation & noise | Repairing an old photo | Order-statistic **Median filter** for impulse noise |
| **Color Processing** | Working across color spaces | Choosing a lens filter | RGB $\leftrightarrow$ HSV color adjustment ($H, S, V$) |
| **Wavelets / Multiresolution** | Multi-scale frequency analysis | Zooming in and out | Multi-level spatial downsampling grid |
| **Compression** | Minimizing storage requirements | Zipping a file | Real-time $M \times N \times k$ bit-size calculator & savings % |
| **Morphological Processing** | Shape-based geometry operations | Shrinking / growing shapes | Square structuring element **Erosion** & **Dilation** |
| **Segmentation** | Partitioning image into regions | Slicing a cake | **Otsu's Thresholding**, **Canny Edges**, **K-Means**, **Region Growing** |
| **Representation & Description** | Boundary & regional descriptors | Describing each slice | Edge contour maps, cluster centroids, grown region masks |
| **Object Recognition** | Labeling isolated structures | Naming each slice | Quantitative pixel statistics & component counts |

---

### 2. Digitization: Sampling, Quantization & Bit-Size

A continuous optical image $f(x, y)$ is converted to digital form through:
- **Sampling:** Discretizing continuous spatial coordinates $(x, y)$, defining spatial resolution ($M \times N$).
- **Quantization:** Discretizing continuous intensity values into $L = 2^k$ gray levels ($k$ bits/pixel).

$$\text{Image Size in Bits} = M \times N \times k$$

> **Worked Example:** A $1024 \times 1024$ grayscale image at $k = 8$ bits/pixel:
> $$b = 1024 \times 1024 \times 8 = 8{,}388{,}608 \text{ bits} = 1{,}048{,}576 \text{ Bytes} = \mathbf{1.00 \text{ MB}}$$

DIP Studio includes an interactive **Digitization Simulator** allowing users to dynamically adjust:
- Spatial downsampling factor ($s \in \{1, 2, 4, 8, 16\}$).
- Quantization bit depth ($k \in [1..8]$ bits, $L = 2^k \in [2..256]$ levels), with live file size savings calculation.

---

### 3. Spatial Domain Point Operations & Enhancement

Operations applied directly on individual pixels $s = T(r)$:

- **Grayscale Conversion (ITU-R BT.601 Luminance):**
  $$I(x, y) = 0.299R + 0.587G + 0.114B$$
- **Image Negative:**
  $$s = (L - 1) - r = 255 - r$$
- **Logarithmic Transformation (Expands Dark Intensities):**
  $$s = c \cdot \ln(1 + r), \quad c = \frac{255}{\ln(256)}$$
- **Power-Law (Gamma $\gamma$) Transformation:**
  $$s = c \cdot r^\gamma \quad (\gamma < 1 \implies \text{brightens midtones}, \quad \gamma > 1 \implies \text{darkens midtones})$$
- **Linear Contrast Stretching:**
  $$s = \frac{r - r_{\min}}{r_{\max} - r_{\min}} \times 255$$
- **Histogram Equalization (Normalized CDF Mapping):**
  $$s_k = \text{round}\left( \frac{\text{cdf}(k) - \text{cdf}_{\min}}{M \cdot N - \text{cdf}_{\min}} \times (L - 1) \right)$$
- **HSV Color Transformation:** Full $\Delta \text{Hue}$ ($[-180^\circ..+180^\circ]$) rotation, Saturation scaling, and Value adjustment.

---

### 4. Noise Models & Spatial Filtering

DIP Studio simulates and restores fundamental degradation models:

- **Impulse Noise (Salt & Pepper):** Randomly injects $0$ (pepper) and $255$ (salt) at density $p$.
- **Gaussian Noise:** Zero-mean normal distribution $g(x, y) = f(x, y) + \mathcal{N}(0, \sigma^2)$ using the Box-Muller transform.
- **Speckle Noise:** Multiplicative noise $g(x,y) = f(x,y) \cdot (1 + n)$.

#### Filters & Restoration:
- **Median Filter ($3 \times 3$ and $5 \times 5$):**
  $$g(x, y) = \text{median}\{ f(s, t) \mid (s, t) \in S_{xy} \}$$
  *Proved via SQA to restore impulse noise with far lower Mean Absolute Error than linear filters.*
- **Mean (Box) Filter ($3 \times 3$ and $5 \times 5$):**
  $$g(x, y) = \frac{1}{K^2} \sum_{(s, t) \in S_{xy}} f(s, t)$$
- **Gaussian Blur:** Continuous $2\text{D}$ kernel $G(x, y) = \frac{1}{2\pi\sigma^2} e^{-\frac{x^2+y^2}{2\sigma^2}}$.
- **Laplacian 2nd-Order Derivative (Sharpening & Edges):**
  $$\nabla^2 f = \frac{\partial^2 f}{\partial x^2} + \frac{\partial^2 f}{\partial y^2}, \quad g(x, y) = f(x, y) - c \nabla^2 f(x, y)$$
  *Supports both 4-neighbor and 8-neighbor kernels, and edge-only mode $|\nabla^2 f|$.*
- **Sobel 1st-Order Gradient Operator:**
  $$G_x = \begin{bmatrix} -1 & 0 & 1 \\ -2 & 0 & 2 \\ -1 & 0 & 1 \end{bmatrix} * f, \quad G_y = \begin{bmatrix} -1 & -2 & -1 \\ 0 & 0 & 0 \\ 1 & 2 & 1 \end{bmatrix} * f, \quad |\nabla f| = \sqrt{G_x^2 + G_y^2}$$
- **Convolution vs. Correlation Demonstrator:**
  $$(f * w)(x, y) = \sum_{s} \sum_{t} f(x - s, y - t) w(s, t) \quad \text{vs.} \quad (f \star w)(x, y) = \sum_{s} \sum_{t} f(x + s, y + t) w(s, t)$$
  *Convolution strictly rotates (flips) the kernel $180^\circ$ prior to sliding.*

---

### 5. Segmentation Approaches & Morphology

- **Otsu’s Global Optimal Thresholding:** Automatically finds threshold $T^*$ that maximizes between-class variance:
  $$\sigma_B^2(T) = \omega_0(T) \omega_1(T) \big[ \mu_0(T) - \mu_1(T) \big]^2$$
- **Canny Edge Detection Pipeline:**
  1. Gaussian smoothing
  2. Sobel gradient magnitude & angle quantization ($0^\circ, 45^\circ, 90^\circ, 135^\circ$)
  3. Non-Maximum Suppression (NMS) along gradient directions
  4. Dual thresholding ($T_{\text{low}}, T_{\text{high}}$) and edge hysteresis
- **K-Means Color Clustering:** Partitions image pixels into $K \in \{2, 3, 4, 6\}$ optimal color centroids using iterative Euclidean distance minimization:
  $$\arg\min_S \sum_{i=1}^K \sum_{p \in S_i} \| p - \mu_i \|^2$$
- **Seed-Based Region Growing:** Interactive segmentation — tap any pixel on the photo canvas to grow connected homogeneous regions based on intensity similarity threshold:
  $$\{ (x, y) \mid |I(x, y) - I(\text{seed})| \le \text{tolerance} \}$$
  *Supports both 4-connectivity and 8-connectivity.*
- **Morphological Operations:**
  - **Erosion ($f \ominus B$):** Local minimum filter over structuring element $B$ (shrinks bright features).
  - **Dilation ($f \oplus B$):** Local maximum filter over structuring element $B$ (expands bright features).

---

### 6. Distance Measures & Neighborhood Metrics

Tap any two pixels ($P_1, P_2$) on the interactive canvas to inspect:
- **Euclidean Distance ($D_e$):**
  $$D_e(P_1, P_2) = \sqrt{(x_1 - x_2)^2 + (y_1 - y_2)^2}$$
- **City-Block / Manhattan Distance ($D_4$):**
  $$D_4(P_1, P_2) = |x_1 - x_2| + |y_1 - y_2|$$
- **Chessboard Distance ($D_8$):**
  $$D_8(P_1, P_2) = \max(|x_1 - x_2|, |y_1 - y_2|)$$
- **Neighborhood Intensities:** Live readout of $N_4(P_1)$ 4-neighbor pixels (Top, Bottom, Left, Right).

---

## Application Features

- **Intuitive Touch Controls & Usability:**
  - **Hold to Peek:** Press & hold the photo anywhere to peek at the original image; release to return to edited view.
  - **Before / After Split Compare:** Draggable vertical split slider comparing original and processed image side-by-side.
  - **Interactive Histogram:** Live 256-bin RGB + Luminance chart displaying Mean ($\mu$), Standard Deviation ($\sigma$), Dynamic Range, and Otsu's threshold marker ($T^*$).
  - **Dynamic Undo Counter:** Multi-step Undo stack with visual count badge and 1-tap Reset.
  - **Photo Geometry:** Rotate $90^\circ$ Clockwise, Horizontal Flip, Vertical Flip.
  - **High-Res Lossless Export:** Save edited results as 32-bit RGBA PNG files.
  - **Quick Start Guide:** Built-in modal overview explaining every tool and feature.
- **Built-in Procedural Phantoms (No internet required):**
  - ☀️ *Mountain Sunset* (Rich gradients & silhouettes for gamma/edges)
  - 🌓 *Low-Contrast Phantom* (Narrow mid-tones for histogram equalization)
  - 🪙 *Coins & Specimens* (Distinct foreground objects for Otsu/morphology)
  - 🏁 *DIP Test Chart* (Frequency bars & step wedges for quantization/Laplacian)

---

## Project Architecture

```
dip_studio/
├── lib/
│   ├── main.dart                          # App entry point & Material 3 Dark theme
│   ├── models/
│   │   └── pixel_image.dart               # 2D RGBA PixelImage, HistogramData, DipOperationRecord
│   ├── services/
│   │   ├── dip_engine.dart                # Core DIP engine (pure Dart pixel processing algorithms)
│   │   ├── sample_image_generator.dart    # Procedural mathematical test image generator
│   │   ├── image_export_models.dart       # Export result metadata model
│   │   ├── image_export_io.dart           # Native file saving to device Downloads / Pictures
│   │   ├── image_export_web.dart          # Web browser anchor download support
│   │   └── image_export_service.dart      # Platform conditional export service
│   ├── screens/
│   │   └── editor_screen.dart             # Main 5-tab workbench, interactive sliders, PNG export
│   └── widgets/
│       ├── digitization_calculator_sheet.dart # M×N×k bit-size calculator & 10 DIP steps reference
│       ├── histogram_chart.dart           # CustomPainter 256-bin intensity histogram
│       └── image_canvas_view.dart         # Split compare view, peek original, inspector crosshairs
├── test/
│   ├── widget_test.dart                   # Smoke test & preset verification
│   └── sqa_verification_test.dart         # Comprehensive 29-test SQA suite (Phases 1–8)
└── pubspec.yaml                           # Project dependencies and configurations
```

---

## Software Quality Assurance (SQA)

The project includes an automated SQA suite covering **29 unit, widget, and end-to-end integration tests**:

```powershell
flutter test --reporter expanded
```

### SQA Coverage Matrix
- **Phase 1: Digitization** — $1024 \times 1024 \times 8 = 8{,}388{,}608\text{ bits} = 1.00\text{ MB}$, spatial resolution downsampling, and $L \le 2^k$ quantization bounds.
- **Phase 2: Point Operations** — Grayscale $R=G=B$ invariant, double-negative involution $(s = 255 - r)$, log transform, gamma curves, and full $[0..255]$ contrast expansion.
- **Phase 3: Noise & Spatial Filtering** — Quantitative proof that Median filter reduces Salt & Pepper noise with lower Mean Absolute Error than Mean filter; proof of $180^\circ$ kernel rotation in Convolution vs. Correlation.
- **Phase 4: Segmentation** — Binary output invariants for Otsu & Canny, $K$-cluster limits in K-Means, and morphological shrink/grow invariants.
- **Phase 5: Mobile Portrait E2E** — Full walkthrough on a standard $412 \times 915$ phone viewport across all buttons, sliders, and bottom sheets.
- **Phase 6: Boundary Stress Tests** — Single-pixel $1 \times 1$ and uniform solid images (all-black, mid-gray, all-white) across all 24 `DipEngine` algorithms.
- **Phase 7: Multi-Viewport & Layouts** — Validated responsive layout rendering across $360 \times 640$ (compact phone), $412 \times 915$ (standard), and $1024 \times 768$ (tablet/desktop) with 0 pixel overflows.
- **Phase 8: Photo Editing Workflow** — Validated geometric rotations, mirror flips, live slider callbacks, undo stack operations, and lossless PNG export dialog.

---

## Installation & Running

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.29.0 or higher)
- Android Studio / Xcode / VS Code with Flutter extension

### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/mashkurulalamohi37/Photo_Editor-DIP-.git
   cd Photo_Editor-DIP-
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run static analyzer and test suite:
   ```bash
   flutter analyze
   flutter test
   ```
4. Launch the application:
   ```bash
   flutter run
   ```

---

## Building the Release APK

To compile an optimized Android release APK:

```bash
flutter build apk --release
```

The output APK will be generated at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Author & License

- **Author:** [Mashkurul Alam Ohi](https://github.com/mashkurulalamohi37)
- **Institution:** BAUST (Bangladesh Army University of Science and Technology)
- **Coursework:** Digital Image Processing (DIP) Lab

This project is licensed under the [MIT License](LICENSE).
