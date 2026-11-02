import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';
import 'r06c_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  for (final entry in [
    ('product-light-phone', ManagementArea.fertilizers, false, 412.0, 1300.0),
    (
      'frozen-product-dark-tablet',
      ManagementArea.fertilizers,
      true,
      1280.0,
      1100.0,
    ),
    ('fertilizer-light-phone', ManagementArea.fertilizer, false, 412.0, 1400.0),
    ('yield-dark-phone', ManagementArea.yieldRules, true, 412.0, 1400.0),
    (
      'composition-editor-light',
      ManagementArea.fertilizers,
      false,
      480.0,
      1400.0,
    ),
    ('rate-editor-dark', ManagementArea.fertilizer, true, 480.0, 1400.0),
    (
      'specification-structured-light',
      ManagementArea.modelSpecifications,
      false,
      480.0,
      1400.0,
    ),
    (
      'specification-json-dark',
      ManagementArea.modelSpecifications,
      true,
      480.0,
      1400.0,
    ),
  ]) {
    testWidgets('R06C ${entry.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(entry.$4, entry.$5);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final fixture = R06CFixture();
      if (entry.$1.startsWith('frozen')) {
        fixture.records[entry.$2]!['contentEditable'] = false;
      }
      final boundary = GlobalKey();
      await fixture.mount(
        tester,
        location: '/admin/manage?area=${entry.$2.name}',
        dark: entry.$3,
        boundary: boundary,
      );
      if (entry.$1.contains('editor') || entry.$1.startsWith('specification')) {
        await r06Tap(
          tester,
          find.text(
            entry.$2 == ManagementArea.fertilizers
                ? 'Edit product metadata'
                : 'New version from this',
          ),
        );
        if (entry.$1.startsWith('composition')) {
          await tester.ensureVisible(find.text('Nutrient composition'));
        }
        if (entry.$1.startsWith('rate')) {
          await tester.ensureVisible(find.text('Application rate'));
        }
        if (entry.$1.contains('structured')) {
          await tester.ensureVisible(find.text('Input definitions'));
        }
        if (entry.$1.contains('json')) {
          await r06Tap(tester, find.text('Advanced JSON · coefficients'));
          await tester.ensureVisible(find.text('Coefficients'));
        }
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/r06c-${entry.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
