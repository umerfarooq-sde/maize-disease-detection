import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/data/models/farmer_analytics.dart';
import 'package:maizedoctor/features/admin/views/admin_access_view.dart';
import 'package:maizedoctor/features/admin/view_models/admin_dashboard_view_model.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  for (final entry in [
    ('overview-light-phone', false, 412.0, 1500.0, 1.0),
    ('overview-dark-tablet', true, 1280.0, 1100.0, 1.0),
    ('navigation-light-320-2x', false, 320.0, 915.0, 2.0),
    ('operations-dark-phone', true, 412.0, 1500.0, 1.0),
    ('operations-chart-light', false, 412.0, 1500.0, 1.0),
    ('operations-unavailable-light', false, 360.0, 915.0, 1.0),
    ('overview-empty-dark', true, 412.0, 1500.0, 1.0),
    ('sign-in-light-320-2x', false, 320.0, 915.0, 2.0),
  ]) {
    testWidgets('R06A ${entry.$1}', (tester) async {
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
      final fixture = R06Fixture()
        ..empty = entry.$1 == 'overview-empty-dark'
        ..operationsUnavailable = entry.$1 == 'operations-unavailable-light';
      final boundary = GlobalKey();
      await fixture.mount(
        tester,
        dark: entry.$2,
        signedIn: !entry.$1.startsWith('sign-in'),
        boundary: boundary,
      );
      if (!entry.$1.startsWith('sign-in')) {
        // Use an explicit fixed reporting window for reproducible captures.
        final model = tester
            .element(
              find
                  .descendant(
                    of: find.byType(AdminAccessView),
                    matching: find.byType(ChoiceChip),
                  )
                  .first,
            )
            .read<AdminDashboardViewModel>();
        await model.load(
          range: AnalyticsDateRange(
            DateTime.utc(2026, 10, 1),
            DateTime.utc(2026, 10, 2),
          ),
        );
        await tester.pumpAndSettle();
        expect(model.data, isNotNull);
      }
      if (entry.$1.startsWith('operations')) {
        await fixture.go(tester, '/admin/ai-operations');
        if (entry.$1.contains('chart')) {
          await tester.ensureVisible(find.text('Daily operation activity'));
          await tester.pumpAndSettle();
        }
      }
      if (entry.$1.startsWith('navigation')) {
        await r06Tap(tester, find.byTooltip('Open Admin navigation'));
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/r06a-${entry.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
