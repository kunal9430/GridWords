import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the user's saved light/dark/system preference before first frame.
  ThemeController.instance.loadTheme();
  runApp(const GridWordGameApp());
}

class GridWordGameApp extends StatelessWidget {
  const GridWordGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Grid Words',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
