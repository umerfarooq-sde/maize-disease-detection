import 'package:flutter/material.dart';
import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/app_fonts.dart';

export 'app.dart' show MainApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAppFontLicense();
  final theme = await ThemeController.load(SharedPreferencesThemeStore());
  runApp(MainApp(themeController: theme));
}
