import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/theme_controller.dart';
import 'package:maizedoctor/features/shell/views/farmer_shell.dart';
import '../auth/session_test.dart' show response;
import '../scans/helpers.dart' show FakeScanRepository;
import '../support/design_fonts.dart';

void main() {
  setUpAll(loadDesignFonts);
  for (final width in [320.0, 360.0, 412.0, 480.0, 600.0, 840.0, 1024.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'R-02 light/dark $width dp at $scale text, auth keyboard and tab labels',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 915);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final theme = ThemeController.system();
          addTearDown(theme.dispose);
          await tester.pumpWidget(
            MainApp(
              themeController: theme,
              scanRepository: FakeScanRepository(),
              config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
              httpClient: MockClient((_) async => response(null, status: 503)),
            ),
          );
          await tester.pumpAndSettle();
          final router = GoRouter.of(tester.element(find.byType(FarmerShell)));
          for (final mode in [ThemeMode.light, ThemeMode.dark]) {
            await theme.setMode(mode);
            router.go(AppRoutes.assistant);
            await tester.pumpAndSettle();
            if (width < 840) {
              final bar = tester.widget<NavigationBar>(
                find.byType(NavigationBar),
              );
              expect(bar.destinations, hasLength(5));
              expect(
                bar.labelBehavior,
                NavigationDestinationLabelBehavior.alwaysShow,
              );
              expect(find.byTooltip('AI Assistant'), findsOneWidget);
              expect(
                tester
                    .getSize(find.byKey(const ValueKey('farmer-tab-3')))
                    .width,
                greaterThanOrEqualTo(48),
              );
            } else {
              expect(
                tester
                    .widget<NavigationRail>(find.byType(NavigationRail))
                    .destinations,
                hasLength(5),
              );
            }
            for (final route in [
              AppRoutes.auth,
              AppRoutes.register,
              AppRoutes.admin,
            ]) {
              router.go(route);
              await tester.pumpAndSettle();
              tester.view.viewInsets = const FakeViewPadding(bottom: 280);
              await tester.pumpAndSettle();
              final fields = find.byType(TextFormField);
              expect(fields, findsNWidgets(2));
              await tester.ensureVisible(fields.last);
              await tester.tap(fields.last);
              await tester.enterText(fields.last, 'six🌽🌽🌽');
              await tester.pumpAndSettle();
              final editor = find.descendant(
                of: fields.last,
                matching: find.byType(EditableText),
              );
              await tester.ensureVisible(editor);
              await tester.pumpAndSettle();
              expect(
                editor.hitTestable(),
                findsOneWidget,
                reason: '$route $mode $width $scale',
              );
              expect(
                tester.takeException(),
                isNull,
                reason: '$route $mode $width $scale',
              );
              FocusManager.instance.primaryFocus?.unfocus();
              tester.view.viewInsets = const FakeViewPadding();
              await tester.pumpAndSettle();
            }
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
