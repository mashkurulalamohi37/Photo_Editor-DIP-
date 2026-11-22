import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pixel_image.dart';
import '../services/dip_engine.dart';
import '../services/image_export_service.dart';
import '../services/sample_image_generator.dart';
import '../widgets/digitization_calculator_sheet.dart';
import '../widgets/histogram_chart.dart';
import '../widgets/image_canvas_view.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final ImagePicker _picker = ImagePicker();

  String _activePresetId = 'sunset';
  late PixelImage _originalImage;
  late PixelImage _currentImage;
  late HistogramData _histogram;

  final List<PixelImage> _undoStack = [];
  final List<DipOperationRecord> _operationHistory = [];

  bool _showHistogram = true;
  bool _splitCompareMode = false;
  int _selectedTabIndex = 0;

  // Tab 1: Point & Enhancement parameters
  double _gammaValue = 0.65;
  final double _logGain = 1.05;
  final bool _equalizePreserveColor = true;
  double _hueShift = 0.0;
  final double _saturationScale = 1.25;

  // Tab 2: Noise & Spatial Filtering parameters
  final double _saltPepperDensity = 0.06;
  final double _gaussianNoiseSigma = 22.0;
  int _filterKernelSize = 3;
  final double _gaussianBlurSigma = 1.2;
  bool _laplacianSharpenMode = true;
  bool _laplacianEightNeighbor = true;
  bool _useConvolutionFlip = true;

  // Tab 3: Segmentation & Morphology parameters
  int _manualThreshold = 128;
  final double _cannyLow = 35.0;
  final double _cannyHigh = 85.0;
  int _kMeansClusters = 4;
  final int _regionTolerance = 28;
  bool _regionEightConnected = true;
  int? _lastGrownRegionCount;

  // Tab 4: Digitization (Sampling & Quantization) parameters
  int _samplingFactor = 1;
  int _quantizationBits = 8;

  // Tab 5: Pixel Inspector & Distance measures
  math.Point<int> _point1 = const math.Point<int>(120, 120);
  math.Point<int> _point2 = const math.Point<int>(220, 195);
  bool _selectingSecondPoint = false;

  @override
  void initState() {
    super.initState();
    _loadSamplePreset(_activePresetId, resetHistory: true);
  }

  void _loadSamplePreset(String presetId, {bool resetHistory = true}) {
    final generated = SampleImageGenerator.generate(presetId, size: 360);
    final hist = DipEngine.computeHistogram(generated);
    setState(() {
      _activePresetId = presetId;
      _originalImage = generated;
      _currentImage = generated.clone();
      _histogram = hist;
      _manualThreshold = hist.otsuThreshold;
      _samplingFactor = 1;
      _quantizationBits = 8;
      _point1 = math.Point<int>(generated.width ~/ 3, generated.height ~/ 3);
      _point2 = math.Point<int>(
        (generated.width * 2) ~/ 3,
        (generated.height * 2) ~/ 3,
      );
      if (resetHistory) {
        _undoStack.clear();
        _operationHistory.clear();
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 480,
        maxHeight: 480,
      );
      if (file == null) return;

      final Uint8List rawBytes = await file.readAsBytes();
      await loadRawImageBytes(rawBytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open image source: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Decodes raw PNG/JPEG bytes into a 2D RGBA PixelImage for editing.
  Future<void> loadRawImageBytes(Uint8List rawBytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(rawBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image decodedImage = frameInfo.image;
    final ByteData? rgbaBytes = await decodedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (rgbaBytes == null) return;

    final loaded = PixelImage(
      width: decodedImage.width,
      height: decodedImage.height,
      pixels: Uint8List.fromList(rgbaBytes.buffer.asUint8List()),
    );
    final hist = DipEngine.computeHistogram(loaded);

    if (!mounted) return;
    setState(() {
      _activePresetId = 'custom';
      _originalImage = loaded;
      _currentImage = loaded.clone();
      _histogram = hist;
      _manualThreshold = hist.otsuThreshold;
      _samplingFactor = 1;
      _quantizationBits = 8;
      _point1 = math.Point<int>(loaded.width ~/ 3, loaded.height ~/ 3);
      _point2 = math.Point<int>(
        (loaded.width * 2) ~/ 3,
        (loaded.height * 2) ~/ 3,
      );
      _undoStack.clear();
      _operationHistory.clear();
    });
  }

  /// Encodes the edited PixelImage into lossless PNG bytes.
  static Future<Uint8List> encodePixelImageToPng(PixelImage img) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      img.pixels,
      img.width,
      img.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final uiImg = await completer.future;
    final byteData = await uiImg.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _showExportedPhotoDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF38BDF8),
              ),
            ),
            SizedBox(width: 12),
            Text('Processing and saving high-res PNG...'),
          ],
        ),
        duration: Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final pngBytes = await encodePixelImageToPng(_currentImage);
      if (!mounted) return;

      final sizeKb = (pngBytes.lengthInBytes / 1024.0).toStringAsFixed(1);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'DIP_Studio_$timestamp.png';

      final exportResult = await saveImageToDevice(pngBytes, fileName);
      if (!mounted) return;

      messenger.hideCurrentSnackBar();

      if (exportResult.success) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved: $fileName\n${exportResult.filePath}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            action: exportResult.canShare
                ? SnackBarAction(
                    label: 'SHARE',
                    textColor: Colors.white,
                    onPressed: () => shareExportedImage(exportResult.filePath),
                  )
                : null,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to save image: ${exportResult.message}'),
          ),
        );
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF151922),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edited Photo Ready (PNG)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(
                      'Saved to Device Storage',
                      style: TextStyle(fontSize: 11, color: Color(0xFF34D399)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    height: 190,
                    width: double.infinity,
                    child: Image.memory(
                      pngBytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2234),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_special_outlined, size: 16, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Saved: ${exportResult.filePath}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      Text(
                        '• Dimensions: ${_currentImage.width} × ${_currentImage.height} px\n'
                        '• Format: Lossless 32-bit RGBA PNG ($sizeKb KB)\n'
                        '• Edits Applied: ${_operationHistory.length} step(s)\n'
                        '• Effective Sampling: ${_currentImage.effectiveWidth}×${_currentImage.effectiveHeight} (÷${_currentImage.samplingFactor})\n'
                        '• Quantization Depth: ${_currentImage.quantizationBits}-bit (${_currentImage.grayLevels} levels)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            if (exportResult.canShare)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share / Save to Gallery'),
                onPressed: () => shareExportedImage(exportResult.filePath),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _applyOperation({
    required String title,
    required String category,
    required String formula,
    required PixelImage Function(PixelImage src) processor,
    bool applyFromOriginal = false,
  }) {
    final sw = Stopwatch()..start();
    final baseImage = applyFromOriginal ? _originalImage : _currentImage;
    final result = processor(baseImage);
    final hist = DipEngine.computeHistogram(result);
    sw.stop();

    setState(() {
      if (!applyFromOriginal) {
        _undoStack.add(_currentImage);
        if (_undoStack.length > 15) {
          _undoStack.removeAt(0);
        }
      } else {
        if (_undoStack.isEmpty) {
          _undoStack.add(_currentImage);
        }
      }
      _currentImage = result;
      _histogram = hist;
      _operationHistory.add(
        DipOperationRecord(
          title: title,
          category: category,
          formula: formula,
          durationMs: sw.elapsedMilliseconds,
        ),
      );
    });
  }

  void _undoLastOperation() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _currentImage = _undoStack.removeLast();
      _histogram = DipEngine.computeHistogram(_currentImage);
      if (_operationHistory.isNotEmpty) {
        _operationHistory.removeLast();
      }
      _samplingFactor = _currentImage.samplingFactor;
      _quantizationBits = _currentImage.quantizationBits;
    });
  }

  void _resetToOriginal() {
    setState(() {
      _currentImage = _originalImage.clone();
      _histogram = DipEngine.computeHistogram(_currentImage);
      _undoStack.clear();
      _operationHistory.clear();
      _samplingFactor = 1;
      _quantizationBits = 8;
      _lastGrownRegionCount = null;
    });
  }

  void _handleCanvasPixelTap(math.Point<int> pt) {
    // If on Segmentation tab (index 2), tapping grows a region from that seed pixel!
    if (_selectedTabIndex == 2) {
      setState(() {
        _point1 = pt;
      });
      _runRegionGrowingFromSeed(pt);
      return;
    }

    // Otherwise update P1 or P2 for the Pixel Inspector & Distance Calculator
    setState(() {
      if (!_selectingSecondPoint) {
        _point1 = pt;
        _selectingSecondPoint = true;
      } else {
        _point2 = pt;
        _selectingSecondPoint = false;
      }
    });
  }

  void _runRegionGrowingFromSeed(math.Point<int> seed) {
    final sw = Stopwatch()..start();
    final res = DipEngine.applyRegionGrowing(
      _originalImage,
      seedX: seed.x,
      seedY: seed.y,
      tolerance: _regionTolerance,
      eightConnected: _regionEightConnected,
    );
    final hist = DipEngine.computeHistogram(res.image);
    sw.stop();

    setState(() {
      _undoStack.add(_currentImage);
      if (_undoStack.length > 15) _undoStack.removeAt(0);
      _currentImage = res.image;
      _histogram = hist;
      _lastGrownRegionCount = res.grownPixels;
      _operationHistory.add(
        DipOperationRecord(
          title: 'Region Growing (${_regionEightConnected ? "8-conn" : "4-conn"})',
          category: 'Segmentation',
          formula:
              'Seed(${seed.x},${seed.y}) |I(x,y) - I(seed)| ≤ $_regionTolerance → ${res.grownPixels} px',
          durationMs: sw.elapsedMilliseconds,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final latestOp =
        _operationHistory.isNotEmpty ? _operationHistory.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11151E),
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_fix_high_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIP Studio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Digital Image Processing Lab & Editor',
                    style: TextStyle(fontSize: 10.5, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Camera Capture',
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            onPressed: () => _pickImage(ImageSource.camera),
          ),
          IconButton(
            tooltip: 'Pick from Gallery',
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
          IconButton(
            tooltip: 'Export Edited Photo (PNG)',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF34D399), width: 1.1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded, size: 15, color: Color(0xFF34D399)),
                  SizedBox(width: 4),
                  Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
            ),
            onPressed: _showExportedPhotoDialog,
          ),
          IconButton(
            tooltip: 'Toggle Histogram Chart',
            icon: Icon(
              Icons.bar_chart_rounded,
              size: 20,
              color: _showHistogram ? const Color(0xFF38BDF8) : Colors.white70,
            ),
            onPressed: () => setState(() => _showHistogram = !_showHistogram),
          ),
          IconButton(
            tooltip: 'Digitization M×N×k Calculator & DIP Guide',
            icon: const Icon(Icons.calculate_outlined, size: 20),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const DigitizationCalculatorSheet(),
              );
            },
          ),
          IconButton(
            tooltip: 'Help & Guide',
            icon: const Icon(Icons.help_outline_rounded, size: 20),
            onPressed: _showQuickHelpDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Sample Test Images & Undo/Compare Bar
            _buildTopActionRow(),

            // 2. Main Interactive Image Viewport
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    Expanded(
                      child: ImageCanvasView(
                        originalImage: _originalImage,
                        currentImage: _currentImage,
                        splitCompareMode: _splitCompareMode,
                        inspectorEnabled:
                            _selectedTabIndex == 4 || _selectedTabIndex == 2,
                        primaryPoint: _point1,
                        secondaryPoint: _selectedTabIndex == 4 ? _point2 : null,
                        onPixelTapped: _handleCanvasPixelTap,
                      ),
                    ),
                    if (latestOp != null) ...[
                      const SizedBox(height: 6),
                      _buildActiveOperationBanner(latestOp),
                    ],
                    if (_showHistogram) ...[
                      const SizedBox(height: 6),
                      HistogramChart(
                        histogram: _histogram,
                        activeThreshold:
                            _selectedTabIndex == 2 ? _manualThreshold : null,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Bottom DIP Algorithm Workbench
            _buildBottomWorkbench(),
          ],
        ),
      ),
    );
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF151922),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Load Photo to Edit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Import any high-resolution image or photograph to apply digital image processing techniques.',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white12),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFF38BDF8)),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('PNG, JPG, WebP from device storage', style: TextStyle(fontSize: 11, color: Colors.white54)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white12),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_camera_outlined, color: Color(0xFF34D399)),
                ),
                title: const Text('Capture with Camera', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Snap a real-world document or scene', style: TextStyle(fontSize: 11, color: Colors.white54)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFBBF24), size: 22),
            SizedBox(width: 8),
            Text('Quick Start Guide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HelpTile(
                icon: Icons.photo_library_outlined,
                title: 'Load Any Photo',
                desc: 'Tap Camera or Gallery in the top bar, or pick one of the sample test scenes.',
              ),
              _HelpTile(
                icon: Icons.tune_rounded,
                title: '5 DIP Workbenches',
                desc: 'Switch between Enhance, Filters, Segment, Digitize, and Inspector tabs below.',
              ),
              _HelpTile(
                icon: Icons.compare_rounded,
                title: 'Before & After Compare',
                desc: 'Slide the comparison divider, or press & hold the photo to peek original.',
              ),
              _HelpTile(
                icon: Icons.undo_rounded,
                title: 'Undo Any Change',
                desc: 'Easily step back or reset at any time without losing original quality.',
              ),
              _HelpTile(
                icon: Icons.download_rounded,
                title: 'Lossless Export',
                desc: 'Tap the Download icon to save your edited photo as high-res PNG.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  IconData _presetIcon(String id) {
    switch (id) {
      case 'low_contrast':
        return Icons.tonality_rounded;
      case 'coins_cells':
        return Icons.bubble_chart_rounded;
      case 'test_card':
        return Icons.grid_on_rounded;
      case 'sunset':
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  Widget _buildTopActionRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF11151E),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          // Preset selector dropdown & Load Custom Photo button
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _showPhotoSourceSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 5),
                            Text(
                              '+ Photo',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ...SampleImageGenerator.presets.map((preset) {
                  final isSelected = _activePresetId == preset.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _loadSamplePreset(preset.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF38BDF8).withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : Colors.white12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _presetIcon(preset.id),
                              size: 13,
                              color: isSelected
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white60,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              preset.name,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF38BDF8)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Split Before/After Toggle
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Split Before / After Comparison',
            onPressed: () =>
                setState(() => _splitCompareMode = !_splitCompareMode),
            icon: Icon(
              Icons.compare_rounded,
              size: 19,
              color: _splitCompareMode
                  ? const Color(0xFF38BDF8)
                  : Colors.white70,
            ),
          ),
          // Undo Button
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Undo Last Operation',
            onPressed: _undoStack.isNotEmpty ? _undoLastOperation : null,
            icon: Badge(
              isLabelVisible: _undoStack.isNotEmpty,
              label: Text('${_undoStack.length}'),
              backgroundColor: const Color(0xFF38BDF8),
              textColor: Colors.black,
              child: const Icon(Icons.undo_rounded, size: 19),
            ),
          ),
          // Reset Button
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Reset to Original Image',
            onPressed: _operationHistory.isNotEmpty ? _resetToOriginal : null,
            icon: const Icon(Icons.restart_alt_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOperationBanner(DipOperationRecord op) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFF38BDF8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${op.title} • ${op.formula}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${op.durationMs} ms • Step ${_operationHistory.length}',
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF34D399),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomWorkbench() {
    const tabs = [
      (icon: Icons.tune_rounded, label: 'Enhance'),
      (icon: Icons.blur_on_rounded, label: 'Filters & Noise'),
      (icon: Icons.pie_chart_outline_rounded, label: 'Segment'),
      (icon: Icons.grid_4x4_rounded, label: 'Digitize'),
      (icon: Icons.straighten_rounded, label: 'Inspector'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF11151E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category Selector Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final tab = tabs[index];
                final selected = _selectedTabIndex == index;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _selectedTabIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF38BDF8).withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab.icon,
                            size: 18,
                            color: selected
                                ? const Color(0xFF38BDF8)
                                : Colors.white54,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Active Tab Panel Content
          SizedBox(
            height: 226,
            child: SingleChildScrollView(
              key: ValueKey<int>(_selectedTabIndex),
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: _buildSelectedTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildPointAndEnhancementTab();
      case 1:
        return _buildFilteringAndNoiseTab();
      case 2:
        return _buildSegmentationAndMorphologyTab();
      case 3:
        return _buildDigitizationTab();
      case 4:
      default:
        return _buildInspectorAndDistanceTab();
    }
  }

  // ===========================================================================
  // TAB 0: POINT OPERATIONS & HISTOGRAM ENHANCEMENT
  // ===========================================================================
  Widget _buildPointAndEnhancementTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spatial Point Operations & Histogram Enhancement',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChipButton(
              icon: Icons.contrast_rounded,
              label: 'Grayscale',
              subtitle: 'I = 0.299R+0.587G+0.114B',
              onTap: () => _applyOperation(
                title: 'Grayscale Luminance',
                category: 'Point Operation',
                formula: 'I = 0.299R + 0.587G + 0.114B',
                processor: DipEngine.toGrayscale,
              ),
            ),
            _ActionChipButton(
              icon: Icons.invert_colors_rounded,
              label: 'Negative',
              subtitle: 's = (L - 1) - r',
              onTap: () => _applyOperation(
                title: 'Image Negative',
                category: 'Point Operation',
                formula: 's = 255 - r',
                processor: DipEngine.invertNegative,
              ),
            ),
            _ActionChipButton(
              icon: Icons.equalizer_rounded,
              label: 'Histogram Equalize',
              subtitle: 'Spreads CDF intensity',
              accentColor: const Color(0xFF34D399),
              onTap: () => _applyOperation(
                title: 'Histogram Equalization',
                category: 'Enhancement',
                formula: 's_k = round((L-1) ∑ p_r(r_j))',
                processor: (img) => DipEngine.applyHistogramEqualization(
                  img,
                  preserveColor: _equalizePreserveColor,
                ),
              ),
            ),
            _ActionChipButton(
              icon: Icons.open_in_full_rounded,
              label: 'Contrast Stretch',
              subtitle: '[r_min..r_max] → [0..255]',
              onTap: () => _applyOperation(
                title: 'Contrast Stretching',
                category: 'Enhancement',
                formula: 's = (r - r_min)/(r_max - r_min) × 255',
                processor: DipEngine.applyContrastStretch,
              ),
            ),
            _ActionChipButton(
              icon: Icons.functions_rounded,
              label: 'Log Transform',
              subtitle: 's = c·log(1 + r)',
              onTap: () => _applyOperation(
                title: 'Log Transformation',
                category: 'Point Operation',
                formula: 's = c · ln(1 + r), gain=${_logGain.toStringAsFixed(2)}',
                processor: (img) =>
                    DipEngine.applyLogTransform(img, gain: _logGain),
              ),
            ),
            _ActionChipButton(
              icon: Icons.rotate_90_degrees_cw_rounded,
              label: 'Rotate 90°',
              subtitle: 'Geometric CW',
              accentColor: const Color(0xFFA78BFA),
              onTap: () => _applyOperation(
                title: 'Rotate 90° Clockwise',
                category: 'Photo Geometry',
                formula: '(x, y) → (H-1-y, x)',
                processor: DipEngine.rotate90Clockwise,
              ),
            ),
            _ActionChipButton(
              icon: Icons.flip_rounded,
              label: 'Flip H',
              subtitle: 'Mirror left-right',
              accentColor: const Color(0xFFA78BFA),
              onTap: () => _applyOperation(
                title: 'Horizontal Mirror Flip',
                category: 'Photo Geometry',
                formula: '(x, y) → (W-1-x, y)',
                processor: DipEngine.flipHorizontal,
              ),
            ),
            _ActionChipButton(
              icon: Icons.swap_vert_rounded,
              label: 'Flip V',
              subtitle: 'Mirror top-bottom',
              accentColor: const Color(0xFFA78BFA),
              onTap: () => _applyOperation(
                title: 'Vertical Mirror Flip',
                category: 'Photo Geometry',
                formula: '(x, y) → (x, H-1-y)',
                processor: DipEngine.flipVertical,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Power-Law (Gamma) Interactive Slider
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF181E2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Power-Law (Gamma): γ = ${_gammaValue.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _applyOperation(
                      title: 'Power-Law (Gamma)',
                      category: 'Point Operation',
                      formula: 's = c · r^${_gammaValue.toStringAsFixed(2)}',
                      processor: (img) => DipEngine.applyGammaTransform(
                        img,
                        gamma: _gammaValue,
                      ),
                    ),
                    child: const Text(
                      'Apply Gamma',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: _gammaValue,
                  min: 0.20,
                  max: 3.00,
                  divisions: 56,
                  label: 'γ = ${_gammaValue.toStringAsFixed(2)}',
                  onChanged: (v) => setState(() => _gammaValue = v),
                  onChangeEnd: (v) => _applyOperation(
                    title: 'Power-Law (Gamma)',
                    category: 'Point Operation',
                    formula: 's = c · r^${v.toStringAsFixed(2)}',
                    applyFromOriginal: true,
                    processor: (img) => DipEngine.applyGammaTransform(
                      img,
                      gamma: v,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Color Processing (RGB <-> HSV) Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF181E2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.palette_outlined,
                size: 16,
                color: Color(0xFFA78BFA),
              ),
              const SizedBox(width: 6),
              const Text(
                'HSV:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _hueShift,
                    min: -180,
                    max: 180,
                    divisions: 36,
                    label: 'Hue ${_hueShift.round()}°',
                    onChanged: (v) => setState(() => _hueShift = v),
                    onChangeEnd: (v) => _applyOperation(
                      title: 'HSV Color Transform',
                      category: 'Color Processing',
                      formula:
                          'ΔHue=${v.round()}°, Sat×${_saturationScale.toStringAsFixed(2)}',
                      applyFromOriginal: true,
                      processor: (img) => DipEngine.applyHsvAdjustment(
                        img,
                        hueShiftDeg: v,
                        saturationScale: _saturationScale,
                        valueScale: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA78BFA),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _applyOperation(
                  title: 'HSV Color Transform',
                  category: 'Color Processing',
                  formula:
                      'ΔHue=${_hueShift.round()}°, Sat×${_saturationScale.toStringAsFixed(2)}',
                  processor: (img) => DipEngine.applyHsvAdjustment(
                    img,
                    hueShiftDeg: _hueShift,
                    saturationScale: _saturationScale,
                    valueScale: 1.0,
                  ),
                ),
                child: Text(
                  'Hue ${_hueShift >= 0 ? "+${_hueShift.round()}" : _hueShift.round()}°',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 1: NOISE MODELS & SPATIAL FILTERING (SMOOTHING, RESTORATION, SHARPENING)
  // ===========================================================================
  Widget _buildFilteringAndNoiseTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '1. Add Degradation / Noise',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Kernel size 3x3 vs 5x5 toggle
            SegmentedButton<int>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: 3,
                  label: Text('3×3', style: TextStyle(fontSize: 10.5)),
                ),
                ButtonSegment(
                  value: 5,
                  label: Text('5×5', style: TextStyle(fontSize: 10.5)),
                ),
              ],
              selected: {_filterKernelSize},
              onSelectionChanged: (s) =>
                  setState(() => _filterKernelSize = s.first),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChipButton(
              icon: Icons.grain_rounded,
              label: 'Salt & Pepper Noise',
              subtitle: 'Impulse (${(_saltPepperDensity * 100).round()}%)',
              accentColor: const Color(0xFFF43F5E),
              onTap: () => _applyOperation(
                title: 'Salt & Pepper Noise',
                category: 'Noise Model',
                formula:
                    'Impulse p=${(_saltPepperDensity * 100).round()}% (0 & 255)',
                processor: (img) => DipEngine.addSaltAndPepperNoise(
                  img,
                  density: _saltPepperDensity,
                ),
              ),
            ),
            _ActionChipButton(
              icon: Icons.blur_circular_rounded,
              label: 'Gaussian Noise',
              subtitle: 'N(0, σ=${_gaussianNoiseSigma.round()})',
              accentColor: const Color(0xFFF43F5E),
              onTap: () => _applyOperation(
                title: 'Gaussian Noise',
                category: 'Noise Model',
                formula: 'g(x,y) = f(x,y) + N(0, σ=${_gaussianNoiseSigma.round()})',
                processor: (img) => DipEngine.addGaussianNoise(
                  img,
                  sigma: _gaussianNoiseSigma,
                ),
              ),
            ),
            _ActionChipButton(
              icon: Icons.lens_blur_rounded,
              label: 'Speckle Noise',
              subtitle: 'Multiplicative f + n·f',
              accentColor: const Color(0xFFF43F5E),
              onTap: () => _applyOperation(
                title: 'Speckle Noise',
                category: 'Noise Model',
                formula: 'g(x,y) = f(x,y) · (1 + n)',
                processor: DipEngine.addSpeckleNoise,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '2. Smoothing (Low-Pass), Restoration & Sharpening (High-Pass)',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChipButton(
              icon: Icons.cleaning_services_rounded,
              label: 'Median Filter ($_filterKernelSize×$_filterKernelSize)',
              subtitle: 'Best for Salt & Pepper!',
              accentColor: const Color(0xFF34D399),
              onTap: () => _applyOperation(
                title: 'Median Filter ($_filterKernelSize×$_filterKernelSize)',
                category: 'Order-Statistic Restoration',
                formula: 'g(x,y) = median{f(s,t)} in $_filterKernelSize×$_filterKernelSize',
                processor: (img) => DipEngine.applyMedianFilter(
                  img,
                  kernelSize: _filterKernelSize,
                ),
              ),
            ),
            _ActionChipButton(
              icon: Icons.grid_on_rounded,
              label: 'Mean Filter ($_filterKernelSize×$_filterKernelSize)',
              subtitle: 'Box averaging smooth',
              onTap: () => _applyOperation(
                title: 'Mean Box Filter ($_filterKernelSize×$_filterKernelSize)',
                category: 'Spatial Smoothing',
                formula:
                    'g(x,y) = (1/${_filterKernelSize * _filterKernelSize}) ∑ f(s,t)',
                processor: (img) => DipEngine.applyMeanFilter(
                  img,
                  kernelSize: _filterKernelSize,
                ),
              ),
            ),
            _ActionChipButton(
              icon: Icons.deblur_rounded,
              label: 'Gaussian Blur ($_filterKernelSize×$_filterKernelSize)',
              subtitle: 'G(x,y) σ=${_gaussianBlurSigma.toStringAsFixed(1)}',
              onTap: () => _applyOperation(
                title: 'Gaussian Smoothing ($_filterKernelSize×$_filterKernelSize)',
                category: 'Low-Pass Filter',
                formula:
                    'G(x,y) = exp(-(x²+y²)/2σ²), σ=${_gaussianBlurSigma.toStringAsFixed(1)}',
                processor: (img) => DipEngine.applyGaussianFilter(
                  img,
                  kernelSize: _filterKernelSize,
                  sigma: _gaussianBlurSigma,
                ),
              ),
            ),
            _ActionChipButton(
              icon: Icons.auto_awesome_rounded,
              label: _laplacianSharpenMode
                  ? 'Laplacian Sharpen'
                  : 'Laplacian Edges',
              subtitle: _laplacianEightNeighbor
                  ? '8-Neighbor ∇²f'
                  : '4-Neighbor ∇²f',
              accentColor: const Color(0xFF38BDF8),
              onTap: () => _applyOperation(
                title: _laplacianSharpenMode
                    ? 'Laplacian Sharpening'
                    : 'Laplacian Edge Map',
                category: '2nd-Order Derivative',
                formula: _laplacianSharpenMode
                    ? 'g = f - c∇²f (${_laplacianEightNeighbor ? "8-neighbor" : "4-neighbor"})'
                    : '|∇²f| (${_laplacianEightNeighbor ? "8-neighbor" : "4-neighbor"})',
                processor: (img) => DipEngine.applyLaplacianFilter(
                  img,
                  sharpenImage: _laplacianSharpenMode,
                  eightNeighbor: _laplacianEightNeighbor,
                ),
              ),
            ),
            _ActionChipButton(
              icon: Icons.border_outer_rounded,
              label: 'Sobel Gradient',
              subtitle: '|∇f| = √(Gx² + Gy²)',
              accentColor: const Color(0xFF38BDF8),
              onTap: () => _applyOperation(
                title: 'Sobel Gradient Operator',
                category: '1st-Order Derivative',
                formula: '|∇f| = √(Gx² + Gy²)',
                processor: DipEngine.applySobelFilter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Convolution vs. Correlation & Laplacian options bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF181E2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: Text(
                  _laplacianSharpenMode ? 'Laplacian: Sharpen' : 'Laplacian: Edge Map',
                  style: const TextStyle(fontSize: 10.5),
                ),
                selected: _laplacianSharpenMode,
                onSelected: (v) => setState(() => _laplacianSharpenMode = v),
              ),
              FilterChip(
                label: Text(
                  _laplacianEightNeighbor ? '8-Neighbor Kernel' : '4-Neighbor Kernel',
                  style: const TextStyle(fontSize: 10.5),
                ),
                selected: _laplacianEightNeighbor,
                onSelected: (v) => setState(() => _laplacianEightNeighbor = v),
              ),
              ActionChip(
                avatar: const Icon(Icons.rotate_90_degrees_ccw, size: 15),
                label: Text(
                  _useConvolutionFlip
                      ? 'Test 3×3 Convolution (180° Flipped)'
                      : 'Test 3×3 Correlation (Unflipped)',
                  style: const TextStyle(fontSize: 10.5),
                ),
                onPressed: () {
                  // Asymmetric directional relief kernel to visually highlight
                  // Convolution (flips kernel 180 degrees first) vs Correlation!
                  const directionalKernel = <double>[
                    -2, -1, 0,
                    -1,  1, 1,
                     0,  1, 2,
                  ];
                  final isConv = _useConvolutionFlip;
                  _applyOperation(
                    title: isConv
                        ? 'Spatial Convolution (Kernel Flipped 180°)'
                        : 'Spatial Correlation (Unflipped Kernel)',
                    category: 'Spatial Filtering',
                    formula: isConv
                        ? '(f * w)(x,y) = ∑∑ f(x-s, y-t) w(s,t)'
                        : '(f ⋆ w)(x,y) = ∑∑ f(x+s, y+t) w(s,t)',
                    processor: (img) => DipEngine.applyCustomKernel3x3(
                      img,
                      kernel: directionalKernel,
                      isConvolution: isConv,
                    ),
                  );
                  setState(() => _useConvolutionFlip = !_useConvolutionFlip);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: SEGMENTATION APPROACHES & MORPHOLOGICAL PROCESSING
  // ===========================================================================
  Widget _buildSegmentationAndMorphologyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChipButton(
              icon: Icons.auto_graph_rounded,
              label: "Otsu's Threshold",
              subtitle: 'Auto T* = ${_histogram.otsuThreshold}',
              accentColor: const Color(0xFFFBBF24),
              onTap: () {
                final t = _histogram.otsuThreshold;
                setState(() => _manualThreshold = t);
                _applyOperation(
                  title: "Otsu's Optimal Thresholding",
                  category: 'Segmentation',
                  formula: 'Maximized σ²_B(T*) at T* = $t',
                  processor: (img) => DipEngine.applyThreshold(img, threshold: t),
                );
              },
            ),
            _ActionChipButton(
              icon: Icons.polyline_rounded,
              label: 'Canny Edges',
              subtitle: 'NMS + Hysteresis',
              accentColor: const Color(0xFF38BDF8),
              onTap: () => _applyOperation(
                title: 'Canny Edge Segmentation',
                category: 'Edge-Based Segmentation',
                formula:
                    'Gaussian → Sobel → NMS → Hysteresis (${_cannyLow.round()}/${_cannyHigh.round()})',
                processor: (img) => DipEngine.applyCannyEdgeDetection(
                  img,
                  lowThreshold: _cannyLow,
                  highThreshold: _cannyHigh,
                ),
              ),
            ),
            _ActionChipButton(
              icon: Icons.scatter_plot_rounded,
              label: 'K-Means (K=$_kMeansClusters)',
              subtitle: 'Color clustering',
              accentColor: const Color(0xFFA78BFA),
              onTap: () => _applyOperation(
                title: 'K-Means Clustering (K=$_kMeansClusters)',
                category: 'Clustering Segmentation',
                formula: 'min ∑ ||I(x,y) - μ_k||² for K = $_kMeansClusters',
                processor: (img) => DipEngine.applyKMeansSegmentation(
                  img,
                  k: _kMeansClusters,
                ),
              ),
            ),
            _ActionChipButton(
              icon: Icons.compress_rounded,
              label: 'Erosion (f ⊖ B)',
              subtitle: 'Shrink bright shapes',
              onTap: () => _applyOperation(
                title: 'Morphological Erosion',
                category: 'Morphological Processing',
                formula: '(f ⊖ B)(x,y) = min_{(s,t)∈B} f(x+s, y+t)',
                processor: (img) =>
                    DipEngine.applyMorphology(img, isDilation: false),
              ),
            ),
            _ActionChipButton(
              icon: Icons.expand_rounded,
              label: 'Dilation (f ⊕ B)',
              subtitle: 'Grow bright shapes',
              onTap: () => _applyOperation(
                title: 'Morphological Dilation',
                category: 'Morphological Processing',
                formula: '(f ⊕ B)(x,y) = max_{(s,t)∈B} f(x-s, y-t)',
                processor: (img) =>
                    DipEngine.applyMorphology(img, isDilation: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Manual Thresholding & K-Means Cluster Selector Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF181E2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'T=$_manualThreshold',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: _manualThreshold.toDouble(),
                        min: 0,
                        max: 255,
                        divisions: 255,
                        onChanged: (v) {
                          setState(() => _manualThreshold = v.round());
                        },
                        onChangeEnd: (v) {
                          _applyOperation(
                            title: 'Manual Thresholding',
                            category: 'Segmentation',
                            formula: 'g(x,y) = 255 if f(x,y) ≥ ${v.round()} else 0',
                            processor: (img) => DipEngine.applyThreshold(
                              img,
                              threshold: v.round(),
                            ),
                            applyFromOriginal: true,
                          );
                        },
                      ),
                    ),
                  ),
                  const Text(
                    'K:',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(width: 4),
                  ...[2, 3, 4, 6].map((kVal) {
                    final selected = _kMeansClusters == kVal;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        onTap: () => setState(() => _kMeansClusters = kVal),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFA78BFA)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$kVal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.black : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.touch_app_rounded,
                    size: 14,
                    color: Color(0xFF34D399),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Region Growing: Tap any seed pixel on canvas '
                      '(Seed: ${_point1.x},${_point1.y}'
                      '${_lastGrownRegionCount != null ? " → $_lastGrownRegionCount px" : ""})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(
                        () => _regionEightConnected = !_regionEightConnected,
                      );
                      _runRegionGrowingFromSeed(_point1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _regionEightConnected ? '8-Neighbors' : '4-Neighbors',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: DIGITIZATION (SAMPLING & QUANTIZATION SIMULATOR)
  // ===========================================================================
  Widget _buildDigitizationTab() {
    final effW = math.max(1, _originalImage.width ~/ _samplingFactor);
    final effH = math.max(1, _originalImage.height ~/ _samplingFactor);
    final grayLevels = 1 << _quantizationBits;
    final bits = effW * effH * _quantizationBits;
    final origBits = _originalImage.width * _originalImage.height * 8;
    final savingsPct =
        origBits > 0 ? ((1.0 - bits / origBits) * 100.0).clamp(0.0, 99.9) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF181E2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Spatial Sampling Row
              Row(
                children: [
                  const Icon(
                    Icons.grid_view_rounded,
                    size: 15,
                    color: Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sampling (Resolution): $effW×$effH (÷$_samplingFactor)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...[1, 2, 4, 8, 16].map((factor) {
                    final selected = _samplingFactor == factor;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() => _samplingFactor = factor);
                          _applyDigitizationPreview();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF38BDF8)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '÷$factor',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.black : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),

              // Quantization Bit Depth Row
              Row(
                children: [
                  const Icon(
                    Icons.layers_rounded,
                    size: 15,
                    color: Color(0xFFA78BFA),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Quantization: k = $_quantizationBits bits (L = 2^$_quantizationBits = $grayLevels levels)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: _quantizationBits.toDouble(),
                  min: 1,
                  max: 8,
                  divisions: 7,
                  label: 'k = $_quantizationBits bits (L = $grayLevels)',
                  onChanged: (v) {
                    setState(() => _quantizationBits = v.round());
                    _applyDigitizationPreview();
                  },
                ),
              ),

              // Live M × N × k readout
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E121A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Size = M × N × k = $effW × $effH × $_quantizationBits = ${_currentImage.formattedBitSize}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                    Text(
                      '-${savingsPct.toStringAsFixed(1)}% bits',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _applyDigitizationPreview() {
    _applyOperation(
      title: 'Digitization (s=÷$_samplingFactor, k=$_quantizationBits bits)',
      category: 'Digitization',
      formula: 'L = 2^$_quantizationBits = ${1 << _quantizationBits} levels',
      applyFromOriginal: true,
      processor: (img) => DipEngine.applyDigitization(
        img,
        samplingFactor: _samplingFactor,
        quantizationBits: _quantizationBits,
      ),
    );
  }

  // ===========================================================================
  // TAB 4: PIXEL INSPECTOR, NEIGHBORHOODS (N4/N8) & DISTANCE MEASURES
  // ===========================================================================
  Widget _buildInspectorAndDistanceTab() {
    final p1 = _point1;
    final p2 = _point2;
    final r1 = _currentImage.getRed(p1.x, p1.y);
    final g1 = _currentImage.getGreen(p1.x, p1.y);
    final b1 = _currentImage.getBlue(p1.x, p1.y);
    final lum1 = _currentImage.getLuminance(p1.x, p1.y);

    final dx = (p1.x - p2.x).abs();
    final dy = (p1.y - p2.y).abs();
    final euclidean = math.sqrt(dx * dx + dy * dy);
    final cityBlockD4 = dx + dy;
    final chessboardD8 = math.max(dx, dy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.ads_click_rounded,
              size: 15,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tap image canvas to set P1 (cyan) & P2 (red) • Next tap sets: ${_selectingSecondPoint ? "P2" : "P1"}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Distance Measures Card (Euclidean, City-Block D4, Chessboard D8)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF181E2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, r1, g1, b1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'P1(${p1.x}, ${p1.y}): RGB($r1, $g1, $b1) • Lum I=$lum1   |   P2(${p2.x}, ${p2.y})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DistanceMetricBox(
                      title: 'Euclidean (De)',
                      formula: '√(Δx² + Δy²)',
                      value: '${euclidean.toStringAsFixed(2)} px',
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _DistanceMetricBox(
                      title: 'City-Block (D4)',
                      formula: '|Δx| + |Δy|',
                      value: '$cityBlockD4 px',
                      color: const Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _DistanceMetricBox(
                      title: 'Chessboard (D8)',
                      formula: 'max(|Δx|, |Δy|)',
                      value: '$chessboardD8 px',
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 4-Neighbors & 8-Neighbors Intensity Readout around P1
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF141925),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'N4(P1) 4-Neighbors Intensities: '
            'Top=${_safeLum(p1.x, p1.y - 1)}, '
            'Bottom=${_safeLum(p1.x, p1.y + 1)}, '
            'Left=${_safeLum(p1.x - 1, p1.y)}, '
            'Right=${_safeLum(p1.x + 1, p1.y)}',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ),
      ],
    );
  }

  int _safeLum(int x, int y) {
    final cx = x.clamp(0, _currentImage.width - 1);
    final cy = y.clamp(0, _currentImage.height - 1);
    return _currentImage.getLuminance(cx, cy);
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color accentColor;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.accentColor = const Color(0xFF38BDF8),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF181E2C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.32),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _HelpTile({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceMetricBox extends StatelessWidget {
  final String title;
  final String formula;
  final String value;
  final Color color;

  const _DistanceMetricBox({
    required this.title,
    required this.formula,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          formula,
          style: const TextStyle(fontSize: 9.5, color: Colors.white54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
