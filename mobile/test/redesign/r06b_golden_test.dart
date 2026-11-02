import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_fonts.dart';
import 'r04_fixtures.dart' show r04Image, settleImages;
import 'r06a_fixtures.dart';
import 'r06b_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  for (final entry in [
    ('diseases-light-phone', false, 412.0, 1200.0, 1.0),
    ('knowledge-dark-tablet', true, 1280.0, 1100.0, 1.0),
    ('knowledge-editor-light', false, 480.0, 1400.0, 1.0),
    ('knowledge-sources-dark', true, 480.0, 1400.0, 1.0),
    ('healthy-editor-light', false, 412.0, 1400.0, 1.0),
    ('reference-light-phone', false, 412.0, 1400.0, 1.0),
    ('reference-editor-dark', true, 480.0, 1400.0, 1.0),
    ('reference-empty-dark-320-2x', true, 320.0, 1100.0, 2.0),
  ]) {
    testWidgets('R06B ${entry.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(entry.$3, entry.$4);
      tester.platformDispatcher.textScaleFactorTestValue = entry.$5;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final fixture = R06BFixture();
      if (entry.$1.startsWith('reference') && !entry.$1.contains('empty')) {
        fixture.addMedia();
        fixture.image = await tester.runAsync(r04Image);
      }
      final reference = entry.$1.startsWith('reference');
      final disease =
          entry.$1.startsWith('diseases') || entry.$1.startsWith('healthy');
      final boundary = GlobalKey();
      await fixture.mount(
        tester,
        location: reference
            ? '/admin/reference-images'
            : disease
            ? '/admin/manage?area=diseases'
            : '/admin/manage',
        dark: entry.$2,
        boundary: boundary,
      );
      if (entry.$1.startsWith('knowledge-editor') ||
          entry.$1.startsWith('knowledge-sources')) {
        await r06Tap(tester, find.text('New version from this'));
        if (entry.$1.contains('sources')) {
          await tester.ensureVisible(find.text('Source & applicability'));
        }
      } else if (entry.$1.startsWith('healthy')) {
        await r06bEditDisease(tester, 'Healthy');
      } else if (entry.$1.startsWith('reference-editor')) {
        await r06Tap(tester, find.text('Edit metadata / reorder / replace'));
        await tester.ensureVisible(find.text('Usage rights'));
      } else if (entry.$1.contains('empty')) {
        await tester.ensureVisible(find.text('No reference images'));
      }
      await tester.pumpAndSettle();
      if (fixture.image != null) await settleImages(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/r06b-${entry.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
