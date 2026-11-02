import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/theme_controller.dart';
import 'package:maizedoctor/features/ai_assistant/views/assistant_view.dart';
import 'package:maizedoctor/features/ai_assistant/view_models/assistant_view_model.dart';
import '../support/design_fonts.dart';
import '../scans/widget_test.dart' show tapVisible;
import 'r04_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  for (final config in [
    ('r04-library-light', 'library', false, 412.0, 1400.0, 1.0),
    ('r04-library-dark', 'library', true, 360.0, 1400.0, 1.0),
    ('r04-detail-light', 'detail', false, 412.0, 1600.0, 1.0),
    ('r04-assistant-empty-light', 'empty', false, 360.0, 915.0, 1.0),
    ('r04-assistant-chat-dark', 'chat', true, 412.0, 1400.0, 1.0),
    ('r04-assistant-keyboard-2x', 'keyboard', false, 320.0, 915.0, 2.0),
    ('r04-gallery-light', 'gallery', false, 412.0, 1400.0, 1.0),
    ('r04-viewer-dark', 'viewer', true, 412.0, 915.0, 1.0),
  ]) {
    testWidgets(config.$1, (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(config.$4, config.$5);
      tester.platformDispatcher.textScaleFactorTestValue = config.$6;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final theme = ThemeController.system();
      await theme.setMode(config.$3 ? ThemeMode.dark : ThemeMode.light);
      addTearDown(theme.dispose);
      List<int>? image;
      if (config.$2 == 'gallery' || config.$2 == 'viewer') {
        image = await tester.runAsync(r04Image);
      }
      final assistant = ['empty', 'chat', 'keyboard'].contains(config.$2);
      final location = assistant
          ? AppRoutes.assistant
          : config.$2 == 'library'
          ? AppRoutes.knowledge
          : '${AppRoutes.knowledge}/common-rust';
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MainApp(
            initialLocation: location,
            themeController: theme,
            config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
            httpClient: r04Client(imageBytes: image, images: image != null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (config.$2 == 'chat') {
        await tester
            .element(find.byType(AssistantView))
            .read<AssistantViewModel>()
            .ask('UI fixture: what reviewed evidence is available?');
        await tester.pumpAndSettle();
        tester
            .widget<SingleChildScrollView>(
              find.byKey(const PageStorageKey('assistant-conversation')),
            )
            .controller!
            .jumpTo(0);
        await tester.pumpAndSettle();
      }
      if (config.$2 == 'keyboard') {
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('assistant-question')),
          'UI test draft\nSecond line',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('assistant-send')).hitTestable(),
          findsOneWidget,
        );
      }
      if (image != null) {
        final open = find.byKey(
          const ValueKey('reference-open-12345678-1234-4123-8123-123456789abc'),
        );
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        if (config.$2 == 'viewer') await tapVisible(tester, open);
      }
      await settleImages(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/${config.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
