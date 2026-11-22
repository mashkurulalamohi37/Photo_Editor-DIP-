import 'package:dip_studio/main.dart';
import 'package:dip_studio/services/dip_engine.dart';
import 'package:dip_studio/services/sample_image_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DipEngine Core Algorithms', () {
    test('Digitization calculates M × N × k bit size & quantizes gray levels', () {
      final base = SampleImageGenerator.generate('test_card', size: 128);
      expect(base.sizeInBits, 128 * 128 * 8);

      final quantized = DipEngine.applyDigitization(
        base,
        samplingFactor: 2,
        quantizationBits: 2, // L = 4 levels
      );
      expect(quantized.effectiveWidth, 64);
      expect(quantized.effectiveHeight, 64);
      expect(quantized.grayLevels, 4);
      expect(quantized.sizeInBits, 64 * 64 * 2);
    });

    test('Histogram Equalization expands dynamic range of Low-Contrast Phantom', () {
      final lowContrast = SampleImageGenerator.generate('low_contrast', size: 100);
      final beforeHist = DipEngine.computeHistogram(lowContrast);
      expect(beforeHist.dynamicRange, lessThan(100));

      final equalized = DipEngine.applyHistogramEqualization(
        lowContrast,
        preserveColor: false,
      );
      final afterHist = DipEngine.computeHistogram(equalized);
      expect(afterHist.dynamicRange, greaterThan(200));
    });

    test('Salt & Pepper noise and Median Filter restoration work accurately', () {
      final clean = SampleImageGenerator.generate('coins_cells', size: 80);
      final noisy = DipEngine.addSaltAndPepperNoise(clean, density: 0.12);
      final restored = DipEngine.applyMedianFilter(noisy, kernelSize: 3);

      expect(restored.width, clean.width);
      expect(restored.height, clean.height);
    });

    test('Otsu Thresholding, Sobel, Canny, and K-Means Segmentation execute cleanly', () {
      final img = SampleImageGenerator.generate('coins_cells', size: 80);
      final otsuResult = DipEngine.applyOtsuThreshold(img);
      expect(otsuResult.threshold, inInclusiveRange(20, 230));
      expect(otsuResult.image.quantizationBits, 1);

      final sobel = DipEngine.applySobelFilter(img);
      expect(sobel.width, 80);

      final canny = DipEngine.applyCannyEdgeDetection(img);
      expect(canny.quantizationBits, 1);

      final kmeans = DipEngine.applyKMeansSegmentation(img, k: 3, maxIterations: 5);
      expect(kmeans.width, 80);
    });
  });

  testWidgets('DIP Studio app renders tabs and sample presets', (WidgetTester tester) async {
    await tester.pumpWidget(const DipStudioApp());
    expect(find.text('DIP Studio'), findsOneWidget);
    expect(find.text('Mountain Sunset'), findsOneWidget);
    expect(find.text('Low-Contrast Phantom'), findsOneWidget);
    expect(find.text('Enhance'), findsOneWidget);
    expect(find.text('Filters & Noise'), findsOneWidget);
    expect(find.text('Segment'), findsOneWidget);
    expect(find.text('Digitize'), findsOneWidget);
    expect(find.text('Inspector'), findsOneWidget);
  });
}
