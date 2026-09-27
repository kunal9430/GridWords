import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/brightness_controller.dart';
import 'services/profile_service.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the user's saved appearance preferences before first frame.
  ThemeController.instance.loadTheme();
  BrightnessController.instance.load();
  ProfileService.init();
  runApp(const GridWordGameApp());
}

class GridWordGameApp extends StatelessWidget {
  const GridWordGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    // Rebuilds whenever ANY appearance setting changes — mode, either
    // color theme, font family, or font size — since all of them feed
    // into the ThemeData built below.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<int>(
          valueListenable: controller.lightThemeIndex,
          builder: (context, lightIndex, _) {
            return ValueListenableBuilder<int>(
              valueListenable: controller.darkThemeIndex,
              builder: (context, darkIndex, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: controller.fontFamily,
                  builder: (context, fontFamily, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: controller.fontScale,
                      builder: (context, fontScale, _) {
                        // "System" mode always means the classic default
                        // look, regardless of whatever swatch was last
                        // picked for Light/Dark — only an explicit Light
                        // or Dark choice applies the user's color pick.
                        final lightTheme =
                            mode == ThemeMode.system ? AppTheme.originalLight : AppTheme.lightThemes[lightIndex];
                        final darkTheme =
                            mode == ThemeMode.system ? AppTheme.originalDark : AppTheme.darkThemes[darkIndex];
                        return MaterialApp(
                          title: 'Grid Words',
                          debugShowCheckedModeBanner: false,
                          theme: AppTheme.light(theme: lightTheme, fontFamily: fontFamily, fontScale: fontScale),
                          darkTheme: AppTheme.dark(theme: darkTheme, fontFamily: fontFamily, fontScale: fontScale),
                          themeMode: mode,
                          home: const SplashScreen(),
                          // Cross-fades colors/typography smoothly whenever
                          // the theme, font, or font size changes in
                          // Settings, instead of an abrupt jump-cut. The
                          // MediaQuery override applies the Settings
                          // font-size slider to EVERY Text widget in the
                          // app uniformly — including ones that set their
                          // own literal fontSize — since individual
                          // widgets can't all be trusted to read it off
                          // the theme themselves.
                          builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
                            child: AnimatedTheme(
                              data: Theme.of(context),
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                              child: child!,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
