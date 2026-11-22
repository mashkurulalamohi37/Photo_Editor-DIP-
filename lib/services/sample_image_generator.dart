import 'dart:math' as math;
import 'dart:typed_data';
import '../models/pixel_image.dart';

class SampleImagePreset {
  final String id;
  final String name;
  final String subtitle;
  final String bestFor;

  const SampleImagePreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.bestFor,
  });
}

class SampleImageGenerator {
  static const List<SampleImagePreset> presets = [
    SampleImagePreset(
      id: 'sunset',
      name: 'Mountain Sunset',
      subtitle: 'Rich RGB scene with gradients & silhouettes',
      bestFor: 'Point Ops, Gamma, K-Means, Sobel Edges',
    ),
    SampleImagePreset(
      id: 'low_contrast',
      name: 'Low-Contrast Phantom',
      subtitle: 'Narrow histogram compressed in mid-tones',
      bestFor: 'Histogram Equalization, Contrast Stretch, Log',
    ),
    SampleImagePreset(
      id: 'coins_cells',
      name: 'Coins & Specimens',
      subtitle: 'Distinct foreground objects on clean background',
      bestFor: 'Otsu Thresholding, Morphology, Median Filter',
    ),
    SampleImagePreset(
      id: 'test_card',
      name: 'DIP Test Chart',
      subtitle: 'Resolution bars, step wedge & geometric edges',
      bestFor: 'Sampling/Quantization, Laplacian, Convolution',
    ),
  ];

  static PixelImage generate(String presetId, {int size = 360}) {
    switch (presetId) {
      case 'low_contrast':
        return _generateLowContrastPhantom(size, size);
      case 'coins_cells':
        return _generateCoinsAndSpecimens(size, size);
      case 'test_card':
        return _generateDipTestChart(size, size);
      case 'sunset':
      default:
        return _generateMountainSunset(size, size);
    }
  }

  /// 1. Rich RGB Mountain Sunset with sun disk, layered mountains, and water reflection.
  static PixelImage _generateMountainSunset(int width, int height) {
    final pixels = Uint8List(width * height * 4);
    final sunCx = width * 0.62;
    final sunCy = height * 0.34;
    final sunRadius = width * 0.14;
    final horizonY = (height * 0.66).round();

    for (int y = 0; y < height; y++) {
      final isWater = y >= horizonY;
      // Mirror y across horizon for water reflection
      final sampleY = isWater
          ? (horizonY - (y - horizonY) * 0.85).clamp(0.0, horizonY.toDouble())
          : y.toDouble();
      final tSky = (sampleY / horizonY).clamp(0.0, 1.0);

      for (int x = 0; x < width; x++) {
        // Sky gradient: deep indigo top -> magenta mid -> warm orange horizon
        double r = _lerp(24, 248, math.pow(tSky, 0.85).toDouble());
        double g = _lerp(28, 135, math.pow(tSky, 1.15).toDouble());
        double b = _lerp(92, 68, tSky);

        // Sun glow & disk
        final dx = x - sunCx;
        final dy = sampleY - sunCy;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < sunRadius) {
          final inner = (1.0 - dist / sunRadius).clamp(0.0, 1.0);
          r = _lerp(r, 255, 0.85 + 0.15 * inner);
          g = _lerp(g, 242, 0.75 + 0.25 * inner);
          b = _lerp(b, 175, 0.65 + 0.35 * inner);
        } else if (dist < sunRadius * 2.4) {
          final glow =
              math.pow(1.0 - (dist - sunRadius) / (sunRadius * 1.4), 2).toDouble();
          r = (r + 70 * glow).clamp(0, 255);
          g = (g + 45 * glow).clamp(0, 255);
          b = (b + 15 * glow).clamp(0, 255);
        }

        // Far mountain ridge
        final nx = x / width;
        final ridge1 = horizonY *
            (0.60 +
                0.15 * math.sin(nx * 5.2 + 0.4) +
                0.07 * math.cos(nx * 13.0) +
                0.03 * math.sin(nx * 27.0));
        // Near mountain ridge
        final ridge2 = horizonY *
            (0.75 +
                0.14 * math.sin(nx * 3.8 + 2.1) +
                0.06 * math.sin(nx * 11.5 + 1.0));

        if (sampleY > ridge1) {
          final depth = ((sampleY - ridge1) / (horizonY - ridge1 + 1)).clamp(0.0, 1.0);
          r = _lerp(88, 52, depth);
          g = _lerp(56, 36, depth);
          b = _lerp(112, 74, depth);
        }
        if (sampleY > ridge2) {
          final depth = ((sampleY - ridge2) / (horizonY - ridge2 + 1)).clamp(0.0, 1.0);
          r = _lerp(42, 20, depth);
          g = _lerp(28, 16, depth);
          b = _lerp(58, 34, depth);
        }

        // Water ripples and darkening
        if (isWater) {
          final waterDepth = ((y - horizonY) / (height - horizonY)).clamp(0.0, 1.0);
          final ripple = math.sin(y * 0.45 + x * 0.08) * 10.0 * (1.0 - waterDepth * 0.5);
          r = (r * 0.78 + ripple).clamp(0, 255);
          g = (g * 0.76 + ripple * 0.8).clamp(0, 255);
          b = (b * 0.88 + 18 + ripple * 0.5).clamp(0, 255);
        }

        final idx = (y * width + x) << 2;
        pixels[idx] = r.round().clamp(0, 255);
        pixels[idx + 1] = g.round().clamp(0, 255);
        pixels[idx + 2] = b.round().clamp(0, 255);
        pixels[idx + 3] = 255;
      }
    }

