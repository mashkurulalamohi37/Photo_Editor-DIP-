// Renders every experimental figure panel used in the research paper with the
// real DIP Studio engine (lib/services/dip_engine.dart), and records the
// objective metrics quoted in the paper to paper/figures/panels/metrics.json.
//
// Run:  dart run tool/export_paper_figures.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dip_studio/models/pixel_image.dart';
import 'package:dip_studio/services/dip_engine.dart';
import 'package:dip_studio/services/sample_image_generator.dart';

const outDir = 'paper/figures/panels';

// ---------------------------------------------------------------- PNG encoder
final List<int> _crcTable = List<int>.generate(256, (n) {
  int c = n;
  for (int k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  int c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

List<int> _chunk(String type, List<int> data) {
  final typeBytes = ascii.encode(type);
  final len = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc([...typeBytes, ...data]));
  return [
    ...len.buffer.asUint8List(),
    ...typeBytes,
    ...data,
    ...crc.buffer.asUint8List()
  ];
}

void savePng(PixelImage img, String name) {
  final w = img.width, h = img.height;
  final raw = BytesBuilder();
  for (int y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    for (int x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      raw.add([img.pixels[i], img.pixels[i + 1], img.pixels[i + 2]]);
    }
  }
  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8)
    ..setUint8(9, 2) // truecolor RGB
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final png = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ..._chunk('IHDR', ihdr.buffer.asUint8List()),
    ..._chunk('IDAT', ZLibEncoder(level: 9).convert(raw.takeBytes())),
    ..._chunk('IEND', const []),
  ];
  File('$outDir/$name.png').writeAsBytesSync(png);
  stdout.writeln('  panel $name.png (${w}x$h)');
}

// -------------------------------------------------------------------- metrics
double mse(PixelImage a, PixelImage b) {
  double sum = 0;
  for (int i = 0; i < a.pixels.length; i += 4) {
    for (int c = 0; c < 3; c++) {
      final d = a.pixels[i + c] - b.pixels[i + c];
      sum += d * d;
    }
  }
  return sum / (3.0 * a.width * a.height);
}

double psnr(double m) =>
    m <= 0 ? 99.99 : 10.0 * math.log(255.0 * 255.0 / m) / math.ln10;

double r2(double v) => (v * 100).roundToDouble() / 100;

Map<String, dynamic> stats(PixelImage img) {
  final h = DipEngine.computeHistogram(img);
  final occupied = h.luminance.where((c) => c > 0).length;
  return {
    'min': h.minIntensity,
    'max': h.maxIntensity,
    'spread': h.maxIntensity - h.minIntensity,
    'occupiedLevels': occupied,
    'mean': r2(h.meanIntensity),
    'std': r2(h.stdDevIntensity),
    'otsu': h.otsuThreshold,
  };
}

/// Nearest-neighbour re-expansion so down-sampled panels keep the panel size
/// and the blockiness of spatial sampling stays visible.
PixelImage upscaleTo(PixelImage src, int w, int h) {
  final out = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    final sy = (y * src.height) ~/ h;
    for (int x = 0; x < w; x++) {
      final sx = (x * src.width) ~/ w;
      final si = (sy * src.width + sx) * 4, di = (y * w + x) * 4;
      out[di] = src.pixels[si];
      out[di + 1] = src.pixels[si + 1];
      out[di + 2] = src.pixels[si + 2];
      out[di + 3] = 255;
    }
  }
  return PixelImage(width: w, height: h, pixels: out);
}

