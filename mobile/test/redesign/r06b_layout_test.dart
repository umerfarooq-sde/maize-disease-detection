import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/features/admin/widgets/reference_editor.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';
import 'r06b_fixtures.dart';
import 'r06b_content_test.dart' show r06bEnter;

void main() {
  setUpAll(loadDesignFonts);
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
        'content lists, all editors and rights at ${width}dp / ${scale}x / both themes',
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
          final fixture = R06BFixture()..addMedia();
          fixture.media.first['imagePath'] = null;
          fixture.diseases.first['name'] =
              'Long synthetic catalogue display name for responsive verification';
          fixture.documents.first['title'] =
              'Long synthetic document title to verify wrapping across compact and expanded panes';
          await fixture.mount(tester, location: '/admin/manage?area=diseases');
          for (final dark in [false, true]) {
            await fixture.theme.setMode(
              dark ? ThemeMode.dark : ThemeMode.light,
            );
            await fixture.go(tester, '/admin/manage?area=diseases');
            await r06bEditDisease(tester, 'Common_Rust');
            await tester.ensureVisible(find.text('Save display metadata'));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Disease editor $dark',
            );
            await r06Tap(tester, find.text('Cancel editing'));
            await fixture.go(tester, '/admin/manage');
            await r06Tap(tester, find.text('New version from this'));
            await tester.ensureVisible(
              find.byKey(const Key('management-content')),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Save draft'));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Knowledge editor $dark',
            );
            await r06Tap(tester, find.text('Cancel editing'));
            await fixture.go(tester, '/admin/reference-images');
            await r06Tap(tester, find.text('Source & rights'));
            await tester.ensureVisible(find.text('Retire and clean'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'Media card $dark');
            await r06Tap(
              tester,
              find.text('Edit metadata / reorder / replace'),
            );
            expect(find.byType(ReferenceEditor), findsOneWidget);
            await tester.ensureVisible(
              find.text('Save reviewed draft metadata'),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Media editor $dark',
            );
            await r06Tap(tester, find.text('Cancel editing'));
          }
          expect(fixture.writes, isEmpty);
        },
      );
    }
  }
  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets(
      'keyboard and long HTTPS reference remain scrollable at $size / 200%',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final fixture = R06BFixture();
        await fixture.mount(tester, location: '/admin/manage');
        await r06Tap(tester, find.text('New version from this'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await r06bEnter(
          tester,
          'management-source.url',
          'https://example.invalid/${'long-reviewed-source-path/' * 30}',
        );
        await tester.ensureVisible(find.text('Save draft'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Save draft')).bottom,
          lessThanOrEqualTo(size.height - 160),
        );
        expect(tester.takeException(), isNull);
        expect(fixture.writes, isEmpty);
      },
    );
  }
  testWidgets('content controls are labelled and have Android touch targets', (
    tester,
  ) async {
    final fixture = R06BFixture();
    await fixture.mount(tester, location: '/admin/manage');
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await r06Tap(tester, find.text('New reviewed draft'));
    expect(find.bySemanticsLabel('Title (required)'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Authors (one per line, up to 16) (optional)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