    return PixelImage(width: width, height: height, pixels: pixels);
  }

  /// 2. Low-Contrast Medical Phantom (Shepp-Logan inspired) compressed into narrow intensity band [88..152].
  /// Applying Histogram Equalization expands this to [0..255] with dramatic clarity.
  static PixelImage _generateLowContrastPhantom(int width, int height) {
    final pixels = Uint8List(width * height * 4);
    for (int y = 0; y < height; y++) {
      final ny = (y - height / 2) / (height / 2);
      for (int x = 0; x < width; x++) {
        final nx = (x - width / 2) / (width / 2);

        // Base compressed intensity (narrow mid-gray background)
        double intensity = 96.0;

        // Outer skull ring
        final outer = (nx * nx) / (0.72 * 0.72) + (ny * ny) / (0.88 * 0.88);
        final inner = (nx * nx) / (0.64 * 0.64) + (ny * ny) / (0.80 * 0.80);
        if (outer <= 1.0) {
          intensity = 148.0; // Outer bone shell
        }
        if (inner <= 1.0) {
          // Soft tissue interior with gentle radial shading
          intensity = 114.0 + 6.0 * (1.0 - inner);

          // Left & right ventricles (darker tilted ellipses)
          final lx = nx + 0.22;
          final ly = ny - 0.02;
          final rotL1 = lx * math.cos(0.32) - ly * math.sin(0.32);
          final rotL2 = lx * math.sin(0.32) + ly * math.cos(0.32);
          if ((rotL1 * rotL1) / (0.14 * 0.14) + (rotL2 * rotL2) / (0.31 * 0.31) <= 1.0) {
            intensity -= 18.0;
          }

          final rx = nx - 0.22;
          final ry = ny - 0.02;
          final rotR1 = rx * math.cos(-0.32) - ry * math.sin(-0.32);
          final rotR2 = rx * math.sin(-0.32) + ry * math.cos(-0.32);
          if ((rotR1 * rotR1) / (0.14 * 0.14) + (rotR2 * rotR2) / (0.31 * 0.31) <= 1.0) {
            intensity -= 18.0;
          }

          // Upper bright tissue structure
          if ((nx * nx) / (0.24 * 0.24) + ((ny + 0.36) * (ny + 0.36)) / (0.20 * 0.20) <=
              1.0) {
            intensity += 16.0;
          }

          // Three small focal nodules at bottom
          if ((nx * nx) / (0.08 * 0.08) + ((ny - 0.44) * (ny - 0.44)) / (0.08 * 0.08) <=
              1.0) {
            intensity += 22.0;
          }
          if (((nx + 0.16) * (nx + 0.16)) / (0.05 * 0.05) +
                  ((ny - 0.56) * (ny - 0.56)) / (0.05 * 0.05) <=
              1.0) {
            intensity += 20.0;
          }
          if (((nx - 0.16) * (nx - 0.16)) / (0.05 * 0.05) +
                  ((ny - 0.56) * (ny - 0.56)) / (0.05 * 0.05) <=
              1.0) {
            intensity += 20.0;
          }
        }

        final v = intensity.round().clamp(0, 255);
        final idx = (y * width + x) << 2;
        pixels[idx] = v;
        pixels[idx + 1] = v;
        pixels[idx + 2] = (v + 4).clamp(0, 255);
        pixels[idx + 3] = 255;
      }
    }
    return PixelImage(width: width, height: height, pixels: pixels);
  }

  /// 3. Coins & Specimens on dark table: great for Otsu thresholding, morphology, and noise removal.
  static PixelImage _generateCoinsAndSpecimens(int width, int height) {
    final pixels = Uint8List(width * height * 4);
    final objects = <List<double>>[
      // [cx, cy, radius, r, g, b]
      [0.26, 0.28, 0.15, 232, 192, 110], // Gold coin
      [0.68, 0.26, 0.13, 212, 216, 224], // Silver coin
      [0.48, 0.54, 0.17, 240, 172, 102], // Copper medal
      [0.24, 0.74, 0.11, 200, 218, 230], // Small silver coin
      [0.74, 0.72, 0.14, 236, 204, 124], // Brass token
    ];

    for (int y = 0; y < height; y++) {
      final ny = y / height;
      for (int x = 0; x < width; x++) {
        final nx = x / width;
        // Dark slate background with subtle vignette illumination
        final dxBg = nx - 0.5;
        final dyBg = ny - 0.5;
        final vig = (1.0 - (dxBg * dxBg + dyBg * dyBg) * 0.9).clamp(0.4, 1.0);
        double r = 34 * vig;
        double g = 40 * vig;
        double b = 48 * vig;

        for (final obj in objects) {
          final dx = nx - obj[0];
          final dy = ny - obj[1];
          final dist = math.sqrt(dx * dx + dy * dy);
          final rad = obj[2];
          if (dist <= rad) {
            final normDist = dist / rad;
            // 3D specular highlight + rim ridge
            final light = ((dx / rad) * -0.4 + (dy / rad) * -0.5 + 0.85).clamp(0.55, 1.18);
            final rim = (normDist > 0.86 && normDist < 0.95) ? 1.12 : 1.0;
            final ring = ((normDist * 18).floor().isEven) ? 1.02 : 0.98;
            r = (obj[3] * light * rim * ring).clamp(0, 255);
            g = (obj[4] * light * rim * ring).clamp(0, 255);
            b = (obj[5] * light * rim * ring).clamp(0, 255);
            break;
          } else if (dist <= rad * 1.06) {
            // Soft drop shadow
            r *= 0.65;
            g *= 0.65;
            b *= 0.65;
          }
        }

        final idx = (y * width + x) << 2;
        pixels[idx] = r.round().clamp(0, 255);
        pixels[idx + 1] = g.round().clamp(0, 255);
        pixels[idx + 2] = b.round().clamp(0, 255);
        pixels[idx + 3] = 255;
      }
    }
    return PixelImage(width: width, height: height, pixels: pixels);
  }

  /// 4. DIP Test Chart with continuous gradient ramp, step quantization wedge,
  /// high-frequency resolution bars, and sharp geometric shapes.
  static PixelImage _generateDipTestChart(int width, int height) {
    final pixels = Uint8List(width * height * 4);
    for (int y = 0; y < height; y++) {
      final ny = y / height;
      for (int x = 0; x < width; x++) {
        final nx = x / width;
        int r = 0, g = 0, b = 0;

        if (ny < 0.22) {
          // Top strip: continuous 0..255 intensity ramp (perfect for quantization contouring test!)
          final v = (nx * 255).round().clamp(0, 255);
          r = v;
          g = v;
          b = v;
        } else if (ny < 0.36) {
          // Second strip: RGB primary & secondary color bars
          final bar = (nx * 6).floor().clamp(0, 5);
          const colors = [
            [235, 55, 55],
            [240, 200, 45],
            [50, 205, 95],
            [45, 205, 225],
            [65, 95, 235],
            [215, 65, 210],
          ];
          r = colors[bar][0];
          g = colors[bar][1];
          b = colors[bar][2];
        } else {
          // Lower 64%: Left = Concentric circular zone plate, Right = Checkerboard & geometric shapes
          if (nx < 0.5) {
            final cx = 0.25;
            final cy = 0.68;
            final dx = nx - cx;
            final dy = ny - cy;
            final dist = math.sqrt(dx * dx + dy * dy);
            if (dist < 0.21) {
              final wave = (math.cos(dist * 140.0) * 0.5 + 0.5);
              final v = (wave * 230 + 15).round().clamp(0, 255);
              r = v;
              g = v;
              b = v;
            } else {
              r = 38;
              g = 44;
              b = 54;
            }
          } else {
            // Right quadrant: sharp diagonal star + checkerboard grid
            final gx = ((nx - 0.5) * 16).floor();
            final gy = ((ny - 0.36) * 12).floor();
            final isEven = ((gx + gy) & 1) == 0;
            final cx = 0.75;
            final cy = 0.68;
            final dx = (nx - cx).abs();
            final dy = (ny - cy).abs();
            if (dx + dy < 0.16) {
              // Diamond target
              r = 245;
              g = 175;
              b = 55;
            } else {
              final v = isEven ? 215 : 50;
              r = v;
              g = v;
              b = v;
            }
          }
        }

        final idx = (y * width + x) << 2;
        pixels[idx] = r;
        pixels[idx + 1] = g;
        pixels[idx + 2] = b;
        pixels[idx + 3] = 255;
      }
    }
    return PixelImage(width: width, height: height, pixels: pixels);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
