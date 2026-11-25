import 'dart:math' as math;
import 'package:dip_studio/models/pixel_image.dart';
import 'package:dip_studio/services/dip_engine.dart';
import 'package:dip_studio/services/sample_image_generator.dart';

void main() {
  print('========================================================================');
  print('           DIP ENGINE EMPIRICAL BENCHMARK & EVALUATION SUITE            ');
  print('========================================================================\n');

  final sizes = [256, 512, 1024];

  for (final sz in sizes) {
    print('--- BENCHMARK FOR RESOLUTION: $sz x $sz (${(sz * sz / 1e6).toStringAsFixed(2)} MP) ---');
    final img = SampleImageGenerator.generate('sunset', size: sz);

    // Warm-up
    DipEngine.toGrayscale(img);

    void measure(String name, void Function() fn) {
      final sw = Stopwatch()..start();
      const iters = 5;
      for (int i = 0; i < iters; i++) {
        fn();
      }
      sw.stop();
      final avgMs = sw.elapsedMicroseconds / (iters * 1000.0);
      final mpPerSec = (sz * sz / 1e6) / (avgMs / 1000.0);
      print('${name.padRight(32)}: ${avgMs.toStringAsFixed(2).padLeft(7)} ms | Throughput: ${mpPerSec.toStringAsFixed(2).padLeft(6)} MP/s');
    }

    measure('Grayscale (BT.601)', () => DipEngine.toGrayscale(img));
    measure('Negative Involution', () => DipEngine.invertNegative(img));
    measure('Log Transform (Gain=1.0)', () => DipEngine.applyLogTransform(img));
    measure('Gamma Transform (γ=0.65)', () => DipEngine.applyGammaTransform(img, gamma: 0.65));
    measure('Contrast Stretch', () => DipEngine.applyContrastStretch(img));
    measure('Histogram Calculation', () => DipEngine.computeHistogram(img));
    measure('Histogram Equalization (RGB)', () => DipEngine.applyHistogramEqualization(img, preserveColor: true));
    measure('Mean Filter (3x3)', () => DipEngine.applyMeanFilter(img, kernelSize: 3));
    measure('Gaussian Filter (3x3, σ=1.2)', () => DipEngine.applyGaussianFilter(img, kernelSize: 3, sigma: 1.2));
    measure('Median Filter (3x3)', () => DipEngine.applyMedianFilter(img, kernelSize: 3));
    measure('Laplacian Sharpen (3x3, 8-N)', () => DipEngine.applyLaplacianFilter(img, eightNeighbor: true, sharpenImage: true));
    measure('Sobel Edge Operator (3x3)', () => DipEngine.applySobelFilter(img));
    measure('Otsu Thresholding (Auto)', () => DipEngine.applyOtsuThreshold(img));
    if (sz <= 512) {
      measure('Canny Edge Detection', () => DipEngine.applyCannyEdgeDetection(img, lowThreshold: 35, highThreshold: 85));
      measure('K-Means Segmentation (K=4)', () => DipEngine.applyKMeansSegmentation(img, k: 4, maxIterations: 5));
      measure('Morphological Erosion (3x3)', () => DipEngine.applyMorphology(img, isDilation: false, kernelSize: 3));
      measure('Morphological Dilation (3x3)', () => DipEngine.applyMorphology(img, isDilation: true, kernelSize: 3));
    }
    measure('Rotate 90 Clockwise', () => DipEngine.rotate90Clockwise(img));
    measure('Horizontal Reflection', () => DipEngine.flipHorizontal(img));
    print('');
  }

  print('--- NOISE RESTORATION & OBJECTIVE QUALITY METRICS (PSNR / MSE) ---');
  final testImg = SampleImageGenerator.generate('coins_cells', size: 256);

  // 1. Salt & Pepper Restoration
  final noisySP = DipEngine.addSaltAndPepperNoise(testImg, density: 0.10);
  final restoredMedian = DipEngine.applyMedianFilter(noisySP, kernelSize: 3);
  final restoredMean = DipEngine.applyMeanFilter(noisySP, kernelSize: 3);

  double computeMse(PixelImage a, PixelImage b) {
    double sum = 0.0;
    final total = a.width * a.height;
    for (int i = 0; i < a.pixels.length; i += 4) {
      final dr = a.pixels[i] - b.pixels[i];
      final dg = a.pixels[i + 1] - b.pixels[i + 1];
      final db = a.pixels[i + 2] - b.pixels[i + 2];
      sum += (dr * dr + dg * dg + db * db) / 3.0;
    }
    return sum / total;
  }

  double computePsnr(double mse) {
    if (mse <= 0.0) return 99.99;
    return 10.0 * (math.log(255.0 * 255.0 / mse) / math.ln10);
  }

  final mseSP = computeMse(testImg, noisySP);
  final psnrSP = computePsnr(mseSP);

  final mseMedian = computeMse(testImg, restoredMedian);
  final psnrMedian = computePsnr(mseMedian);

  final mseMeanSP = computeMse(testImg, restoredMean);
  final psnrMeanSP = computePsnr(mseMeanSP);

  print('Corrupted Salt & Pepper (10%):  MSE = ${mseSP.toStringAsFixed(2)}, PSNR = ${psnrSP.toStringAsFixed(2)} dB');
  print('Restored via Median (3x3):     MSE = ${mseMedian.toStringAsFixed(2)}, PSNR = ${psnrMedian.toStringAsFixed(2)} dB (Δ = +${(psnrMedian - psnrSP).toStringAsFixed(2)} dB)');
  print('Restored via Mean (3x3):       MSE = ${mseMeanSP.toStringAsFixed(2)}, PSNR = ${psnrMeanSP.toStringAsFixed(2)} dB (Δ = +${(psnrMeanSP - psnrSP).toStringAsFixed(2)} dB)');

  // 2. Gaussian Noise Restoration
  final noisyGauss = DipEngine.addGaussianNoise(testImg, sigma: 20.0);
  final restoredGaussBlur = DipEngine.applyGaussianFilter(noisyGauss, kernelSize: 3, sigma: 1.2);
  final restoredGaussMean = DipEngine.applyMeanFilter(noisyGauss, kernelSize: 3);

  final mseGauss = computeMse(testImg, noisyGauss);
  final psnrGauss = computePsnr(mseGauss);

  final mseGBlur = computeMse(testImg, restoredGaussBlur);
  final psnrGBlur = computePsnr(mseGBlur);

  final mseGMean = computeMse(testImg, restoredGaussMean);
  final psnrGMean = computePsnr(mseGMean);

  print('Corrupted Gaussian Noise (σ=20): MSE = ${mseGauss.toStringAsFixed(2)}, PSNR = ${psnrGauss.toStringAsFixed(2)} dB');
  print('Restored via Gaussian Blur:     MSE = ${mseGBlur.toStringAsFixed(2)}, PSNR = ${psnrGBlur.toStringAsFixed(2)} dB (Δ = +${(psnrGBlur - psnrGauss).toStringAsFixed(2)} dB)');
  print('Restored via Arithmetic Mean:   MSE = ${mseGMean.toStringAsFixed(2)}, PSNR = ${psnrGMean.toStringAsFixed(2)} dB (Δ = +${(psnrGMean - psnrGauss).toStringAsFixed(2)} dB)');

  // 3. Dynamic Range Expansion
  final phantom = SampleImageGenerator.generate('low_contrast', size: 256);
  final histBefore = DipEngine.computeHistogram(phantom);
  final equalized = DipEngine.applyHistogramEqualization(phantom, preserveColor: false);
  final histAfter = DipEngine.computeHistogram(equalized);

  print('\n--- DYNAMIC RANGE & CONTRAST EXPANSION ---');
  print('Low-Contrast Phantom Original: Dynamic Range = [${histBefore.minIntensity}..${histBefore.maxIntensity}] (${histBefore.dynamicRange} levels), Std Dev σ = ${histBefore.stdDevIntensity.toStringAsFixed(2)}');
  print('Histogram Equalized Phantom:   Dynamic Range = [${histAfter.minIntensity}..${histAfter.maxIntensity}] (${histAfter.dynamicRange} levels), Std Dev σ = ${histAfter.stdDevIntensity.toStringAsFixed(2)}');
}
