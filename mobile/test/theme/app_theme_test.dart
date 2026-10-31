import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/core/theme/design_tokens.dart';
import 'package:maizedoctor/core/theme/theme_controller.dart';
import 'package:maizedoctor/core/widgets/theme_mode_selector.dart';

class _FakeThemeStore implements ThemePreferenceStore {
  _FakeThemeStore([this.value]);
  String? value;

  @override
  Future<String?> readThemeMode() async => value;

  @override
  Future<void> writeThemeMode(String value) async {
    this.value = value;
  }
}

double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final dark = identical(light, foreground) ? background : foreground;
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}

void main() {
  test(
    'themes expose adaptive semantic roles and accessible body contrast',
    () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final scheme = theme.colorScheme;
        final semantic = theme.extension<AppSemanticColors>();
        expect(theme.useMaterial3, isTrue);
        expect(semantic, isNotNull);
        expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(7));
        expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
        expect(
          _contrast(semantic!.onWarningContainer, semantic.warningContainer),
          greaterThan(4.5),
        );
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      }
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    },
  );

  test(
    'theme preference loads, falls back safely and persists selection',
    () async {
      final store = _FakeThemeStore('dark');
      final controller = await ThemeController.load(store);
      expect(controller.mode, ThemeMode.dark);

      await controller.setMode(ThemeMode.light);
      expect(controller.mode, ThemeMode.light);
      expect(store.value, 'light');

      final invalid = await ThemeController.load(_FakeThemeStore('unknown'));
      expect(invalid.mode, ThemeMode.system);
    },
  );

  testWidgets('system mode follows platform brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: Builder(
          builder: (context) => Text(
            Theme.of(context).brightness.name,
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    expect(find.text('dark'), findsOneWidget);
  });

  testWidgets('appearance selector updates the shared controller', (
    tester,
  ) async {
    final controller = ThemeController.system();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const Scaffold(body: ThemeModeSelector()),
        ),
      ),
    );
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(controller.mode, ThemeMode.dark);
  });
}
