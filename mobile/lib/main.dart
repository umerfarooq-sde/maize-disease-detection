import 'package:flutter/material.dart';
import 'app.dart';
import 'core/theme/theme_controller.dart';

export 'app.dart' show MainApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = await ThemeController.load(SharedPreferencesThemeStore());
  runApp(MainApp(themeController: theme));
}
