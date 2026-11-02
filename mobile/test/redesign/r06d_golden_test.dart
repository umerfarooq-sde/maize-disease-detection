import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_fonts.dart';
import 'r06d_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  for (final entry in [
    ('accounts-light-phone', '/admin/farmers', false, 412.0, 1300.0),
    ('accounts-dark-tablet', '/admin/farmers', true, 1280.0, 1000.0),
    ('account-confirm-light', '/admin/farmers', false, 320.0, 1000.0),
    ('audit-light-phone', '/admin/audit', false, 412.0, 1400.0),
    ('audit-detail-dark', '/admin/audit', true, 1280.0, 1100.0),
    ('model-light-phone', '/admin/model-health', false, 412.0, 1600.0),
    ('model-evidence-dark', '/admin/model-health', true, 1280.0, 1200.0),
    ('model-runtime-dark', '/admin/model-health', true, 480.0, 1300.0),
    ('model-unavailable-light', '/admin/model-health', false, 320.0, 1200.0),
  ]) {
    testWidgets('R06D ${entry.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(entry.$4, entry.$5);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final fixture = R06DFixture();
      if (entry.$1.contains('unavailable')) {
        fixture.health['service'] = {
          'status': 'UNAVAILABLE',
          'configuredVersion': 'synthetic-v1',
          'registered': false,
          'matchesProduction': false,
          'data': null,
        };
      }
      final boundary = GlobalKey();
      await fixture.mount(
        tester,
        location: entry.$2,
        dark: entry.$3,
        boundary: boundary,
      );
      if (entry.$1 == 'accounts-dark-tablet' ||
          entry.$1.startsWith('account-confirm')) {
        await r06dTap(tester, find.text('Filter accounts'));
        if (entry.$1.startsWith('account-confirm')) {
          await r06dTap(tester, find.text('Set SUSPENDED'));
        }
      }
      if (entry.$1.startsWith('audit')) {
        await r06dTap(tester, find.text('Filter recorded events'));
        if (entry.$1.contains('detail')) {
          await r06dTap(tester, find.text('Recorded event details'));
        }
      }
      if (entry.$1 == 'model-evidence-dark') {
        await r06dTap(tester, find.text('Per-class test metrics'));
        await r06dTap(tester, find.text('Saved confusion matrix'));
        await tester.ensureVisible(find.text('Per-class test metrics'));
      }
      if (entry.$1 == 'model-runtime-dark') {
        await r06dTap(tester, find.text('Prediction distribution'));
        await tester.ensureVisible(find.text('Runtime operational statistics'));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/r06d-${entry.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
