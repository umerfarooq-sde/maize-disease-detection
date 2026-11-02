import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';
import 'r06b_content_test.dart' show r06bEnter;
import 'r06c_fixtures.dart';

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
        'calculator lists/editors ${width}dp ${scale}x, all four areas and both themes',
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
          final fixture = R06CFixture();
          fixture.records[ManagementArea.fertilizers]!['title'] =
              'Synthetic long fertilizer product name for responsive layout verification';
          await fixture.mount(
            tester,
            location: '/admin/manage?area=fertilizers',
          );
          for (final dark in [false, true]) {
            await fixture.theme.setMode(
              dark ? ThemeMode.dark : ThemeMode.light,
            );
            for (final area in [
              ManagementArea.fertilizers,
              ManagementArea.fertilizer,
              ManagementArea.yieldRules,
              ManagementArea.modelSpecifications,
            ]) {
              await fixture.go(tester, '/admin/manage?area=${area.name}');
              await r06Tap(
                tester,
                find.text(
                  area == ManagementArea.fertilizers
                      ? 'Edit product metadata'
                      : 'New version from this',
                ),
              );
              final save = area == ManagementArea.fertilizers
                  ? 'Save product metadata'
                  : 'Save draft';
              await tester.ensureVisible(find.text(save));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${area.name} $dark',
              );
              if (area == ManagementArea.modelSpecifications) {
                await r06Tap(tester, find.text('Advanced JSON · coefficients'));
                await tester.ensureVisible(
                  find.byKey(const Key('management-coefficients')),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
              await r06Tap(tester, find.text('Cancel editing'));
              expect(find.text('Leave unsaved changes?'), findsNothing);
            }
          }
          expect(fixture.writes, isEmpty);
        },
      );
    }
  }
  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets(
      'numeric keyboard and large rate remain reachable at $size / 200%',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final fixture = R06CFixture();
        await fixture.mount(tester, location: '/admin/manage?area=fertilizer');
        await r06Tap(tester, find.text('New version from this'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await r06bEnter(tester, 'management-rate', '999999.123456');
        await tester.ensureVisible(find.text('Save draft'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Save draft')).bottom,
          lessThanOrEqualTo(size.height - 160),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'composition and structured controls are labelled and meet touch-target guidance',
    (tester) async {
      final fixture = R06CFixture();
      await fixture.mount(tester, location: '/admin/manage?area=fertilizers');
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(
        find.bySemanticsLabel(RegExp('Composition, percent by mass')),
        findsOneWidget,
      );
      await fixture.go(tester, '/admin/manage?area=modelSpecifications');
      await r06Tap(tester, find.text('New version from this'));
      await tester.ensureVisible(find.text('Add input'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );
}
