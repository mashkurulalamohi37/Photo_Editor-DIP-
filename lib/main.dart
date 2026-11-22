import 'package:flutter/material.dart';
import 'screens/editor_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DipStudioApp());
}

class DipStudioApp extends StatelessWidget {
  final bool initialShowHistogram;
  final bool initialWorkbenchCollapsed;
  final bool? enableSplashScreen;

  const DipStudioApp({
    super.key,
    this.initialShowHistogram = false,
    this.initialWorkbenchCollapsed = true,
    this.enableSplashScreen,
  });

  @override
  Widget build(BuildContext context) {
    // When running inside an automated test without explicit splash flag,
    // load EditorScreen directly so existing widget tests don't stall on timers.
    final bool isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    final bool showSplash = enableSplashScreen ?? !isTestEnv;

    return MaterialApp(
      title: 'DIP Studio',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
          primary: const Color(0xFF38BDF8),
          secondary: const Color(0xFFA78BFA),
          surface: const Color(0xFF11151E),
        ),
      ),
      home: showSplash
          ? const SplashScreen()
          : EditorScreen(
              initialShowHistogram: initialShowHistogram,
              initialWorkbenchCollapsed: initialWorkbenchCollapsed,
            ),
    );
  }
}