void main() {
  Directory(outDir).createSync(recursive: true);
  final metrics = <String, dynamic>{};
  const n = 256;

  // ---- Fig. restoration: impulse + Gaussian noise -------------------------
  stdout.writeln('Restoration panels');
  final coins = SampleImageGenerator.generate('coins_cells', size: n);
  final sp = DipEngine.addSaltAndPepperNoise(coins, density: 0.10);
  final spMean = DipEngine.applyMeanFilter(sp, kernelSize: 3);
  final spMedian = DipEngine.applyMedianFilter(sp, kernelSize: 3);
  final gn = DipEngine.addGaussianNoise(coins, sigma: 20.0);
  final gnMean = DipEngine.applyMeanFilter(gn, kernelSize: 3);
  final gnGauss =
      DipEngine.applyGaussianFilter(gn, kernelSize: 3, sigma: 1.2);
  for (final e in {
    'rest_a_clean': coins,
    'rest_b_sp': sp,
    'rest_c_sp_mean': spMean,
    'rest_d_sp_median': spMedian,
    'rest_e_gauss': gn,
    'rest_f_gauss_filtered': gnGauss,
  }.entries) {
    savePng(e.value, e.key);
  }
  Map<String, double> q(PixelImage x) {
    final m = mse(coins, x);
    return {'mse': r2(m), 'psnr': r2(psnr(m))};
  }

  metrics['restoration'] = {
    'sp_noisy': q(sp),
    'sp_mean': q(spMean),
    'sp_median': q(spMedian),
    'gauss_noisy': q(gn),
    'gauss_mean': q(gnMean),
    'gauss_gaussian': q(gnGauss),
  };

  // ---- Fig. enhancement & segmentation ------------------------------------
  stdout.writeln('Enhancement / segmentation panels');
  final phantom = SampleImageGenerator.generate('low_contrast', size: n);
  final equalized =
      DipEngine.applyHistogramEqualization(phantom, preserveColor: false);
  final otsu = DipEngine.applyOtsuThreshold(coins);
  final canny = DipEngine.applyCannyEdgeDetection(coins,
      lowThreshold: 35, highThreshold: 85);
  final sunset = SampleImageGenerator.generate('sunset', size: n);
  final kmeans =
      DipEngine.applyKMeansSegmentation(sunset, k: 4, maxIterations: 10);
  final opened = DipEngine.applyMorphology(
      DipEngine.applyMorphology(otsu.image, isDilation: false, kernelSize: 5),
      isDilation: true,
      kernelSize: 5);
  savePng(phantom, 'seg_a_lowcontrast');
  savePng(equalized, 'seg_b_equalized');
  savePng(otsu.image, 'seg_c_otsu');
  savePng(canny, 'seg_d_canny');
  savePng(sunset, 'seg_e_sunset');
  savePng(kmeans, 'seg_f_kmeans');
  savePng(opened, 'seg_g_opening');

  int edgePixels = 0;
  for (int i = 0; i < canny.pixels.length; i += 4) {
    if (canny.pixels[i] > 127) edgePixels++;
  }
  metrics['contrast'] = {'before': stats(phantom), 'after': stats(equalized)};
  metrics['segmentation'] = {
    'otsu_threshold': otsu.threshold,
    'canny_edge_pixel_ratio': r2(100.0 * edgePixels / (n * n)),
  };

  // ---- Fig. digitization: sampling & quantization -------------------------
  stdout.writeln('Digitization panels');
  final chart = SampleImageGenerator.generate('sunset', size: n);
  final digit = <String, List<int>>{
    'dig_a_s1_k8': [1, 8],
    'dig_b_s8_k8': [8, 8],
    'dig_c_s1_k3': [1, 3],
    'dig_d_s1_k1': [1, 1],
  };
  final digMetrics = <String, dynamic>{};
  digit.forEach((name, p) {
    final d = DipEngine.applyDigitization(chart,
        samplingFactor: p[0], quantizationBits: p[1]);
    final shown = (d.width == n && d.height == n) ? d : upscaleTo(d, n, n);
    savePng(shown, name);
    digMetrics[name] = {
      'S': p[0],
      'k': p[1],
      'bits': d.sizeInBits,
      'psnr': r2(psnr(mse(chart, shown))),
    };
  });
  metrics['digitization'] = digMetrics;

  File('$outDir/metrics.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metrics));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(metrics));
}
