import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/theme_controller.dart';
import '../auth/session_test.dart' show response;
import '../scans/helpers.dart' show FakeScanRepository;
import '../support/design_fonts.dart';

void main() {
  setUpAll(loadDesignFonts);
  for (final config in [
    ('navigation-light-320-2x', AppRoutes.home, 320.0, 2.0, ThemeMode.light),
    ('sign-in-light-360', AppRoutes.auth, 360.0, 1.0, ThemeMode.light),
    ('register-dark-360', AppRoutes.register, 360.0, 1.0, ThemeMode.dark),
    ('admin-dark-360', AppRoutes.admin, 360.0, 1.0, ThemeMode.dark),
  ]) {
    testWidgets(config.$1, (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(config.$3, 915);
      tester.platformDispatcher.textScaleFactorTestValue = config.$4;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final theme = ThemeController.system();
      await theme.setMode(config.$5);
      addTearDown(theme.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MainApp(
            themeController: theme,
            initialLocation: config.$2,
            scanRepository: FakeScanRepository(),
            config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
            httpClient: MockClient((_) async => response(null, status: 503)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/${config.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
