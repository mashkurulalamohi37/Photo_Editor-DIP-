import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import '../models/pixel_image.dart';

class DipEngine {
  /// Computes 256-bin histograms (R, G, B, Luminance), summary statistics,
  /// and Otsu's optimal threshold T*.
  static HistogramData computeHistogram(PixelImage image) {
    final red = List<int>.filled(256, 0);
    final green = List<int>.filled(256, 0);
    final blue = List<int>.filled(256, 0);
    final lum = List<int>.filled(256, 0);

    final bytes = image.pixels;
    final total = image.width * image.height;
    int minI = 255;
    int maxI = 0;
    double sumI = 0;

    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final y = ((77 * r + 150 * g + 29 * b) >> 8).clamp(0, 255);

      red[r]++;
      green[g]++;
      blue[b]++;
      lum[y]++;

      if (y < minI) minI = y;
      if (y > maxI) maxI = y;
      sumI += y;
    }

    final mean = total > 0 ? sumI / total : 0.0;
    double varianceSum = 0.0;
    for (int level = 0; level < 256; level++) {
      final count = lum[level];
      if (count > 0) {
        final diff = level - mean;
        varianceSum += count * diff * diff;
      }
    }
    final stdDev = total > 0 ? math.sqrt(varianceSum / total) : 0.0;
    final otsu = computeOtsuThresholdFromHistogram(lum, total);

