import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/app_fonts.dart';

export 'app.dart' show MainApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // If .env is missing or unreadable, continue with default unconfigured environment
  }
  registerAppFontLicense();
  final theme = await ThemeController.load(SharedPreferencesThemeStore());
  runApp(MainApp(themeController: theme));
}
