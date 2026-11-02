import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/theme_controller.dart';
import 'package:maizedoctor/features/disease_knowledge/views/knowledge_view.dart';
import 'package:maizedoctor/features/ai_assistant/views/assistant_view.dart';
import 'package:maizedoctor/features/ai_assistant/view_models/assistant_view_model.dart';
import '../support/design_fonts.dart';
import '../scans/helpers.dart' show leafImage;
import '../scans/widget_test.dart' show tapVisible;
import 'r04_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  for (final width in [320.0, 360.0, 412.0, 480.0, 600.0, 840.0, 1024.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'R04 $width / $scale light-dark Knowledge, detail, focus and pinned keyboard composer',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 915);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
          });
          final theme = ThemeController.system();
          addTearDown(theme.dispose);
          await tester.pumpWidget(
            MainApp(
              initialLocation: AppRoutes.knowledge,
              themeController: theme,
              config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
              httpClient: r04Client(imageBytes: leafImage.bytes, images: true),
            ),
          );
          await tester.pumpAndSettle();
          final router = GoRouter.of(
            tester.element(find.byType(KnowledgeView)),
          );
          for (final mode in [ThemeMode.light, ThemeMode.dark]) {
            await theme.setMode(mode);
            router.go(AppRoutes.knowledge);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('knowledge-healthy')),
              findsOneWidget,
            );
            expect(find.text('Healthy / scouting'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Catalogue $width $scale $mode',
            );
            router.go('${AppRoutes.knowledge}/common-rust');
            await tester.pumpAndSettle();
            await tapVisible(
              tester,
              find.byKey(
                const ValueKey(
                  'section-link-22345678-1234-4123-8123-123456789abc',
                ),
              ),
            );
            expect(
              find.text('UI fixture prevention').hitTestable(),
              findsOneWidget,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'Detail $width $scale $mode',
            );
            await tapVisible(
              tester,
              find.byKey(
                const ValueKey(
                  'reference-open-12345678-1234-4123-8123-123456789abc',
                ),
              ),
            );
            expect(
              find.byKey(const Key('reference-image-zoom')),
              findsOneWidget,
            );
            await tester.ensureVisible(find.text('Copy source URL').last);
            await tester.pumpAndSettle();
            expect(
              find.byTooltip('Close reference image').hitTestable(),
              findsOneWidget,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'Viewer $width $scale $mode',
            );
            await tester.tap(find.byTooltip('Close reference image'));
            await tester.pumpAndSettle();
            router.go(AppRoutes.assistant);
            await tester.pumpAndSettle();
            final model = tester
                .element(find.byType(AssistantView))
                .read<AssistantViewModel>();
            await model.ask('UI fixture question about maize');
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('assistant-focus')));
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byType(DropdownButtonFormField<String>).last,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'Focus $width $scale $mode',
            );
            await tester.tap(find.byTooltip('Close focus controls'));
            await tester.pumpAndSettle();
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            await tester.pumpAndSettle();
            final field = find.byKey(const Key('assistant-question'));
            await tester.tap(field);
            await tester.enterText(
              field,
              'A multiline draft\nSecond line\nThird line\nFourth line',
            );
            await tester.pumpAndSettle();
            expect(field.hitTestable(), findsOneWidget);
            final send = find.byKey(const Key('assistant-send'));
            expect(send.hitTestable(), findsOneWidget);
            expect(tester.getBottomRight(send).dy, lessThanOrEqualTo(635));
            expect(
              tester.takeException(),
              isNull,
              reason: 'Composer $width $scale $mode',
            );
            FocusManager.instance.primaryFocus?.unfocus();
            tester.view.viewInsets = const FakeViewPadding();
            await tester.pumpAndSettle();
            model.clear();
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
