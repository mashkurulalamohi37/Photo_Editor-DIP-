import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pixel_image.dart';

class HistogramChart extends StatefulWidget {
  final HistogramData histogram;
  final int? activeThreshold;
  final bool compact;

  const HistogramChart({
    super.key,
    required this.histogram,
    this.activeThreshold,
    this.compact = false,
  });

  @override
  State<HistogramChart> createState() => _HistogramChartState();
}

class _HistogramChartState extends State<HistogramChart> {
  bool _showRgbChannels = true;

  @override
  Widget build(BuildContext context) {
    final h = widget.histogram;
    return Container(
      padding: EdgeInsets.all(widget.compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Intensity Histogram (0–255)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _showRgbChannels = !_showRgbChannels),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _showRgbChannels
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _showRgbChannels ? 'RGB + Lum' : 'Lum Only',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _showRgbChannels
                          ? const Color(0xFF38BDF8)
                          : Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: widget.compact ? 74 : 96,
            width: double.infinity,
            child: CustomPaint(
              painter: _HistogramPainter(
                histogram: h,
                showRgb: _showRgbChannels,
                thresholdMarker: widget.activeThreshold ?? h.otsuThreshold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _StatBadge(
                label: 'Mean μ',
                value: h.meanIntensity.toStringAsFixed(1),
                color: const Color(0xFF38BDF8),
              ),
              _StatBadge(
                label: 'Std σ',
                value: h.stdDevIntensity.toStringAsFixed(1),
                color: const Color(0xFFA78BFA),
              ),
              _StatBadge(
                label: 'Range',
                value: '[${h.minIntensity}..${h.maxIntensity}]',
                color: const Color(0xFF34D399),
              ),
              _StatBadge(
                label: 'Otsu T*',
                value: '${h.otsuThreshold}',
                color: const Color(0xFFFBBF24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _HistogramPainter extends CustomPainter {
  final HistogramData histogram;
  final bool showRgb;
  final int? thresholdMarker;

  _HistogramPainter({
    required this.histogram,
    required this.showRgb,
    this.thresholdMarker,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Baseline grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), gridPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);

    int maxCount = 1;
    for (int i = 0; i < 256; i++) {
      maxCount = math.max(maxCount, histogram.luminance[i]);
      if (showRgb) {
        maxCount = math.max(maxCount, histogram.red[i]);
        maxCount = math.max(maxCount, histogram.green[i]);
        maxCount = math.max(maxCount, histogram.blue[i]);
      }
    }

    // Use soft square-root scaling so smaller peaks remain clearly visible
    final normDenom = math.sqrt(maxCount.toDouble());

    if (showRgb) {
      _drawChannelCurve(
        canvas,
        size,
        histogram.red,
        normDenom,
        const Color(0xFFEF4444),
        fillAlpha: 0.10,
      );
      _drawChannelCurve(
        canvas,
        size,
        histogram.green,
        normDenom,
        const Color(0xFF22C55E),
        fillAlpha: 0.10,
      );
      _drawChannelCurve(
        canvas,
        size,
        histogram.blue,
        normDenom,
        const Color(0xFF3B82F6),
        fillAlpha: 0.10,
      );
    }

    _drawChannelCurve(
      canvas,
      size,
      histogram.luminance,
      normDenom,
      Colors.white,
      fillAlpha: showRgb ? 0.14 : 0.28,
      strokeWidth: 1.5,
    );

    // Draw Otsu / active threshold vertical indicator
    if (thresholdMarker != null) {
      final tx = (thresholdMarker!.clamp(0, 255) / 255.0) * size.width;
      final markerPaint = Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.75)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(tx, 0), Offset(tx, size.height), markerPaint);
    }
  }

  void _drawChannelCurve(
    Canvas canvas,
    Size size,
    List<int> bins,
    double normDenom,
    Color color, {
    double fillAlpha = 0.15,
    double strokeWidth = 1.1,
  }) {
    final path = Path()..moveTo(0, size.height);
    final linePath = Path();

    for (int i = 0; i < 256; i++) {
      final x = (i / 255.0) * size.width;
      final ratio = (math.sqrt(bins[i].toDouble()) / normDenom).clamp(0.0, 1.0);
      final y = size.height - ratio * (size.height - 2);
      path.lineTo(x, y);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    path.lineTo(size.width, size.height);
    path.close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: fillAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter oldDelegate) {
    return oldDelegate.histogram != histogram ||
        oldDelegate.showRgb != showRgb ||
        oldDelegate.thresholdMarker != thresholdMarker;
  }
}
