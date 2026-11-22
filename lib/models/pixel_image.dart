import 'dart:math' as math;
import 'dart:typed_data';

/// Represents a 2D digital image stored as an RGBA8888 byte buffer.
/// Every pixel at (x, y) occupies 4 bytes at index `(y * width + x) * 4`:
/// [R, G, B, A] each in 0..255.
class PixelImage {
  final int width;
  final int height;
  final Uint8List pixels;
  final int quantizationBits; // k in L = 2^k (default 8)
  final int samplingFactor; // s (default 1)

  const PixelImage({
    required this.width,
    required this.height,
    required this.pixels,
    this.quantizationBits = 8,
    this.samplingFactor = 1,
  });

  /// Effective spatial width after sampling discretization.
  int get effectiveWidth => math.max(1, width ~/ samplingFactor);

  /// Effective spatial height after sampling discretization.
  int get effectiveHeight => math.max(1, height ~/ samplingFactor);

  /// Gray levels L = 2^k.
  int get grayLevels => 1 << quantizationBits;

  /// Image size in bits: M × N × k (using effective spatial resolution).
  int get sizeInBits => effectiveWidth * effectiveHeight * quantizationBits;

  /// Color image size in bits (3 channels): M × N × 3k.
  int get colorSizeInBits => sizeInBits * 3;

  /// Formatted human-readable bit size string (e.g. "2,097,152 bits (256.0 KB)").
  String get formattedBitSize {
    final bits = sizeInBits;
    final bytes = bits / 8.0;
    if (bytes >= 1024 * 1024) {
      return '${_formatNumber(bits)} bits (${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB)';
    } else if (bytes >= 1024) {
      return '${_formatNumber(bits)} bits (${(bytes / 1024).toStringAsFixed(1)} KB)';
    }
    return '$bits bits (${bytes.toStringAsFixed(0)} B)';
  }

  static String _formatNumber(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  PixelImage clone({
    int? quantizationBits,
    int? samplingFactor,
  }) {
    return PixelImage(
      width: width,
      height: height,
      pixels: Uint8List.fromList(pixels),
      quantizationBits: quantizationBits ?? this.quantizationBits,
      samplingFactor: samplingFactor ?? this.samplingFactor,
    );
  }

  int _offset(int x, int y) => (y * width + x) << 2;

  int getRed(int x, int y) => pixels[_offset(x, y)];
  int getGreen(int x, int y) => pixels[_offset(x, y) + 1];
  int getBlue(int x, int y) => pixels[_offset(x, y) + 2];
  int getAlpha(int x, int y) => pixels[_offset(x, y) + 3];

  /// Standard ITU-R BT.601 luminance: Y = 0.299R + 0.587G + 0.114B.
  int getLuminance(int x, int y) {
    final idx = _offset(x, y);
    final r = pixels[idx];
    final g = pixels[idx + 1];
    final b = pixels[idx + 2];
    return ((77 * r + 150 * g + 29 * b) >> 8).clamp(0, 255);
  }

  void setRgba(int x, int y, int r, int g, int b, [int a = 255]) {
    final idx = _offset(x, y);
    pixels[idx] = r.clamp(0, 255);
    pixels[idx + 1] = g.clamp(0, 255);
    pixels[idx + 2] = b.clamp(0, 255);
    pixels[idx + 3] = a.clamp(0, 255);
  }
}

/// Holds 256-bin histogram counts and statistical metrics for an image.
class HistogramData {
  final List<int> red;
  final List<int> green;
  final List<int> blue;
  final List<int> luminance;
  final int totalPixels;
  final int minIntensity;
  final int maxIntensity;
  final double meanIntensity;
  final double stdDevIntensity;
  final int otsuThreshold;

  const HistogramData({
    required this.red,
    required this.green,
    required this.blue,
    required this.luminance,
    required this.totalPixels,
    required this.minIntensity,
    required this.maxIntensity,
    required this.meanIntensity,
    required this.stdDevIntensity,
    required this.otsuThreshold,
  });

  int get dynamicRange => maxIntensity - minIntensity;
}

/// Record of an operation applied in the processing pipeline.
class DipOperationRecord {
  final String title;
  final String category;
  final String formula;
  final int durationMs;

  const DipOperationRecord({
    required this.title,
    required this.category,
    required this.formula,
    required this.durationMs,
  });
}
