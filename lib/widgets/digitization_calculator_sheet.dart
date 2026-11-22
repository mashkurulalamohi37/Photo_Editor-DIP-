import 'package:flutter/material.dart';

class DigitizationCalculatorSheet extends StatefulWidget {
  const DigitizationCalculatorSheet({super.key});

  @override
  State<DigitizationCalculatorSheet> createState() =>
      _DigitizationCalculatorSheetState();
}

class _DigitizationCalculatorSheetState
    extends State<DigitizationCalculatorSheet> {
  int _mWidth = 1024;
  int _nHeight = 1024;
  int _kBits = 8;

  static const List<int> _presetDimensions = [
    128,
    256,
    512,
    1024,
    1920,
    2048,
    4096,
  ];

  static const List<Map<String, String>> _dipSteps = [
    {
      'step': '1. Image Acquisition',
      'desc': 'Capture & digitize (sampling + quantization)',
      'analogy': 'Taking the photo',
    },
    {
      'step': '2. Preprocessing / Enhancement',
      'desc': 'Improve contrast, remove noise (Point Ops, Hist Eq)',
      'analogy': 'Cleaning a dirty window',
    },
    {
      'step': '3. Image Restoration',
      'desc': 'Reverse known degradation (blur, impulse/Gaussian noise)',
      'analogy': 'Repairing an old photo',
    },
    {
      'step': '4. Color Processing',
      'desc': 'Work with RGB, HSV, Luminance color spaces',
      'analogy': 'Choosing the right lens filter',
    },
    {
      'step': '5. Wavelets / Multiresolution',
      'desc': 'Analyze image structures at multiple spatial scales',
      'analogy': 'Zooming in and out',
    },
    {
      'step': '6. Compression',
      'desc': 'Reduce storage size & redundancy',
      'analogy': 'Zipping a file',
    },
    {
      'step': '7. Morphological Processing',
      'desc': 'Shape-based operations (Erosion & Dilation)',
      'analogy': 'Shrinking or growing shapes',
    },
    {
      'step': '8. Segmentation',
      'desc': 'Partition image into regions/objects (Otsu, Canny, K-Means)',
      'analogy': 'Cutting a cake into slices',
    },
    {
      'step': '9. Representation & Description',
      'desc': 'Extract boundary & regional quantitative features',
      'analogy': 'Describing each slice',
    },
    {
      'step': '10. Object Recognition',
      'desc': 'Assign labels to detected objects',
      'analogy': 'Naming each slice',
    },
  ];

  String _formatInt(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final grayLevels = 1 << _kBits;
    final totalPixels = _mWidth * _nHeight;
    final totalBits = totalPixels * _kBits;
    final totalBytes = totalBits / 8.0;
    final totalKB = totalBytes / 1024.0;
    final totalMB = totalKB / 1024.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF11151E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calculate_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Digitization Calculator & DIP Core Reference',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                  children: [

              // Worked Example & Live M x N x k Calculator Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A202E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Image Storage Formula: b = M × N × k',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              _mWidth = 1024;
                              _nHeight = 1024;
                              _kBits = 8;
                            });
                          },
                          icon: const Icon(Icons.restore, size: 14),
                          label: const Text(
                            '1024×1024×8 (1 MB)',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sampling sets spatial resolution (M × N = ${_formatInt(totalPixels)} px)\n'
                      'Quantization sets gray levels (L = 2^$_kBits = $grayLevels levels)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dimension Presets
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _presetDimensions.map((dim) {
                        final selected = _mWidth == dim && _nHeight == dim;
                        return ChoiceChip(
                          label: Text(
                            '$dim×$dim',
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _mWidth = dim;
                              _nHeight = dim;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Bit Depth k Slider
                    Row(
                      children: [
                        const Text(
                          'Bit Depth (k):',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        Expanded(
                          child: Slider(
                            value: _kBits.toDouble(),
                            min: 1,
                            max: 16,
                            divisions: 15,
                            label: '$_kBits bits (L = $grayLevels)',
                            onChanged: (v) =>
                                setState(() => _kBits = v.round()),
                          ),
                        ),
                        Text(
                          'k = $_kBits bits',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const Divider(color: Colors.white12, height: 16),

                    // Calculation Output Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E121A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_mWidth × $_nHeight × $_kBits = ${_formatInt(totalBits)} bits',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34D399),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Grayscale Size: ${_formatInt(totalBytes.round())} Bytes '
                            '(${totalKB.toStringAsFixed(1)} KB / ${totalMB.toStringAsFixed(3)} MB)\n'
                            '• 3-Channel RGB Size (3k): ${(totalMB * 3).toStringAsFixed(3)} MB',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                '10 Fundamental Steps in Digital Image Processing',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ..._dipSteps.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171C28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['step']!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item['desc']} — Analogy: "${item['analogy']}"',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
      },
    );
  }
}
