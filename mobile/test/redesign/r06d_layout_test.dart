import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_fonts.dart';
import 'r06d_fixtures.dart';

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
        'R06D ${width}dp ${scale}x all modules both themes, long records and reduced motion',
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
          final fixture = R06DFixture()..longValues = true;
          await fixture.mount(tester, location: '/admin/farmers');
          for (final dark in [false, true]) {
            await fixture.theme.setMode(
              dark ? ThemeMode.dark : ThemeMode.light,
            );
            await fixture.go(tester, '/admin/farmers');
            await r06dTap(tester, find.text('Filter accounts'));
            await r06dTap(tester, find.text('Account details'));
            await r06dReveal(tester, find.text('Set SUSPENDED'));
            expect(tester.takeException(), isNull, reason: 'farmer $dark');
            await fixture.go(tester, '/admin/audit');
            await r06dTap(tester, find.text('Filter recorded events'));
            await r06dTap(tester, find.text('Recorded event details'));
            await r06dReveal(
              tester,
              find.textContaining('does not establish success'),
            );
            expect(tester.takeException(), isNull, reason: 'audit $dark');
            await fixture.go(tester, '/admin/model-health');
            for (final section in [
              'Per-class test metrics',
              'Saved confusion matrix',
              'Evaluation provenance',
              'Prediction distribution',
              'Technical details and registry',
            ]) {
              await r06dTap(tester, find.text(section));
            }
            await r06dReveal(tester, find.textContaining('Status: VALIDATED'));
            expect(tester.takeException(), isNull, reason: 'health $dark');
          }
          expect(
            fixture.requests
                .where((r) => r.url.path.contains('/admin/'))
                .every((r) => r.method == 'GET'),
            true,
          );
        },
      );
    }
  }
  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets(
      'R06D filters and confirmation fit keyboard/landscape $size at 200%',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final fixture = R06DFixture();
        await fixture.mount(tester, location: '/admin/farmers');
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await r06dReveal(tester, find.byKey(const Key('farmer-account-email')));
        await tester.enterText(
          find.byKey(const Key('farmer-account-email')),
          'farmer@example.test',
        );
        await r06dTap(tester, find.text('Apply / refresh accounts'));
        await r06dTap(tester, find.text('Set SUSPENDED'));
        expect(find.text('Confirm status change'), findsOneWidget);
        await tester.ensureVisible(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(fixture.requests.where((r) => r.method == 'PATCH'), isEmpty);
        await fixture.go(tester, '/admin/audit');
        await r06dReveal(tester, find.byKey(const Key('audit-from')));
        await tester.enterText(
          find.byKey(const Key('audit-from')),
          '2026-10-15',
        );
        await r06dReveal(tester, find.byKey(const Key('audit-to')));
        await tester.enterText(find.byKey(const Key('audit-to')), '2026-10-15');
        await r06dTap(tester, find.byKey(const Key('audit-filter')));
        expect(fixture.requests.last.url.queryParameters['to'], '2026-10-15');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'account actions and audit/model disclosure have labels, contextual semantics and 48dp targets',
    (tester) async {
      final fixture = R06DFixture();
      await fixture.mount(tester, location: '/admin/farmers');
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await r06dTap(tester, find.text('Filter accounts'));
      await r06dReveal(tester, find.text('Set SUSPENDED'));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await fixture.go(tester, '/admin/model-health');
      await r06dTap(tester, find.text('Saved confusion matrix'));
      expect(
        find.bySemanticsLabel('Actual Common Rust, predicted Common Rust: 1'),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );
}
