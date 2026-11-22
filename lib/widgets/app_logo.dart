import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom, high-definition vector logo for DIP Studio.
/// Visualizes the core essence of Digital Image Processing:
/// An optical camera iris (acquisition) focusing onto a 3×3 discrete pixel matrix (sampling & quantization).
class AppLogo extends StatefulWidget {
  final double size;
  final bool showGlow;
  final bool animate;
  final double? borderRadius;

  const AppLogo({
    super.key,
    this.size = 40.0,
    this.showGlow = true,
    this.animate = false,
    this.borderRadius,
  });

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AppLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      )..repeat(reverse: true);
    } else if (!widget.animate && _controller != null) {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.borderRadius ?? (widget.size * 0.24);

    Widget logoGraphic = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _AppLogoPainter(
        progress: _controller?.value ?? 0.0,
        showGlow: widget.showGlow,
        borderRadius: effectiveRadius,
      ),
    );

    if (widget.showGlow) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(effectiveRadius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: widget.animate ? 0.35 : 0.22),
              blurRadius: widget.size * 0.25,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: const Color(0xFFA78BFA).withValues(alpha: widget.animate ? 0.25 : 0.15),
              blurRadius: widget.size * 0.35,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: logoGraphic,
      );
    }

    return logoGraphic;
  }
}

class _AppLogoPainter extends CustomPainter {
  final double progress;
  final bool showGlow;
  final double borderRadius;

  _AppLogoPainter({
    required this.progress,
    required this.showGlow,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Base dark background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF131926),
          Color(0xFF090D15),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // 2. Multi-stop glowing rim
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.04)
      ..shader = SweepGradient(
        center: Alignment.center,
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          Color(0xFF38BDF8),
          Color(0xFFA78BFA),
          Color(0xFF34D399),
          Color(0xFF38BDF8),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(borderPaint.strokeWidth / 2), borderPaint);

    // 3. Aperture Outer Housing Ring
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.02)
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, w * 0.38, outerRingPaint);

    // 4. Optical Aperture Blades (6 blades)
    final bladePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.025)
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.55);

    final bladeFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.65);

    const int bladeCount = 6;
    final double angleStep = (math.pi * 2) / bladeCount;
    final double rotationOffset = progress * 0.15; // gentle breath rotation

    for (int i = 0; i < bladeCount; i++) {
      final double theta = i * angleStep + rotationOffset;
      final double r1 = w * 0.38;
      final double r2 = w * 0.20;

      final p1 = Offset(center.dx + r1 * math.cos(theta), center.dy + r1 * math.sin(theta));
      final p2 = Offset(center.dx + r2 * math.cos(theta + 0.65), center.dy + r2 * math.sin(theta + 0.65));
      final p3 = Offset(center.dx + r1 * math.cos(theta + angleStep * 0.7), center.dy + r1 * math.sin(theta + angleStep * 0.7));

      final bladePath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      canvas.drawPath(bladePath, bladeFillPaint);
      canvas.drawPath(bladePath, bladePaint);
    }

    // 5. Digital Pixel Matrix (3x3 grid inside aperture core)
    final double pixelSize = w * 0.082;
    final double pixelSpacing = w * 0.105;

    for (int row = -1; row <= 1; row++) {
      for (int col = -1; col <= 1; col++) {
        final pxCenter = Offset(
          center.dx + col * pixelSpacing,
          center.dy + row * pixelSpacing,
        );

        final manhattan = row.abs() + col.abs();
        Color pxColor;
        if (manhattan == 0) {
          // Center pixel: High-intensity white/cyan sensor core
          pxColor = const Color(0xFFFFFFFF);
        } else if (manhattan == 1) {
          // 4-Neighbors: Vivid Cyan
          pxColor = const Color(0xFF38BDF8);
        } else {
          // 8-Neighbors: Purple
          pxColor = const Color(0xFFA78BFA);
        }

        final pxRect = Rect.fromCenter(
          center: pxCenter,
          width: pixelSize,
          height: pixelSize,
        );
        final pxRRect = RRect.fromRectAndRadius(pxRect, Radius.circular(pixelSize * 0.28));

        final pxPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = pxColor;
        canvas.drawRRect(pxRRect, pxPaint);
      }
    }

    // 6. Central Sensor Glow Pulse
    final coreGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          const Color(0xFF38BDF8).withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.14));
    canvas.drawCircle(center, w * 0.14, coreGlowPaint);
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.borderRadius != borderRadius;
  }
}
