import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/app_fonts.dart';

export 'app.dart' show MainApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  registerAppFontLicense();
  final theme = await ThemeController.load(SharedPreferencesThemeStore());
  runApp(MainApp(themeController: theme));
}
