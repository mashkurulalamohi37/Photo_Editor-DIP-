import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/pixel_image.dart';

class ImageCanvasView extends StatefulWidget {
  final PixelImage originalImage;
  final PixelImage currentImage;
  final bool splitCompareMode;
  final bool inspectorEnabled;
  final math.Point<int>? primaryPoint;
  final math.Point<int>? secondaryPoint;
  final ValueChanged<math.Point<int>>? onPixelTapped;

  const ImageCanvasView({
    super.key,
    required this.originalImage,
    required this.currentImage,
    required this.splitCompareMode,
    required this.inspectorEnabled,
    this.primaryPoint,
    this.secondaryPoint,
    this.onPixelTapped,
  });

  @override
  State<ImageCanvasView> createState() => _ImageCanvasViewState();
}

class _ImageCanvasViewState extends State<ImageCanvasView> {
  ui.Image? _originalUiImage;
  ui.Image? _currentUiImage;
  double _splitFraction = 0.5;
  bool _isPeekingOriginal = false;

  @override
  void initState() {
    super.initState();
    _rebuildOriginalImage();
    _rebuildCurrentImage();
  }

  @override
  void didUpdateWidget(covariant ImageCanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originalImage != widget.originalImage) {
      _rebuildOriginalImage();
    }
    if (oldWidget.currentImage != widget.currentImage) {
      _rebuildCurrentImage();
    }
  }

  void _rebuildOriginalImage() {
    final img = widget.originalImage;
    ui.decodeImageFromPixels(
      img.pixels,
      img.width,
      img.height,
      ui.PixelFormat.rgba8888,
      (decoded) {
        if (!mounted) return;
        setState(() {
          _originalUiImage = decoded;
        });
      },
    );
  }

  void _rebuildCurrentImage() {
    final img = widget.currentImage;
    ui.decodeImageFromPixels(
      img.pixels,
      img.width,
      img.height,
      ui.PixelFormat.rgba8888,
      (decoded) {
        if (!mounted) return;
        setState(() {
          _currentUiImage = decoded;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.currentImage;
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspect = img.width / img.height;
        double drawW = constraints.maxWidth;
        double drawH = drawW / aspect;
        if (drawH > constraints.maxHeight) {
          drawH = constraints.maxHeight;
          drawW = drawH * aspect;
        }

        return Center(
          child: SizedBox(
            width: drawW,
            height: drawH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (_) => setState(() => _isPeekingOriginal = true),
              onLongPressEnd: (_) => setState(() => _isPeekingOriginal = false),
              onLongPressCancel: () => setState(() => _isPeekingOriginal = false),
              onTapUp: (details) {
                if (widget.onPixelTapped == null) return;
                final px = ((details.localPosition.dx / drawW) * img.width)
                    .floor()
                    .clamp(0, img.width - 1);
                final py = ((details.localPosition.dy / drawH) * img.height)
                    .floor()
                    .clamp(0, img.height - 1);
                widget.onPixelTapped!(math.Point<int>(px, py));
              },
              onHorizontalDragUpdate: widget.splitCompareMode
                  ? (details) {
                      setState(() {
                        _splitFraction =
                            (details.localPosition.dx / drawW).clamp(0.05, 0.95);
                      });
                    }
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Checkerboard backdrop
                    Container(color: const Color(0xFF0E1117)),

                    // Main image canvas
                    CustomPaint(
                      painter: _DipCanvasPainter(
                        originalImage: _originalUiImage,
                        currentImage:
                            _isPeekingOriginal ? _originalUiImage : _currentUiImage,
                        splitCompare: widget.splitCompareMode && !_isPeekingOriginal,
                        splitFraction: _splitFraction,
                        imageWidth: img.width,
                        imageHeight: img.height,
                        primaryPoint: widget.primaryPoint,
                        secondaryPoint: widget.secondaryPoint,
                        showInspector: widget.inspectorEnabled,
                      ),
                    ),

                    if (_isPeekingOriginal)
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: _CanvasTag(
                          label: 'VIEWING ORIGINAL',
                          color: Color(0xFFFBBF24),
                        ),
                      )
                    else if (!widget.splitCompareMode)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_outlined, size: 11, color: Colors.white60),
                              SizedBox(width: 4),
                              Text(
                                'Hold to peek original',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Split Compare labels
                    if (widget.splitCompareMode && !_isPeekingOriginal) ...[
                      const Positioned(
                        left: 8,
                        top: 8,
                        child: _CanvasTag(label: 'ORIGINAL'),
                      ),
                      const Positioned(
                        right: 8,
                        top: 8,
                        child: _CanvasTag(
                          label: 'PROCESSED',
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],

                    // Digitization Badge (Resolution & Bit-Size M × N × k)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          '${img.effectiveWidth}×${img.effectiveHeight} • k=${img.quantizationBits}b (L=${img.grayLevels}) • ${img.formattedBitSize}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CanvasTag extends StatelessWidget {
  final String label;
  final Color color;

  const _CanvasTag({
    required this.label,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

class _DipCanvasPainter extends CustomPainter {
  final ui.Image? originalImage;
  final ui.Image? currentImage;
  final bool splitCompare;
  final double splitFraction;
  final int imageWidth;
  final int imageHeight;
  final math.Point<int>? primaryPoint;
  final math.Point<int>? secondaryPoint;
  final bool showInspector;

  _DipCanvasPainter({
    required this.originalImage,
    required this.currentImage,
    required this.splitCompare,
    required this.splitFraction,
    required this.imageWidth,
    required this.imageHeight,
    required this.primaryPoint,
    required this.secondaryPoint,
    required this.showInspector,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final curr = currentImage;
    if (curr == null) return;

    final dstRect = Offset.zero & size;
    final srcRect = Rect.fromLTWH(
      0,
      0,
      curr.width.toDouble(),
      curr.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.none;

    // Draw processed image across full canvas
    canvas.drawImageRect(curr, srcRect, dstRect, paint);

    // If split compare is active, clip left side and draw original image
    if (splitCompare && originalImage != null) {
      final origSrcRect = Rect.fromLTWH(
        0,
        0,
        originalImage!.width.toDouble(),
        originalImage!.height.toDouble(),
      );
      final splitX = size.width * splitFraction;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, splitX, size.height));
      canvas.drawImageRect(originalImage!, origSrcRect, dstRect, paint);
      canvas.restore();

      final dividerPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(splitX, 0), Offset(splitX, size.height), dividerPaint);

      // Handle knob
      final handleCenter = Offset(splitX, size.height * 0.5);
      canvas.drawCircle(
        handleCenter,
        12,
        Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.88),
      );
      canvas.drawCircle(
        handleCenter,
        12,
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Draw Pixel Inspector / Seed markers and distance vector if active
    if (showInspector && primaryPoint != null) {
      final p1Offset = Offset(
        ((primaryPoint!.x + 0.5) / imageWidth) * size.width,
        ((primaryPoint!.y + 0.5) / imageHeight) * size.height,
      );

      if (secondaryPoint != null) {
        final p2Offset = Offset(
          ((secondaryPoint!.x + 0.5) / imageWidth) * size.width,
          ((secondaryPoint!.y + 0.5) / imageHeight) * size.height,
        );
        final linePaint = Paint()
          ..color = const Color(0xFFFBBF24)
          ..strokeWidth = 1.8;
        canvas.drawLine(p1Offset, p2Offset, linePaint);
        _drawCrosshair(canvas, p2Offset, const Color(0xFFF43F5E), 'P2');
      }
      _drawCrosshair(canvas, p1Offset, const Color(0xFF38BDF8), 'P1');
    }
  }

  void _drawCrosshair(Canvas canvas, Offset center, Color color, String tag) {
    canvas.drawCircle(
      center,
      8,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DipCanvasPainter oldDelegate) {
    return oldDelegate.originalImage != originalImage ||
        oldDelegate.currentImage != currentImage ||
        oldDelegate.splitCompare != splitCompare ||
        oldDelegate.splitFraction != splitFraction ||
        oldDelegate.primaryPoint != primaryPoint ||
        oldDelegate.secondaryPoint != secondaryPoint ||
        oldDelegate.showInspector != showInspector;
  }
}
