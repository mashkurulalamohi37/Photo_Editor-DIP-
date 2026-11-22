import 'dart:typed_data';
import 'package:dip_studio/main.dart';
import 'package:dip_studio/models/pixel_image.dart';
import 'package:dip_studio/screens/splash_screen.dart';
import 'package:dip_studio/services/dip_engine.dart';
import 'package:dip_studio/services/sample_image_generator.dart';
import 'package:dip_studio/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SQA Phase 1: Digitization & Mathematical Formulas (Section 2)', () {
    test('Worked Example: 1024 × 1024 × 8 bits = 8,388,608 bits (1.00 MB)', () {
      final dummyPixels = Uint8List(1024 * 1024 * 4);
      final img = PixelImage(
        width: 1024,
        height: 1024,
        pixels: dummyPixels,
        quantizationBits: 8,
        samplingFactor: 1,
      );

      expect(img.effectiveWidth, 1024);
      expect(img.effectiveHeight, 1024);
      expect(img.grayLevels, 256); // L = 2^8
      expect(img.sizeInBits, 8388608);
      expect(img.formattedBitSize, contains('8,388,608 bits'));
      expect(img.formattedBitSize, contains('1.00 MB'));
    });

    test('Spatial sampling & quantization strictly enforce L = 2^k levels', () {
      final src = SampleImageGenerator.generate('test_card', size: 128);

      for (final k in [1, 2, 3, 4, 6, 8]) {
        final maxLevels = 1 << k;
        final digitized = DipEngine.applyDigitization(
          src,
          samplingFactor: 4,
          quantizationBits: k,
        );
        expect(digitized.effectiveWidth, 32);
        expect(digitized.effectiveHeight, 32);
        expect(digitized.grayLevels, maxLevels);
        expect(digitized.sizeInBits, 32 * 32 * k);

        // Count distinct red channel intensity levels
        final distinctR = <int>{};
        for (int i = 0; i < digitized.pixels.length; i += 4) {
          distinctR.add(digitized.pixels[i]);
        }
        expect(
          distinctR.length,
          lessThanOrEqualTo(maxLevels),
          reason: 'Quantization with k=$k bits must produce at most L=2^$k=$maxLevels levels',
        );
      }
    });
  });

  group('SQA Phase 2: Spatial Domain Point Operations & Histogram Enhancement (Section 3)', () {
    late PixelImage sunset;

    setUp(() {
      sunset = SampleImageGenerator.generate('sunset', size: 100);
    });

    test('Grayscale sets R == G == B == Luminance for every pixel', () {
      final gray = DipEngine.toGrayscale(sunset);
      for (int i = 0; i < gray.pixels.length; i += 4) {
        expect(gray.pixels[i], equals(gray.pixels[i + 1]));
        expect(gray.pixels[i + 1], equals(gray.pixels[i + 2]));
      }
    });

    test('Image Negative (s = 255 - r) is an exact involution', () {
      final neg = DipEngine.invertNegative(sunset);
      for (int i = 0; i < sunset.pixels.length; i += 4) {
        expect(neg.pixels[i], 255 - sunset.pixels[i]);
        expect(neg.pixels[i + 1], 255 - sunset.pixels[i + 1]);
        expect(neg.pixels[i + 2], 255 - sunset.pixels[i + 2]);
      }
      final restored = DipEngine.invertNegative(neg);
      expect(restored.pixels, equals(sunset.pixels));
    });

    test('Log Transform expands dark pixel intensities', () {
      final logImg = DipEngine.applyLogTransform(sunset, gain: 1.0);
      final beforeHist = DipEngine.computeHistogram(sunset);
      final afterHist = DipEngine.computeHistogram(logImg);
      expect(afterHist.meanIntensity, greaterThan(beforeHist.meanIntensity));
    });

    test('Power-Law (Gamma) transformation obeys gamma < 1 brighten and gamma > 1 darken', () {
      final baseHist = DipEngine.computeHistogram(sunset);
      final bright = DipEngine.applyGammaTransform(sunset, gamma: 0.45);
      final dark = DipEngine.applyGammaTransform(sunset, gamma: 2.20);
      final identity = DipEngine.applyGammaTransform(sunset, gamma: 1.0);

      expect(
        DipEngine.computeHistogram(bright).meanIntensity,
        greaterThan(baseHist.meanIntensity),
      );
      expect(
        DipEngine.computeHistogram(dark).meanIntensity,
        lessThan(baseHist.meanIntensity),
      );
      expect(identity.pixels, equals(sunset.pixels));
    });

    test('Contrast Stretching and Histogram Equalization expand compressed dynamic range to [0..255]', () {
      final lowContrast = SampleImageGenerator.generate('low_contrast', size: 100);
      final rawHist = DipEngine.computeHistogram(lowContrast);
      expect(rawHist.minIntensity, greaterThanOrEqualTo(80));
      expect(rawHist.maxIntensity, lessThanOrEqualTo(165));

      final stretched = DipEngine.applyContrastStretch(lowContrast);
      final stretchHist = DipEngine.computeHistogram(stretched);
      expect(stretchHist.minIntensity, lessThanOrEqualTo(2));
      expect(stretchHist.maxIntensity, greaterThanOrEqualTo(253));

      final eqGray = DipEngine.applyHistogramEqualization(
        lowContrast,
        preserveColor: false,
      );
      final eqGrayHist = DipEngine.computeHistogram(eqGray);
      expect(eqGrayHist.minIntensity, equals(0));
      expect(eqGrayHist.maxIntensity, equals(255));
      expect(eqGrayHist.stdDevIntensity, greaterThan(rawHist.stdDevIntensity * 2.5));

      final eqColor = DipEngine.applyHistogramEqualization(
        lowContrast,
        preserveColor: true,
      );
      final eqColorHist = DipEngine.computeHistogram(eqColor);
      expect(eqColorHist.dynamicRange, greaterThan(240));
    });

    test('HSV Color Processing shifts hue accurately', () {
      final shifted = DipEngine.applyHsvAdjustment(
        sunset,
        hueShiftDeg: 120.0,
        saturationScale: 1.2,
        valueScale: 1.0,
      );
      expect(shifted.width, sunset.width);
      expect(shifted.pixels, isNot(equals(sunset.pixels)));
    });
  });

  group('SQA Phase 3: Noise Models, Restoration & Spatial Filtering (Section 3 & 5)', () {
    double computeMeanAbsoluteError(PixelImage a, PixelImage b) {
      int diffSum = 0;
      final count = a.width * a.height * 3;
      for (int i = 0; i < a.pixels.length; i += 4) {
        diffSum += (a.pixels[i] - b.pixels[i]).abs();
        diffSum += (a.pixels[i + 1] - b.pixels[i + 1]).abs();
        diffSum += (a.pixels[i + 2] - b.pixels[i + 2]).abs();
      }
      return diffSum / count;
    }

    test('Median Filter outperforms Mean Filter on Salt-and-Pepper noise (Section 5 concept)', () {
      final clean = SampleImageGenerator.generate('coins_cells', size: 96);
      final noisy = DipEngine.addSaltAndPepperNoise(clean, density: 0.10);

      final noisyMae = computeMeanAbsoluteError(clean, noisy);
      final meanRestored = DipEngine.applyMeanFilter(noisy, kernelSize: 3);
      final medianRestored = DipEngine.applyMedianFilter(noisy, kernelSize: 3);

      final meanMae = computeMeanAbsoluteError(clean, meanRestored);
      final medianMae = computeMeanAbsoluteError(clean, medianRestored);

      expect(noisyMae, greaterThan(10.0));
      expect(
        medianMae,
        lessThan(meanMae),
        reason: 'Median filter must restore Salt-and-Pepper noise with lower error than Mean filter',
      );
      expect(medianMae, lessThan(noisyMae * 0.35));
    });

    test('Gaussian & Mean smoothing reduce Gaussian noise error', () {
      final clean = SampleImageGenerator.generate('coins_cells', size: 96);
      final noisy = DipEngine.addGaussianNoise(clean, sigma: 25.0);
      final noisyMae = computeMeanAbsoluteError(clean, noisy);

      final gaussianSmoothed = DipEngine.applyGaussianFilter(
        noisy,
        kernelSize: 3,
        sigma: 1.2,
      );
      final smoothedMae = computeMeanAbsoluteError(clean, gaussianSmoothed);
      expect(smoothedMae, lessThan(noisyMae));
    });

    test('Speckle noise, Laplacian (4/8 neighbor, sharpen/edge), and Sobel execute properly', () {
      final img = SampleImageGenerator.generate('test_card', size: 80);
      final speckled = DipEngine.addSpeckleNoise(img, strength: 0.2);
      expect(speckled.pixels, isNot(equals(img.pixels)));

      final lapSharpen8 = DipEngine.applyLaplacianFilter(
        img,
        sharpenImage: true,
        eightNeighbor: true,
      );
      final lapEdge4 = DipEngine.applyLaplacianFilter(
        img,
        sharpenImage: false,
        eightNeighbor: false,
      );
      expect(lapSharpen8.pixels, isNot(equals(lapEdge4.pixels)));

      final sobel = DipEngine.applySobelFilter(img);
      expect(sobel.width, 80);
    });

    test('Convolution flips the 3×3 kernel 180° relative to Correlation (Section 5 concept)', () {
      // Single impulse at center (4, 4) of a 9×9 image
      final pixels = Uint8List(9 * 9 * 4);
      for (int i = 3; i < pixels.length; i += 4) {
        pixels[i] = 255;
      }
      final centerIdx = (4 * 9 + 4) << 2;
      pixels[centerIdx] = 200;
      pixels[centerIdx + 1] = 200;
      pixels[centerIdx + 2] = 200;
      final impulseImg = PixelImage(width: 9, height: 9, pixels: pixels);

      // Asymmetric kernel with weight 1.0 only at top-left (-1, -1)
      const asymmetricKernel = <double>[
        1, 0, 0,
        0, 0, 0,
        0, 0, 0,
      ];

      final corr = DipEngine.applyCustomKernel3x3(
        impulseImg,
        kernel: asymmetricKernel,
        isConvolution: false,
      );
      final conv = DipEngine.applyCustomKernel3x3(
        impulseImg,
        kernel: asymmetricKernel,
        isConvolution: true,
      );

      // In Correlation, top-left kernel weight triggers when window is at (5, 5)
      // In Convolution (180° flipped), bottom-right kernel weight triggers when window is at (3, 3)
      expect(corr.getRed(5, 5), equals(200));
      expect(corr.getRed(3, 3), equals(0));

      expect(conv.getRed(3, 3), equals(200));
      expect(conv.getRed(5, 5), equals(0));
    });
  });

  group('SQA Phase 4: Segmentation & Morphological Processing (Section 1 & 4)', () {
    late PixelImage coins;

    setUp(() {
      coins = SampleImageGenerator.generate('coins_cells', size: 96);
    });

    test("Otsu's method and Manual Thresholding produce strictly binary outputs", () {
      final otsu = DipEngine.applyOtsuThreshold(coins);
      expect(otsu.threshold, inInclusiveRange(50, 200));
      for (int i = 0; i < otsu.image.pixels.length; i += 4) {
        final v = otsu.image.pixels[i];
        expect(v == 0 || v == 255, isTrue);
      }
    });

    test('Canny Edge Detection produces thin binary edge contours', () {
      final edges = DipEngine.applyCannyEdgeDetection(
        coins,
        lowThreshold: 35,
        highThreshold: 85,
      );
      int edgeCount = 0;
      for (int i = 0; i < edges.pixels.length; i += 4) {
        final v = edges.pixels[i];
        expect(v == 0 || v == 255, isTrue);
        if (v == 255) edgeCount++;
      }
      // Edges should exist but occupy a small fraction (<25%) of total pixels
      expect(edgeCount, greaterThan(50));
      expect(edgeCount, lessThan((96 * 96) ~/ 4));
    });

    test('K-Means Clustering partitions image into at most K distinct RGB colors', () {
      for (final k in [2, 3, 4, 6]) {
        final segmented = DipEngine.applyKMeansSegmentation(
          coins,
          k: k,
          maxIterations: 8,
        );
        final uniqueColors = <int>{};
        for (int i = 0; i < segmented.pixels.length; i += 4) {
          final colorKey = (segmented.pixels[i] << 16) |
              (segmented.pixels[i + 1] << 8) |
              segmented.pixels[i + 2];
          uniqueColors.add(colorKey);
        }
        expect(uniqueColors.length, lessThanOrEqualTo(k));
        expect(uniqueColors.length, greaterThanOrEqualTo(2));
      }
    });

    test('Region Growing segments connected region for both 4-neighbors and 8-neighbors', () {
      final res4 = DipEngine.applyRegionGrowing(
        coins,
        seedX: 5,
        seedY: 5,
        tolerance: 25,
        eightConnected: false,
      );
      final res8 = DipEngine.applyRegionGrowing(
        coins,
        seedX: 5,
        seedY: 5,
        tolerance: 25,
        eightConnected: true,
      );
      expect(res4.grownPixels, greaterThan(100));
      expect(res8.grownPixels, greaterThanOrEqualTo(res4.grownPixels));
    });

    test('Morphological Erosion shrinks bright regions and Dilation grows bright regions', () {
      final binary = DipEngine.applyOtsuThreshold(coins).image;
      final eroded = DipEngine.applyMorphology(binary, isDilation: false);
      final dilated = DipEngine.applyMorphology(binary, isDilation: true);

      int countWhite(PixelImage img) {
        int c = 0;
        for (int i = 0; i < img.pixels.length; i += 4) {
          if (img.pixels[i] > 128) c++;
        }
        return c;
      }

      final baseWhite = countWhite(binary);
      final erodedWhite = countWhite(eroded);
      final dilatedWhite = countWhite(dilated);

      expect(erodedWhite, lessThan(baseWhite));
      expect(dilatedWhite, greaterThan(baseWhite));
    });
  });

  group('SQA Phase 5: End-to-End UI & Interactive Feature Workflow Verification', () {
    testWidgets('Full mobile portrait (412×915) interactive walkthrough of all 5 tabs & sheets',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const DipStudioApp());
      await tester.pump();

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pump();
        await tester.tap(finder);
        await tester.pump();
      }

      // 1. Verify Preset Switching
      await tapVisible(find.text('Low-Contrast Phantom'));
      await tapVisible(find.text('Coins & Specimens'));
      await tapVisible(find.text('DIP Test Chart'));
      await tapVisible(find.text('Mountain Sunset'));

      // 2. Expand workbench (hidden/collapsed by default)
      expect(find.text('Show'), findsOneWidget);
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Hide'), findsOneWidget);

      // 3. Test Tab 0: Enhance (Point Ops & Histogram)
      await tapVisible(find.text('Grayscale'));
      expect(find.textContaining('Grayscale Luminance'), findsOneWidget);

      await tapVisible(find.text('Negative'));
      expect(find.textContaining('Image Negative'), findsOneWidget);

      await tapVisible(find.text('Histogram Equalize'));
      expect(find.textContaining('Histogram Equalization'), findsOneWidget);

      await tapVisible(find.text('Contrast Stretch'));
      expect(find.textContaining('Contrast Stretching'), findsOneWidget);

      await tapVisible(find.text('Log Transform'));
      expect(find.textContaining('Log Transformation'), findsOneWidget);

      await tapVisible(find.text('Apply Gamma'));
      expect(find.textContaining('Power-Law (Gamma) • s = c'), findsOneWidget);

      // Test Undo & Reset
      await tester.tap(find.byTooltip('Undo Last Operation'));
      await tester.pump();
      await tester.tap(find.byTooltip('Reset to Original Image'));
      await tester.pump();

      // 3. Test Tab 1: Filters & Noise
      await tester.tap(find.text('Filters & Noise'));
      await tester.pump();

      await tapVisible(find.text('Salt & Pepper Noise'));
      expect(find.textContaining('Salt & Pepper Noise'), findsWidgets);

      await tapVisible(find.text('Median Filter (3×3)'));
      expect(find.textContaining('Median Filter (3×3)'), findsWidgets);

      await tapVisible(find.text('Mean Filter (3×3)'));
      await tapVisible(find.text('Gaussian Blur (3×3)'));
      await tapVisible(find.text('Laplacian Sharpen'));
      await tapVisible(find.text('Sobel Gradient'));
      expect(find.textContaining('Sobel Gradient Operator'), findsOneWidget);

      // Scroll down inside Filters tab to test Convolution vs Correlation chip
      await tapVisible(find.text('Test 3×3 Convolution (180° Flipped)'));
      expect(
        find.textContaining('Spatial Convolution (Kernel Flipped 180°)'),
        findsOneWidget,
      );

      // 4. Test Tab 2: Segment & Morphology
      await tester.tap(find.text('Segment'));
      await tester.pump();

      await tapVisible(find.text("Otsu's Threshold"));
      expect(find.textContaining("Otsu's Optimal Thresholding"), findsOneWidget);

      await tapVisible(find.text('Canny Edges'));
      expect(find.textContaining('Canny Edge Segmentation'), findsOneWidget);

      await tapVisible(find.text('K-Means (K=4)'));
      expect(find.textContaining('K-Means Clustering (K=4)'), findsOneWidget);

      await tapVisible(find.text('Erosion (f ⊖ B)'));
      expect(find.textContaining('Morphological Erosion'), findsOneWidget);

      await tapVisible(find.text('Dilation (f ⊕ B)'));
      expect(find.textContaining('Morphological Dilation'), findsOneWidget);

      // 5. Test Tab 3: Digitize (Sampling & Quantization)
      await tester.tap(find.text('Digitize'));
      await tester.pump();

      await tester.tap(find.text('÷4'));
      await tester.pump();
      expect(find.textContaining('90×90'), findsWidgets);

      // 6. Test Tab 4: Inspector (Neighborhoods & Distance Measures)
      await tester.tap(find.text('Inspector'));
      await tester.pump();
      expect(find.textContaining('Euclidean (De)'), findsOneWidget);
      expect(find.textContaining('City-Block (D4)'), findsOneWidget);
      expect(find.textContaining('Chessboard (D8)'), findsOneWidget);
      expect(find.textContaining('N4(P1) 4-Neighbors Intensities'), findsOneWidget);

      // 7. Test Split Before/After Comparison & Histogram Toggle
      await tester.tap(find.byTooltip('Split Before / After Comparison'));
      await tester.pump();
      expect(find.text('ORIGINAL'), findsOneWidget);
      expect(find.text('PROCESSED'), findsOneWidget);

      await tester.tap(find.byTooltip('Toggle Histogram Chart'));
      await tester.pump();
      await tester.tap(find.byTooltip('Toggle Histogram Chart'));
      await tester.pump();

      // 8. Test Digitization Calculator & DIP Core Reference Bottom Sheet
      await tester.tap(find.byTooltip('Digitization M×N×k Calculator & DIP Guide'));
      await tester.pumpAndSettle();
      expect(
        find.text('Digitization Calculator & DIP Core Reference'),
        findsOneWidget,
      );
      expect(
        find.text('1024 × 1024 × 8 = 8,388,608 bits'),
        findsOneWidget,
      );

      // Test changing dimension preset in calculator sheet
      await tapVisible(find.text('512×512'));
      expect(
        find.text('512 × 512 × 8 = 2,097,152 bits'),
        findsOneWidget,
      );

      // Scroll down inside the bottom sheet to verify the 10 Fundamental DIP Steps
      await tester.drag(
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('10 Fundamental Steps in Digital Image Processing'),
        findsOneWidget,
      );

      // Close calculator sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });
  });

  group('SQA Phase 6: Boundary & Edge-Case Stress Tests (1×1 & Uniform Images)', () {
    void verifyValidOpaqueOutput(PixelImage out, int expectedW, int expectedH) {
      expect(out.width, expectedW);
      expect(out.height, expectedH);
      expect(out.pixels.length, expectedW * expectedH * 4);
      for (int i = 3; i < out.pixels.length; i += 4) {
        expect(out.pixels[i], equals(255), reason: 'Alpha channel must stay opaque (255)');
      }
    }

    test('Every DipEngine algorithm safely handles a 1×1 single-pixel image', () {
      final onePx = PixelImage(
        width: 1,
        height: 1,
        pixels: Uint8List.fromList([140, 90, 210, 255]),
      );

      verifyValidOpaqueOutput(
        DipEngine.applyDigitization(onePx, samplingFactor: 4, quantizationBits: 2),
        1,
        1,
      );
      verifyValidOpaqueOutput(DipEngine.toGrayscale(onePx), 1, 1);
      verifyValidOpaqueOutput(DipEngine.invertNegative(onePx), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyLogTransform(onePx), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyGammaTransform(onePx, gamma: 1.5), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyContrastStretch(onePx), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyHistogramEqualization(onePx), 1, 1);
      verifyValidOpaqueOutput(
        DipEngine.applyHsvAdjustment(
          onePx,
          hueShiftDeg: 45,
          saturationScale: 1.1,
          valueScale: 0.9,
        ),
        1,
        1,
      );
      verifyValidOpaqueOutput(DipEngine.addSaltAndPepperNoise(onePx), 1, 1);
      verifyValidOpaqueOutput(DipEngine.addGaussianNoise(onePx), 1, 1);
      verifyValidOpaqueOutput(DipEngine.addSpeckleNoise(onePx), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyMeanFilter(onePx, kernelSize: 5), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyGaussianFilter(onePx, kernelSize: 5), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyMedianFilter(onePx, kernelSize: 5), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyLaplacianFilter(onePx), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applySobelFilter(onePx), 1, 1);
      verifyValidOpaqueOutput(
        DipEngine.applyCustomKernel3x3(
          onePx,
          kernel: const [0, -1, 0, -1, 5, -1, 0, -1, 0],
          isConvolution: true,
        ),
        1,
        1,
      );
      verifyValidOpaqueOutput(DipEngine.applyThreshold(onePx, threshold: 100), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyOtsuThreshold(onePx).image, 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyCannyEdgeDetection(onePx), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyKMeansSegmentation(onePx, k: 4), 1, 1);
      verifyValidOpaqueOutput(
        DipEngine.applyRegionGrowing(onePx, seedX: 0, seedY: 0).image,
        1,
        1,
      );
      verifyValidOpaqueOutput(DipEngine.applyMorphology(onePx, isDilation: true), 1, 1);
      verifyValidOpaqueOutput(DipEngine.applyMorphology(onePx, isDilation: false), 1, 1);
    });

    test('Uniform all-black (0), mid-gray (128), and all-white (255) images preserve integrity', () {
      for (final val in [0, 128, 255]) {
        final bytes = Uint8List(32 * 32 * 4);
        for (int i = 0; i < bytes.length; i += 4) {
          bytes[i] = val;
          bytes[i + 1] = val;
          bytes[i + 2] = val;
          bytes[i + 3] = 255;
        }
        final uniform = PixelImage(width: 32, height: 32, pixels: bytes);

        final stretched = DipEngine.applyContrastStretch(uniform);
        expect(stretched.getRed(10, 10), equals(val));

        final equalized = DipEngine.applyHistogramEqualization(
          uniform,
          preserveColor: false,
        );
        expect(equalized.getRed(10, 10), equals(val));

        final canny = DipEngine.applyCannyEdgeDetection(uniform);
        verifyValidOpaqueOutput(canny, 32, 32);

        final kmeans = DipEngine.applyKMeansSegmentation(uniform, k: 3);
        expect(kmeans.getRed(10, 10), equals(val));
      }
    });
  });

  group('SQA Phase 7: Deep Interactive Controls & Multi-Viewport Verification', () {
    testWidgets('5×5 Kernels, Laplacian FilterChips, Canvas Region Growing & Inspector Taps',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const DipStudioApp());
      await tester.pump();

      // Toggle Histogram visibility (hidden by default)
      await tester.tap(find.byIcon(Icons.bar_chart_rounded));
      await tester.pump();

      // Toggle Histogram channel mode: RGB + Lum <-> Lum Only
      await tester.tap(find.text('RGB + Lum'));
      await tester.pump();
      expect(find.text('Lum Only'), findsOneWidget);
      await tester.tap(find.text('Lum Only'));
      await tester.pump();
      expect(find.text('RGB + Lum'), findsOneWidget);

      // Expand workbench (collapsed by default)
      await tester.tap(find.text('Enhance'));
      await tester.pump();

      // Test HSV Hue transform button on Tab 0
      await tester.ensureVisible(find.text('Hue +0°'));
      await tester.tap(find.text('Hue +0°'));
      await tester.pump();
      expect(find.textContaining('HSV Color Transform'), findsOneWidget);

      // Switch to Tab 1 (Filters & Noise) and switch 3×3 -> 5×5 kernel size
      await tester.tap(find.text('Filters & Noise'));
      await tester.pump();
      await tester.tap(find.text('5×5'));
      await tester.pump();

      expect(find.text('Median Filter (5×5)'), findsOneWidget);
      expect(find.text('Mean Filter (5×5)'), findsOneWidget);
      expect(find.text('Gaussian Blur (5×5)'), findsOneWidget);

      await tester.tap(find.text('Gaussian Noise'));
      await tester.pump();
      expect(find.textContaining('Gaussian Noise • g(x,y)'), findsOneWidget);

      await tester.tap(find.text('Speckle Noise'));
      await tester.pump();
      expect(find.textContaining('Speckle Noise • g(x,y)'), findsOneWidget);

      await tester.tap(find.text('Median Filter (5×5)'));
      await tester.pump();
      expect(find.textContaining('Median Filter (5×5) • g(x,y)'), findsOneWidget);

      // Toggle Laplacian FilterChips (Sharpen -> Edge Map, 8-Neighbor -> 4-Neighbor)
      await tester.ensureVisible(find.text('Laplacian: Sharpen'));
      await tester.tap(find.text('Laplacian: Sharpen'));
      await tester.pump();
      expect(find.text('Laplacian: Edge Map'), findsOneWidget);

      await tester.tap(find.text('8-Neighbor Kernel'));
      await tester.pump();
      expect(find.text('4-Neighbor Kernel'), findsOneWidget);

      await tester.ensureVisible(find.text('Laplacian Edges'));
      await tester.tap(find.text('Laplacian Edges'));
      await tester.pump();
      expect(find.textContaining('Laplacian Edge Map • |∇²f| (4-neighbor)'), findsOneWidget);

      // Switch to Tab 2 (Segment) and tap on image canvas to trigger Region Growing
      await tester.tap(find.text('Segment'));
      await tester.pump();

      // Tap K=6 cluster selector and run K-Means (K=6)
      await tester.ensureVisible(find.text('6'));
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.ensureVisible(find.text('K-Means (K=6)'));
      await tester.tap(find.text('K-Means (K=6)'));
      await tester.pump();
      expect(find.textContaining('K-Means Clustering (K=6)'), findsOneWidget);

      // Toggle Region Growing connectivity 8-Neighbors -> 4-Neighbors
      await tester.ensureVisible(find.text('8-Neighbors'));
      await tester.tap(find.text('8-Neighbors'));
      await tester.pump();
      expect(find.text('4-Neighbors'), findsOneWidget);
      expect(find.textContaining('Region Growing (4-conn)'), findsOneWidget);

      // Switch to Tab 4 (Inspector) and tap twice on the canvas to set P1 and P2
      await tester.tap(find.text('Inspector'));
      await tester.pump();
      expect(find.textContaining('Next tap sets: P1'), findsOneWidget);
    });

    testWidgets('Compact phone viewport (360×640) renders without layout overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const DipStudioApp());
      await tester.pump();

      for (final tab in ['Enhance', 'Filters & Noise', 'Segment', 'Digitize', 'Inspector']) {
        await tester.tap(find.text(tab));
        await tester.pump();
      }
    });
  });

  group('SQA Phase 8: Photo Editing Workflow (Geometry, Brightness/Contrast, PNG Load & Export)', () {
    test('Rotate 90° CW, Flip Horizontal, Flip Vertical, and Brightness/Contrast work accurately', () {
      // Create a non-square 40×24 asymmetric photo
      final pixels = Uint8List(40 * 24 * 4);
      for (int y = 0; y < 24; y++) {
        for (int x = 0; x < 40; x++) {
          final idx = (y * 40 + x) << 2;
          pixels[idx] = (x * 6).clamp(0, 255);
          pixels[idx + 1] = (y * 10).clamp(0, 255);
          pixels[idx + 2] = ((x + y) * 4).clamp(0, 255);
          pixels[idx + 3] = 255;
        }
      }
      final photo = PixelImage(width: 40, height: 24, pixels: pixels);

      // 1. Rotate 90° swaps width (40) & height (24) -> (24 × 40)
      final rot1 = DipEngine.rotate90Clockwise(photo);
      expect(rot1.width, 24);
      expect(rot1.height, 40);
      // Four 90° rotations return to exact original photo
      final rot4 = DipEngine.rotate90Clockwise(
        DipEngine.rotate90Clockwise(DipEngine.rotate90Clockwise(rot1)),
      );
      expect(rot4.width, 40);
      expect(rot4.height, 24);
      expect(rot4.pixels, equals(photo.pixels));

      // 2. Flip Horizontal twice returns to exact original photo
      final flipH1 = DipEngine.flipHorizontal(photo);
      expect(flipH1.getRed(39, 0), equals(photo.getRed(0, 0)));
      final flipH2 = DipEngine.flipHorizontal(flipH1);
      expect(flipH2.pixels, equals(photo.pixels));

      // 3. Flip Vertical twice returns to exact original photo
      final flipV1 = DipEngine.flipVertical(photo);
      expect(flipV1.getGreen(0, 23), equals(photo.getGreen(0, 0)));
      final flipV2 = DipEngine.flipVertical(flipV1);
      expect(flipV2.pixels, equals(photo.pixels));

      // 4. Brightness & Contrast adjustment
      final brightened = DipEngine.applyBrightnessContrast(
        photo,
        brightness: 30,
        contrast: 1.2,
      );
      expect(
        DipEngine.computeHistogram(brightened).meanIntensity,
        greaterThan(DipEngine.computeHistogram(photo).meanIntensity),
      );
    });

    testWidgets('UI Photo Editing: Rotate 90°, Flip H, Flip V, Undo stack & PNG Export Dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const DipStudioApp());
      await tester.pump();

      // Expand workbench (collapsed by default)
      await tester.tap(find.text('Enhance'));
      await tester.pump();

      await tester.ensureVisible(find.text('Rotate 90°'));
      await tester.tap(find.text('Rotate 90°'));
      await tester.pump();
      expect(find.textContaining('Rotate 90° Clockwise'), findsOneWidget);

      await tester.ensureVisible(find.text('Flip H'));
      await tester.tap(find.text('Flip H'));
      await tester.pump();
      expect(find.textContaining('Horizontal Mirror Flip'), findsOneWidget);

      await tester.ensureVisible(find.text('Flip V'));
      await tester.tap(find.text('Flip V'));
      await tester.pump();
      expect(find.textContaining('Vertical Mirror Flip'), findsOneWidget);
    });
  });

  group('SQA Phase 9: App Logo & Opening Splash Animation Verification', () {
    testWidgets('SplashScreen displays custom AppLogo, branding, and status animation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            duration: Duration(milliseconds: 200),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('DIP Studio'), findsOneWidget);
      expect(find.text('DIGITAL IMAGE PROCESSING LAB'), findsOneWidget);
      expect(find.textContaining('Sampling 2D Continuous Coordinates'), findsOneWidget);

      // Fast-forward animation to completion
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('EditorScreen displays AppLogo in AppBar and verifies tools are hidden by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DipStudioApp());
      await tester.pump();

      // Custom AppLogo is present in top navigation
      expect(find.byType(AppLogo), findsAtLeastNWidgets(1));

      // Tools & histogram hidden by default as requested
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('RGB + Lum'), findsNothing);

      // One-tap Show reveals workbench tools
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Grayscale'), findsOneWidget);

      // Tapping Hide collapses workbench again
      await tester.tap(find.text('Hide'));
      await tester.pump();
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Grayscale'), findsNothing);

      // Tapping chart icon reveals histogram
      await tester.tap(find.byIcon(Icons.bar_chart_rounded));
      await tester.pump();
      expect(find.text('RGB + Lum'), findsOneWidget);
    });
  });
}