    return HistogramData(
      red: red,
      green: green,
      blue: blue,
      luminance: lum,
      totalPixels: total,
      minIntensity: total > 0 ? minI : 0,
      maxIntensity: total > 0 ? maxI : 0,
      meanIntensity: mean,
      stdDevIntensity: stdDev,
      otsuThreshold: otsu,
    );
  }

  /// Otsu's method: finds threshold T in [0..255] that maximizes between-class variance:
  /// sigma_B^2(T) = w0 * w1 * (mu0 - mu1)^2
  static int computeOtsuThresholdFromHistogram(List<int> hist, int totalPixels) {
    if (totalPixels <= 0) return 128;

    double sumAll = 0;
    for (int t = 0; t < 256; t++) {
      sumAll += t * hist[t];
    }

    double sumBg = 0;
    int weightBg = 0;
    double maxVariance = -1.0;
    int bestThreshold = 128;

    for (int t = 0; t < 256; t++) {
      weightBg += hist[t];
      if (weightBg == 0) continue;

      final weightFg = totalPixels - weightBg;
      if (weightFg == 0) break;

      sumBg += t * hist[t];
      final meanBg = sumBg / weightBg;
      final meanFg = (sumAll - sumBg) / weightFg;

      final diff = meanBg - meanFg;
      final betweenVariance =
          weightBg.toDouble() * weightFg.toDouble() * diff * diff;

      if (betweenVariance > maxVariance) {
        maxVariance = betweenVariance;
        bestThreshold = t;
      }
    }
    return bestThreshold;
  }

  // ===========================================================================
  // 1. DIGITIZATION: SAMPLING & QUANTIZATION
  // ===========================================================================

  /// Simulates spatial sampling (downsampling by `samplingFactor` s)
  /// and intensity quantization (k bits/pixel -> L = 2^k gray/color levels).
  static PixelImage applyDigitization(
    PixelImage src, {
    required int samplingFactor,
    required int quantizationBits,
  }) {
    final s = samplingFactor.clamp(1, 64);
    final k = quantizationBits.clamp(1, 8);
    final levels = 1 << k; // L = 2^k
    final maxLevel = levels - 1;

    final out = Uint8List(src.pixels.length);
    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;

    for (int by = 0; by < h; by += s) {
      final blockH = math.min(s, h - by);
      for (int bx = 0; bx < w; bx += s) {
        final blockW = math.min(s, w - bx);

        // Average RGB within the s × s sampling cell
        int sumR = 0, sumG = 0, sumB = 0;
        final count = blockW * blockH;
        for (int dy = 0; dy < blockH; dy++) {
          final rowOffset = (by + dy) * w;
          for (int dx = 0; dx < blockW; dx++) {
            final idx = (rowOffset + bx + dx) << 2;
            sumR += inBytes[idx];
            sumG += inBytes[idx + 1];
            sumB += inBytes[idx + 2];
          }
        }

        final avgR = sumR ~/ count;
        final avgG = sumG ~/ count;
        final avgB = sumB ~/ count;

        // Quantize each channel to L = 2^k discrete intensity levels
        final qR = (((avgR * levels) >> 8) * 255) ~/ maxLevel;
        final qG = (((avgG * levels) >> 8) * 255) ~/ maxLevel;
        final qB = (((avgB * levels) >> 8) * 255) ~/ maxLevel;

        for (int dy = 0; dy < blockH; dy++) {
          final rowOffset = (by + dy) * w;
          for (int dx = 0; dx < blockW; dx++) {
            final idx = (rowOffset + bx + dx) << 2;
            out[idx] = qR.clamp(0, 255);
            out[idx + 1] = qG.clamp(0, 255);
            out[idx + 2] = qB.clamp(0, 255);
            out[idx + 3] = 255;
          }
        }
      }
    }

    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: k,
      samplingFactor: s,
    );
  }

  // ===========================================================================
  // 2. POINT OPERATIONS & ENHANCEMENT (SPATIAL DOMAIN)
  // ===========================================================================

  /// Converts image to grayscale using ITU-R BT.601 luminance:
  /// I = 0.299 R + 0.587 G + 0.114 B
  static PixelImage toGrayscale(PixelImage src) {
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);
    for (int i = 0; i < inBytes.length; i += 4) {
      final y = ((77 * inBytes[i] + 150 * inBytes[i + 1] + 29 * inBytes[i + 2]) >> 8)
          .clamp(0, 255);
      out[i] = y;
      out[i + 1] = y;
      out[i + 2] = y;
      out[i + 3] = inBytes[i + 3];
    }
    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Image Negative: s = (L - 1) - r = 255 - r
  static PixelImage invertNegative(PixelImage src) {
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);
    for (int i = 0; i < inBytes.length; i += 4) {
      out[i] = 255 - inBytes[i];
      out[i + 1] = 255 - inBytes[i + 1];
      out[i + 2] = 255 - inBytes[i + 2];
      out[i + 3] = inBytes[i + 3];
    }
    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Log Transformation: s = c * log(1 + r), expanding dark intensities.
  static PixelImage applyLogTransform(PixelImage src, {double gain = 1.0}) {
    final c = (255.0 / math.log(256.0)) * gain;
    final lut = Uint8List(256);
    for (int r = 0; r < 256; r++) {
      lut[r] = (c * math.log(1.0 + r)).round().clamp(0, 255);
    }
    return _applyLookUpTable(src, lut);
  }

  /// Power-Law (Gamma) Transformation: s = 255 * c * (r / 255)^gamma
  static PixelImage applyGammaTransform(
    PixelImage src, {
    required double gamma,
    double c = 1.0,
  }) {
    final lut = Uint8List(256);
    for (int r = 0; r < 256; r++) {
      final norm = r / 255.0;
      final mapped = 255.0 * c * math.pow(norm, gamma);
      lut[r] = mapped.round().clamp(0, 255);
    }
    return _applyLookUpTable(src, lut);
  }

  /// Linear Contrast Stretching: maps [r_min, r_max] -> [0, 255].
  static PixelImage applyContrastStretch(PixelImage src) {
    final hist = computeHistogram(src);
    final minI = hist.minIntensity;
    final maxI = hist.maxIntensity;
    if (maxI <= minI) return src.clone();
    final span = maxI - minI;

    final lut = Uint8List(256);
    for (int r = 0; r < 256; r++) {
      lut[r] = (((r - minI) * 255) ~/ span).clamp(0, 255);
    }
    return _applyLookUpTable(src, lut);
  }

  /// Histogram Equalization: spreads intensity values using the Cumulative
  /// Distribution Function (CDF) s_k = round((L - 1) * sum_{j=0}^k p_r(r_j)).
  static PixelImage applyHistogramEqualization(
    PixelImage src, {
    bool preserveColor = true,
  }) {
    final hist = computeHistogram(src);
    final total = hist.totalPixels;
    if (total == 0) return src.clone();

    final cdf = List<int>.filled(256, 0);
    int cumulative = 0;
    int cdfMin = 0;
    for (int k = 0; k < 256; k++) {
      cumulative += hist.luminance[k];
      cdf[k] = cumulative;
      if (cdfMin == 0 && cumulative > 0) {
        cdfMin = cumulative;
      }
    }

    final cdfLut = Uint8List(256);
    if (cdfMin >= total) {
      for (int k = 0; k < 256; k++) {
        cdfLut[k] = k;
      }
    } else {
      final denom = total - cdfMin;
      for (int k = 0; k < 256; k++) {
        if (cdf[k] <= cdfMin) {
          cdfLut[k] = 0;
        } else {
          cdfLut[k] = (((cdf[k] - cdfMin) * 255) / denom).round().clamp(0, 255);
        }
      }
    }

    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int i = 0; i < inBytes.length; i += 4) {
      final r = inBytes[i];
      final g = inBytes[i + 1];
      final b = inBytes[i + 2];
      final y = ((77 * r + 150 * g + 29 * b) >> 8).clamp(0, 255);
      final newY = cdfLut[y];

      if (!preserveColor) {
        out[i] = newY;
        out[i + 1] = newY;
        out[i + 2] = newY;
      } else if (y == 0) {
        out[i] = newY;
        out[i + 1] = newY;
        out[i + 2] = newY;
      } else {
        final ratio = newY / y;
        out[i] = (r * ratio).round().clamp(0, 255);
        out[i + 1] = (g * ratio).round().clamp(0, 255);
        out[i + 2] = (b * ratio).round().clamp(0, 255);
      }
      out[i + 3] = inBytes[i + 3];
    }

    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// HSV Color Processing (Hue rotation, Saturation scaling, Value/Brightness scaling).
  static PixelImage applyHsvAdjustment(
    PixelImage src, {
    required double hueShiftDeg,
    required double saturationScale,
    required double valueScale,
  }) {
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int i = 0; i < inBytes.length; i += 4) {
      final r = inBytes[i] / 255.0;
      final g = inBytes[i + 1] / 255.0;
      final b = inBytes[i + 2] / 255.0;

      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final delta = maxC - minC;

      // Hue in 0..360
      double h = 0.0;
      if (delta > 1e-5) {
        if (maxC == r) {
          h = 60.0 * (((g - b) / delta) % 6.0);
        } else if (maxC == g) {
          h = 60.0 * (((b - r) / delta) + 2.0);
        } else {
          h = 60.0 * (((r - g) / delta) + 4.0);
        }
      }
      if (h < 0) h += 360.0;

      final s = maxC <= 1e-5 ? 0.0 : (delta / maxC);
      final v = maxC;

      final newH = (h + hueShiftDeg) % 360.0;
      final wrappedH = newH < 0 ? newH + 360.0 : newH;
      final newS = (s * saturationScale).clamp(0.0, 1.0);
      final newV = (v * valueScale).clamp(0.0, 1.0);

      // HSV back to RGB
      final c = newV * newS;
      final x = c * (1.0 - (((wrappedH / 60.0) % 2.0) - 1.0).abs());
      final m = newV - c;

      double r1 = 0, g1 = 0, b1 = 0;
      if (wrappedH < 60) {
        r1 = c;
        g1 = x;
      } else if (wrappedH < 120) {
        r1 = x;
        g1 = c;
      } else if (wrappedH < 180) {
        g1 = c;
        b1 = x;
      } else if (wrappedH < 240) {
        g1 = x;
        b1 = c;
      } else if (wrappedH < 300) {
        r1 = x;
        b1 = c;
      } else {
        r1 = c;
        b1 = x;
      }

      out[i] = ((r1 + m) * 255.0).round().clamp(0, 255);
      out[i + 1] = ((g1 + m) * 255.0).round().clamp(0, 255);
      out[i + 2] = ((b1 + m) * 255.0).round().clamp(0, 255);
      out[i + 3] = inBytes[i + 3];
    }

    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  static PixelImage _applyLookUpTable(PixelImage src, Uint8List lut) {
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);
    for (int i = 0; i < inBytes.length; i += 4) {
      out[i] = lut[inBytes[i]];
      out[i + 1] = lut[inBytes[i + 1]];
      out[i + 2] = lut[inBytes[i + 2]];
      out[i + 3] = inBytes[i + 3];
    }
    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  // ===========================================================================
  // 3. NOISE MODELS & SPATIAL FILTERING (SMOOTHING, RESTORATION & SHARPENING)
  // ===========================================================================

  /// Adds Salt-and-Pepper (impulse) noise with total density `density` in [0..1].
  /// Best removed by a Median Filter.
  static PixelImage addSaltAndPepperNoise(
    PixelImage src, {
    double density = 0.06,
    int seed = 1337,
  }) {
    final rng = math.Random(seed);
    final out = Uint8List.fromList(src.pixels);
    final half = density / 2.0;

    for (int i = 0; i < out.length; i += 4) {
      final p = rng.nextDouble();
      if (p < half) {
        // Pepper (0)
        out[i] = 0;
        out[i + 1] = 0;
        out[i + 2] = 0;
      } else if (p < density) {
        // Salt (255)
        out[i] = 255;
        out[i + 1] = 255;
        out[i + 2] = 255;
      }
    }
    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Adds zero-mean Gaussian noise N(0, sigma^2) using the Box-Muller transform.
  static PixelImage addGaussianNoise(
    PixelImage src, {
    double sigma = 25.0,
    int seed = 2026,
  }) {
    final rng = math.Random(seed);
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int i = 0; i < inBytes.length; i += 4) {
      final u1 = math.max(1e-7, rng.nextDouble());
      final u2 = rng.nextDouble();
      final z = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
      final noise = (z * sigma).round();

      out[i] = (inBytes[i] + noise).clamp(0, 255);
      out[i + 1] = (inBytes[i + 1] + noise).clamp(0, 255);
      out[i + 2] = (inBytes[i + 2] + noise).clamp(0, 255);
      out[i + 3] = inBytes[i + 3];
    }
    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Adds multiplicative Speckle noise: g = f + n * f.
  static PixelImage addSpeckleNoise(
    PixelImage src, {
    double strength = 0.22,
    int seed = 9001,
  }) {
    final rng = math.Random(seed);
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int i = 0; i < inBytes.length; i += 4) {
      final n = (rng.nextDouble() * 2.0 - 1.0) * strength;
      out[i] = (inBytes[i] * (1.0 + n)).round().clamp(0, 255);
      out[i + 1] = (inBytes[i + 1] * (1.0 + n)).round().clamp(0, 255);
      out[i + 2] = (inBytes[i + 2] * (1.0 + n)).round().clamp(0, 255);
      out[i + 3] = inBytes[i + 3];
    }
    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Mean (Box) Smoothing Filter with k × k averaging neighborhood (k = 3 or 5).
  static PixelImage applyMeanFilter(PixelImage src, {int kernelSize = 3}) {
    final k = kernelSize <= 3 ? 3 : 5;
    final radius = k ~/ 2;
    final area = k * k;
    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        int sumR = 0, sumG = 0, sumB = 0;
        for (int ky = -radius; ky <= radius; ky++) {
          final py = (y + ky).clamp(0, h - 1);
          final rowOffset = py * w;
          for (int kx = -radius; kx <= radius; kx++) {
            final px = (x + kx).clamp(0, w - 1);
            final idx = (rowOffset + px) << 2;
            sumR += inBytes[idx];
            sumG += inBytes[idx + 1];
            sumB += inBytes[idx + 2];
          }
        }
        final outIdx = (y * w + x) << 2;
        out[outIdx] = sumR ~/ area;
        out[outIdx + 1] = sumG ~/ area;
        out[outIdx + 2] = sumB ~/ area;
        out[outIdx + 3] = 255;
      }
    }
    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Gaussian Smoothing Filter using a 2D Gaussian kernel G(x,y) = exp(-(x^2+y^2)/(2*sigma^2)).
  static PixelImage applyGaussianFilter(
    PixelImage src, {
    int kernelSize = 3,
    double sigma = 1.0,
  }) {
    final k = kernelSize <= 3 ? 3 : 5;
    final radius = k ~/ 2;
    final weights = List<double>.filled(k * k, 0.0);
    double weightSum = 0.0;
    final twoSigmaSq = 2.0 * sigma * sigma;

    int idx = 0;
    for (int ky = -radius; ky <= radius; ky++) {
      for (int kx = -radius; kx <= radius; kx++) {
        final wVal = math.exp(-(kx * kx + ky * ky) / twoSigmaSq);
        weights[idx++] = wVal;
        weightSum += wVal;
      }
    }
    for (int i = 0; i < weights.length; i++) {
      weights[i] /= weightSum;
    }

    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double sumR = 0, sumG = 0, sumB = 0;
        int wIdx = 0;
        for (int ky = -radius; ky <= radius; ky++) {
          final py = (y + ky).clamp(0, h - 1);
          final rowOffset = py * w;
          for (int kx = -radius; kx <= radius; kx++) {
            final px = (x + kx).clamp(0, w - 1);
            final pIdx = (rowOffset + px) << 2;
            final weight = weights[wIdx++];
            sumR += inBytes[pIdx] * weight;
            sumG += inBytes[pIdx + 1] * weight;
            sumB += inBytes[pIdx + 2] * weight;
          }
        }
        final outIdx = (y * w + x) << 2;
        out[outIdx] = sumR.round().clamp(0, 255);
        out[outIdx + 1] = sumG.round().clamp(0, 255);
        out[outIdx + 2] = sumB.round().clamp(0, 255);
        out[outIdx + 3] = 255;
      }
    }
    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Median Filter (Non-linear Order-Statistic Filter): replaces each pixel
  /// with the median of its k × k neighborhood. Best for removing salt-and-pepper noise!
  static PixelImage applyMedianFilter(PixelImage src, {int kernelSize = 3}) {
    final k = kernelSize <= 3 ? 3 : 5;
    final radius = k ~/ 2;
    final area = k * k;
    final mid = area ~/ 2;

    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    final windowR = List<int>.filled(area, 0);
    final windowG = List<int>.filled(area, 0);
    final windowB = List<int>.filled(area, 0);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        int n = 0;
        for (int ky = -radius; ky <= radius; ky++) {
          final py = (y + ky).clamp(0, h - 1);
          final rowOffset = py * w;
          for (int kx = -radius; kx <= radius; kx++) {
            final px = (x + kx).clamp(0, w - 1);
            final pIdx = (rowOffset + px) << 2;
            windowR[n] = inBytes[pIdx];
            windowG[n] = inBytes[pIdx + 1];
            windowB[n] = inBytes[pIdx + 2];
            n++;
          }
        }
        windowR.sort();
        windowG.sort();
        windowB.sort();

        final outIdx = (y * w + x) << 2;
        out[outIdx] = windowR[mid];
        out[outIdx + 1] = windowG[mid];
        out[outIdx + 2] = windowB[mid];
        out[outIdx + 3] = 255;
      }
    }
    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Laplacian 2nd-Order Derivative Filter.
  /// If `sharpenImage` is true, returns g(x,y) = f(x,y) - c * nabla^2 f(x,y).
  /// If `sharpenImage` is false, returns the absolute Laplacian edge map |nabla^2 f|.
  static PixelImage applyLaplacianFilter(
    PixelImage src, {
    bool sharpenImage = true,
    bool eightNeighbor = true,
    double strength = 1.0,
  }) {
    final kernel = eightNeighbor
        ? const <int>[
            1, 1, 1,
            1, -8, 1,
            1, 1, 1,
          ]
        : const <int>[
            0, 1, 0,
            1, -4, 1,
            0, 1, 0,
          ];

    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        int lapR = 0, lapG = 0, lapB = 0;
        int kIdx = 0;
        for (int ky = -1; ky <= 1; ky++) {
          final py = (y + ky).clamp(0, h - 1);
          final rowOffset = py * w;
          for (int kx = -1; kx <= 1; kx++) {
            final px = (x + kx).clamp(0, w - 1);
            final pIdx = (rowOffset + px) << 2;
            final weight = kernel[kIdx++];
            lapR += inBytes[pIdx] * weight;
            lapG += inBytes[pIdx + 1] * weight;
            lapB += inBytes[pIdx + 2] * weight;
          }
        }

        final outIdx = (y * w + x) << 2;
        if (sharpenImage) {
          out[outIdx] = (inBytes[outIdx] - (lapR * strength)).round().clamp(0, 255);
          out[outIdx + 1] =
              (inBytes[outIdx + 1] - (lapG * strength)).round().clamp(0, 255);
          out[outIdx + 2] =
              (inBytes[outIdx + 2] - (lapB * strength)).round().clamp(0, 255);
        } else {
          final edge =
              (((lapR.abs() + lapG.abs() + lapB.abs()) ~/ 3) * strength)
                  .round()
                  .clamp(0, 255);
          out[outIdx] = edge;
          out[outIdx + 1] = edge;
          out[outIdx + 2] = edge;
        }
        out[outIdx + 3] = 255;
      }
    }
    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Sobel Gradient Edge Operator: computes horizontal Gx and vertical Gy
  /// first-order derivatives and outputs gradient magnitude |G| = sqrt(Gx^2 + Gy^2).
  static PixelImage applySobelFilter(PixelImage src) {
    const gxKernel = <int>[
      -1, 0, 1,
      -2, 0, 2,
      -1, 0, 1,
    ];
    const gyKernel = <int>[
      -1, -2, -1,
       0,  0,  0,
       1,  2,  1,
    ];

    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;
    final lum = Uint8List(w * h);
    for (int i = 0, p = 0; i < inBytes.length; i += 4, p++) {
      lum[p] = ((77 * inBytes[i] + 150 * inBytes[i + 1] + 29 * inBytes[i + 2]) >> 8)
          .clamp(0, 255);
    }

    final out = Uint8List(inBytes.length);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        int gx = 0;
        int gy = 0;
        int kIdx = 0;
        for (int ky = -1; ky <= 1; ky++) {
          final py = (y + ky).clamp(0, h - 1);
          final rowOffset = py * w;
          for (int kx = -1; kx <= 1; kx++) {
            final px = (x + kx).clamp(0, w - 1);
            final intensity = lum[rowOffset + px];
            gx += intensity * gxKernel[kIdx];
            gy += intensity * gyKernel[kIdx];
            kIdx++;
          }
        }
        final mag = math.sqrt((gx * gx + gy * gy).toDouble()).round().clamp(0, 255);
        final outIdx = (y * w + x) << 2;
        out[outIdx] = mag;
        out[outIdx + 1] = mag;
        out[outIdx + 2] = mag;
        out[outIdx + 3] = 255;
      }
    }

    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Demonstrates 3×3 Spatial Convolution vs. Correlation!
  /// Section 5: "Convolution vs. correlation: convolution flips the kernel 180° first".
  static PixelImage applyCustomKernel3x3(
    PixelImage src, {
    required List<double> kernel,
    required bool isConvolution,
    double bias = 0.0,
  }) {
    assert(kernel.length == 9);
    // If convolution is selected, flip the 3x3 kernel 180 degrees (reverse order)
    final activeKernel =
        isConvolution ? kernel.reversed.toList(growable: false) : kernel;

    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double sumR = bias, sumG = bias, sumB = bias;
        int kIdx = 0;
        for (int ky = -1; ky <= 1; ky++) {
          final py = (y + ky).clamp(0, h - 1);
          final rowOffset = py * w;
          for (int kx = -1; kx <= 1; kx++) {
            final px = (x + kx).clamp(0, w - 1);
            final pIdx = (rowOffset + px) << 2;
            final weight = activeKernel[kIdx++];
            sumR += inBytes[pIdx] * weight;
            sumG += inBytes[pIdx + 1] * weight;
            sumB += inBytes[pIdx + 2] * weight;
          }
        }
        final outIdx = (y * w + x) << 2;
        out[outIdx] = sumR.round().clamp(0, 255);
        out[outIdx + 1] = sumG.round().clamp(0, 255);
        out[outIdx + 2] = sumB.round().clamp(0, 255);
        out[outIdx + 3] = 255;
      }
    }

    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  // ===========================================================================
  // 4. SEGMENTATION & MORPHOLOGICAL PROCESSING
  // ===========================================================================

  /// Global Binary Thresholding: g(x,y) = 255 if I(x,y) >= T else 0.
  static PixelImage applyThreshold(PixelImage src, {required int threshold}) {
    final t = threshold.clamp(0, 255);
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int i = 0; i < inBytes.length; i += 4) {
      final y = ((77 * inBytes[i] + 150 * inBytes[i + 1] + 29 * inBytes[i + 2]) >> 8);
      final bin = y >= t ? 255 : 0;
      out[i] = bin;
      out[i + 1] = bin;
      out[i + 2] = bin;
      out[i + 3] = 255;
    }

    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: 1,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Automatic Otsu's Thresholding: computes optimal T* that maximizes
  /// between-class variance and segments the image into foreground/background.
  static ({PixelImage image, int threshold}) applyOtsuThreshold(PixelImage src) {
    final hist = computeHistogram(src);
    final t = hist.otsuThreshold;
    return (image: applyThreshold(src, threshold: t), threshold: t);
  }

  /// Canny Edge Detection (4-stage pipeline: Gaussian smooth -> Sobel gradient
  /// -> Non-maximum suppression -> Double threshold & hysteresis).
  static PixelImage applyCannyEdgeDetection(
    PixelImage src, {
    double lowThreshold = 35.0,
    double highThreshold = 85.0,
  }) {
    final smoothed = applyGaussianFilter(src, kernelSize: 3, sigma: 1.1);
    final w = smoothed.width;
    final h = smoothed.height;
    final inBytes = smoothed.pixels;

    final lum = Uint8List(w * h);
    for (int i = 0, p = 0; i < inBytes.length; i += 4, p++) {
      lum[p] = ((77 * inBytes[i] + 150 * inBytes[i + 1] + 29 * inBytes[i + 2]) >> 8)
          .clamp(0, 255);
    }

    final mag = Float32List(w * h);
    final dir = Uint8List(w * h); // Quantized angle: 0, 45, 90, 135

    const gxK = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
    const gyK = [-1, -2, -1, 0, 0, 0, 1, 2, 1];

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        int gx = 0, gy = 0, k = 0;
        for (int ky = -1; ky <= 1; ky++) {
          final row = (y + ky) * w;
          for (int kx = -1; kx <= 1; kx++) {
            final val = lum[row + x + kx];
            gx += val * gxK[k];
            gy += val * gyK[k];
            k++;
          }
        }
        final idx = y * w + x;
        mag[idx] = math.sqrt((gx * gx + gy * gy).toDouble());

        double angle = math.atan2(gy.toDouble(), gx.toDouble()) * 180.0 / math.pi;
        if (angle < 0) angle += 180.0;
        if (angle < 22.5 || angle >= 157.5) {
          dir[idx] = 0;
        } else if (angle < 67.5) {
          dir[idx] = 45;
        } else if (angle < 112.5) {
          dir[idx] = 90;
        } else {
          dir[idx] = 135;
        }
      }
    }

    // Non-maximum suppression + double threshold
    final state = Uint8List(w * h); // 0 = non-edge, 1 = weak, 2 = strong
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final idx = y * w + x;
        final m = mag[idx];
        double n1 = 0, n2 = 0;
        switch (dir[idx]) {
          case 0:
            n1 = mag[idx - 1];
            n2 = mag[idx + 1];
            break;
          case 45:
            n1 = mag[(y - 1) * w + (x + 1)];
            n2 = mag[(y + 1) * w + (x - 1)];
            break;
          case 90:
            n1 = mag[(y - 1) * w + x];
            n2 = mag[(y + 1) * w + x];
            break;
          default:
            n1 = mag[(y - 1) * w + (x - 1)];
            n2 = mag[(y + 1) * w + (x + 1)];
            break;
        }
        if (m >= n1 && m >= n2) {
          if (m >= highThreshold) {
            state[idx] = 2;
          } else if (m >= lowThreshold) {
            state[idx] = 1;
          }
        }
      }
    }

    // Hysteresis: promote weak edges connected to strong edges
    final out = Uint8List(inBytes.length);
    for (int i = 3; i < out.length; i += 4) {
      out[i] = 255;
    }
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final idx = y * w + x;
        bool isEdge = state[idx] == 2;
        if (state[idx] == 1) {
          for (int ky = -1; ky <= 1 && !isEdge; ky++) {
            for (int kx = -1; kx <= 1; kx++) {
              if (state[(y + ky) * w + (x + kx)] == 2) {
                isEdge = true;
                break;
              }
            }
          }
        }
        final v = isEdge ? 255 : 0;
        final outIdx = idx << 2;
        out[outIdx] = v;
        out[outIdx + 1] = v;
        out[outIdx + 2] = v;
        out[outIdx + 3] = 255;
      }
    }

    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: 1,
      samplingFactor: src.samplingFactor,
    );
  }

  /// K-Means Clustering Segmentation: partitions pixels into K color clusters.
  static PixelImage applyKMeansSegmentation(
    PixelImage src, {
    int k = 4,
    int maxIterations = 10,
  }) {
    final clusters = k.clamp(2, 12);
    final inBytes = src.pixels;
    final numPixels = src.width * src.height;
    if (numPixels == 0) return src.clone();

    // Initialize centroids evenly spaced across image percentiles
    final centroidsR = List<double>.filled(clusters, 0);
    final centroidsG = List<double>.filled(clusters, 0);
    final centroidsB = List<double>.filled(clusters, 0);

    for (int c = 0; c < clusters; c++) {
      final sampleIdx = (((c + 0.5) / clusters) * numPixels).floor().clamp(0, numPixels - 1) << 2;
      centroidsR[c] = inBytes[sampleIdx].toDouble();
      centroidsG[c] = inBytes[sampleIdx + 1].toDouble();
      centroidsB[c] = inBytes[sampleIdx + 2].toDouble();
    }

    final labels = Uint8List(numPixels);
    final sumR = List<double>.filled(clusters, 0);
    final sumG = List<double>.filled(clusters, 0);
    final sumB = List<double>.filled(clusters, 0);
    final counts = List<int>.filled(clusters, 0);

    for (int iter = 0; iter < maxIterations; iter++) {
      for (int c = 0; c < clusters; c++) {
        sumR[c] = 0;
        sumG[c] = 0;
        sumB[c] = 0;
        counts[c] = 0;
      }

      bool changed = false;
      for (int p = 0, i = 0; p < numPixels; p++, i += 4) {
        final r = inBytes[i].toDouble();
        final g = inBytes[i + 1].toDouble();
        final b = inBytes[i + 2].toDouble();

        int bestCluster = 0;
        double bestDist = double.infinity;

        for (int c = 0; c < clusters; c++) {
          final dr = r - centroidsR[c];
          final dg = g - centroidsG[c];
          final db = b - centroidsB[c];
          final dist = dr * dr + dg * dg + db * db;
          if (dist < bestDist) {
            bestDist = dist;
            bestCluster = c;
          }
        }

        if (labels[p] != bestCluster) {
          labels[p] = bestCluster;
          changed = true;
        }
        sumR[bestCluster] += r;
        sumG[bestCluster] += g;
        sumB[bestCluster] += b;
        counts[bestCluster]++;
      }

      for (int c = 0; c < clusters; c++) {
        if (counts[c] > 0) {
          centroidsR[c] = sumR[c] / counts[c];
          centroidsG[c] = sumG[c] / counts[c];
          centroidsB[c] = sumB[c] / counts[c];
        }
      }
      if (!changed && iter > 0) break;
    }

    final out = Uint8List(inBytes.length);
    for (int p = 0, i = 0; p < numPixels; p++, i += 4) {
      final c = labels[p];
      out[i] = centroidsR[c].round().clamp(0, 255);
      out[i + 1] = centroidsG[c].round().clamp(0, 255);
      out[i + 2] = centroidsB[c].round().clamp(0, 255);
      out[i + 3] = 255;
    }

    return PixelImage(
      width: src.width,
      height: src.height,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Region Growing Segmentation from a seed point (seedX, seedY) using
  /// 4-connectivity or 8-connectivity and intensity similarity threshold `tolerance`.
  static ({PixelImage image, int grownPixels}) applyRegionGrowing(
    PixelImage src, {
    required int seedX,
    required int seedY,
    int tolerance = 28,
    bool eightConnected = true,
  }) {
    final w = src.width;
    final h = src.height;
    final sx = seedX.clamp(0, w - 1);
    final sy = seedY.clamp(0, h - 1);

    final seedLum = src.getLuminance(sx, sy);
    final visited = Uint8List(w * h);
    final mask = Uint8List(w * h);
    final queue = Queue<int>();

    final startIdx = sy * w + sx;
    visited[startIdx] = 1;
    mask[startIdx] = 1;
    queue.add(startIdx);
    int grownCount = 1;

    final dirsX = eightConnected
        ? const [-1, 1, 0, 0, -1, -1, 1, 1]
        : const [-1, 1, 0, 0];
    final dirsY = eightConnected
        ? const [0, 0, -1, 1, -1, 1, -1, 1]
        : const [0, 0, -1, 1];

    while (queue.isNotEmpty) {
      final curr = queue.removeFirst();
      final cx = curr % w;
      final cy = curr ~/ w;

      for (int d = 0; d < dirsX.length; d++) {
        final nx = cx + dirsX[d];
        final ny = cy + dirsY[d];
        if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;

        final nIdx = ny * w + nx;
        if (visited[nIdx] != 0) continue;
        visited[nIdx] = 1;

        final lum = src.getLuminance(nx, ny);
        if ((lum - seedLum).abs() <= tolerance) {
          mask[nIdx] = 1;
          grownCount++;
          queue.add(nIdx);
        }
      }
    }

    // Highlight grown region in vibrant emerald/cyan overlay, dim non-region background
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);
    for (int p = 0, i = 0; p < mask.length; p++, i += 4) {
      if (mask[p] == 1) {
        out[i] = ((inBytes[i] * 0.35) + 40).round().clamp(0, 255);
        out[i + 1] = ((inBytes[i + 1] * 0.45) + 215).round().clamp(0, 255);
        out[i + 2] = ((inBytes[i + 2] * 0.45) + 185).round().clamp(0, 255);
      } else {
        final y = ((77 * inBytes[i] + 150 * inBytes[i + 1] + 29 * inBytes[i + 2]) >> 9);
        out[i] = y;
        out[i + 1] = y;
        out[i + 2] = y;
      }
      out[i + 3] = 255;
    }

    return (
      image: PixelImage(
        width: w,
        height: h,
        pixels: out,
        quantizationBits: src.quantizationBits,
        samplingFactor: src.samplingFactor,
      ),
      grownPixels: grownCount,
    );
  }

  /// Morphological Erosion (local minimum) or Dilation (local maximum)
  /// using a k × k square structuring element.
  static PixelImage applyMorphology(
    PixelImage src, {
    required bool isDilation,
    int kernelSize = 3,
  }) {
    final k = kernelSize <= 3 ? 3 : 5;
    final radius = k ~/ 2;
    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        int bestR = isDilation ? 0 : 255;
        int bestG = isDilation ? 0 : 255;
        int bestB = isDilation ? 0 : 255;

        for (int ky = -radius; ky <= radius; ky++) {
          final py = (y + ky).clamp(0, h - 1);
          final rowOffset = py * w;
          for (int kx = -radius; kx <= radius; kx++) {
            final px = (x + kx).clamp(0, w - 1);
            final idx = (rowOffset + px) << 2;
            final r = inBytes[idx];
            final g = inBytes[idx + 1];
            final b = inBytes[idx + 2];
            if (isDilation) {
              if (r > bestR) bestR = r;
              if (g > bestG) bestG = g;
              if (b > bestB) bestB = b;
            } else {
              if (r < bestR) bestR = r;
              if (g < bestG) bestG = g;
              if (b < bestB) bestB = b;
            }
          }
        }

        final outIdx = (y * w + x) << 2;
        out[outIdx] = bestR;
        out[outIdx + 1] = bestG;
        out[outIdx + 2] = bestB;
        out[outIdx + 3] = 255;
      }
    }

    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  // ===========================================================================
  // 5. PHOTO EDITING: BRIGHTNESS/CONTRAST & GEOMETRIC TRANSFORMATIONS
  // ===========================================================================

  /// Linear Brightness & Contrast adjustment:
  /// s = clamp((r - 128) * contrast + 128 + brightness, 0, 255)
  static PixelImage applyBrightnessContrast(
    PixelImage src, {
    required int brightness,
    required double contrast,
  }) {
    final lut = Uint8List(256);
    for (int r = 0; r < 256; r++) {
      final mapped = ((r - 128.0) * contrast + 128.0 + brightness).round();
      lut[r] = mapped.clamp(0, 255);
    }
    return _applyLookUpTable(src, lut);
  }

  /// Rotates image 90 degrees clockwise: (x, y) -> (height - 1 - y, x).
  static PixelImage rotate90Clockwise(PixelImage src) {
    final newW = src.height;
    final newH = src.width;
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final srcIdx = (y * src.width + x) << 2;
        final dstX = src.height - 1 - y;
        final dstY = x;
        final dstIdx = (dstY * newW + dstX) << 2;
        out[dstIdx] = inBytes[srcIdx];
        out[dstIdx + 1] = inBytes[srcIdx + 1];
        out[dstIdx + 2] = inBytes[srcIdx + 2];
        out[dstIdx + 3] = inBytes[srcIdx + 3];
      }
    }

    return PixelImage(
      width: newW,
      height: newH,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Flips image horizontally (left <-> right mirror).
  static PixelImage flipHorizontal(PixelImage src) {
    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int y = 0; y < h; y++) {
      final rowOffset = y * w;
      for (int x = 0; x < w; x++) {
        final srcIdx = (rowOffset + x) << 2;
        final dstIdx = (rowOffset + (w - 1 - x)) << 2;
        out[dstIdx] = inBytes[srcIdx];
        out[dstIdx + 1] = inBytes[srcIdx + 1];
        out[dstIdx + 2] = inBytes[srcIdx + 2];
        out[dstIdx + 3] = inBytes[srcIdx + 3];
      }
    }

    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }

  /// Flips image vertically (top <-> bottom mirror).
  static PixelImage flipVertical(PixelImage src) {
    final w = src.width;
    final h = src.height;
    final inBytes = src.pixels;
    final out = Uint8List(inBytes.length);

    for (int y = 0; y < h; y++) {
      final srcRow = y * w;
      final dstRow = (h - 1 - y) * w;
      for (int x = 0; x < w; x++) {
        final srcIdx = (srcRow + x) << 2;
        final dstIdx = (dstRow + x) << 2;
        out[dstIdx] = inBytes[srcIdx];
        out[dstIdx + 1] = inBytes[srcIdx + 1];
        out[dstIdx + 2] = inBytes[srcIdx + 2];
        out[dstIdx + 3] = inBytes[srcIdx + 3];
      }
    }

    return PixelImage(
      width: w,
      height: h,
      pixels: out,
      quantizationBits: src.quantizationBits,
      samplingFactor: src.samplingFactor,
    );
  }
}
