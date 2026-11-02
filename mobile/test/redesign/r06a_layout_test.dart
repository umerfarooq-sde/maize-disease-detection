import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/features/admin/widgets/admin_metric_grid.dart';
import 'package:maizedoctor/features/admin/widgets/admin_navigation.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';
import 'r06a_navigation_test.dart' show selectAdmin;

void main() {
  setUpAll(loadDesignFonts);
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  });
  for (final width in [
    320.0,
    360.0,
    412.0,
    480.0,
    600.0,
    840.0,
    1024.0,
    1280.0,
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'R06A $width / $scale light-dark overview, operations and full navigation',
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
          final fixture = R06Fixture()
            ..longIdentity = true
            ..largeCounts = true;
          await fixture.mount(tester);
          for (final mode in [ThemeMode.light, ThemeMode.dark]) {
            await fixture.theme.setMode(mode);
            await fixture.go(tester, '/admin');
            expect(
              tester
                  .widgetList<AdminMetricCard>(find.byType(AdminMetricCard))
                  .first
                  .value,
              '9007199254740991',
            );
            await r06Tap(tester, find.text('Scan trends and model labels'));
            await tester.ensureVisible(find.text('Model label distribution'));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Overview $width $scale $mode',
            );
            await fixture.go(tester, '/admin/ai-operations');
            await r06Tap(tester, find.text('AI service operations'));
            await r06Tap(tester, find.text('Provider calls'));
            await tester.ensureVisible(find.text('Daily operation activity'));
            await tester.pumpAndSettle();
            expect(find.text('PROVIDER · GEMINI'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Operations $width $scale $mode',
            );
            await selectAdmin(tester, AdminDestination.modelReview);
            expect(
              fixture.router.state.uri.queryParameters['area'],
              'modelSpecifications',
            );
            expect(find.text('Knowledge & configuration'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Long destination $width $scale $mode',
            );
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets(
      'Admin sign-in keyboard and landscape remain usable at $size / 200%',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final fixture = R06Fixture();
        await fixture.mount(tester, signedIn: false);
        await tester.ensureVisible(find.byKey(const Key('admin-email')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('admin-email')),
          'admin@example.test',
        );
        await tester.ensureVisible(find.byKey(const Key('admin-password')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('admin-password')),
          'synthetic password',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Sign in as Admin'));
        await tester.pumpAndSettle();
        expect(
          find.text('Sign in as Admin').hitTestable(),
          findsOneWidget,
          reason:
              'button=${tester.getRect(find.text('Sign in as Admin'))}; bars=${tester.widgetList<AppBar>(find.byType(AppBar)).map((bar) => bar.toolbarHeight)}; scrolls=${tester.widgetList<Scrollable>(find.byType(Scrollable)).length}',
        );
        expect(tester.takeException(), isNull);
        expect(fixture.requests, isEmpty);
      },
    );
  }
}
