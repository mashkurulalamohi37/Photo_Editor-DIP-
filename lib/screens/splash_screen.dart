import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import 'editor_screen.dart';

/// Opening splash screen with animated branding, DIP mathematical aura,
/// and smooth transition to the main [EditorScreen].
class SplashScreen extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onFinished;

  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2200),
    this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _tagFade;
  late final Animation<double> _progressValue;

  Timer? _navigationTimer;
  bool _navigated = false;

  final List<String> _dipStages = const [
    'Sampling 2D Continuous Coordinates (x, y)...',
    'Quantizing Gray Levels (L = 2^k)...',
    'Initializing Spatial & Frequency Domains...',
    'Ready for Digital Image Processing.',
  ];
  int _currentStageIndex = 0;
  Timer? _stageTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _logoFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _titleFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.35, 0.70, curve: Curves.easeIn),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _tagFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.60, 0.90, curve: Curves.easeIn),
    );

    _progressValue = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.15, 0.95, curve: Curves.easeInOut),
    );

    _animController.forward();

    // Stage messages update every 500ms
    _stageTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      setState(() {
        if (_currentStageIndex < _dipStages.length - 1) {
          _currentStageIndex++;
        }
      });
    });

    _navigationTimer = Timer(widget.duration + const Duration(milliseconds: 200), () {
      _navigateToEditor();
    });
  }

  void _navigateToEditor() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _stageTimer?.cancel();
    _navigationTimer?.cancel();

    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const EditorScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _stageTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToEditor, // Tap to immediately skip intro
        child: Stack(
          children: [
            // 1. Subtle radial gradient spotlight
            Positioned(
              top: size.height * 0.25 - 180,
              left: size.width * 0.5 - 180,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.14),
                      const Color(0xFFA78BFA).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 2. Main Branding & Animated Elements
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated App Logo
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: const AppLogo(
                          size: 104,
                          showGlow: true,
                          animate: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // App Title
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFF38BDF8),
                                  Color(0xFF818CF8),
                                  Color(0xFFA78BFA),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'DIP Studio',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                'DIGITAL IMAGE PROCESSING LAB',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.4,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Subtitle feature highlights
                    FadeTransition(
                      opacity: _tagFade,
                      child: const Text(
                        'Sampling • Enhancement • Segmentation • Analysis',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                          letterSpacing: 0.8,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Bottom Loading & Skip Bar
            Positioned(
              left: 28,
              right: 28,
              bottom: 40,
              child: FadeTransition(
                opacity: _tagFade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // DIP Processing status text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _dipStages[_currentStageIndex],
                        key: ValueKey<int>(_currentStageIndex),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Animated progress indicator bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedBuilder(
                        animation: _progressValue,
                        builder: (context, _) {
                          return LinearProgressIndicator(
                            value: _progressValue.value,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF38BDF8),
                            ),
                            minHeight: 3.5,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tap to skip hint
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 13,
                          color: Colors.white30,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Tap anywhere to start',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white30,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
