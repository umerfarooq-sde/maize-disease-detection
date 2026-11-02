import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/features/fertilizer_calculator/views/fertilizer_view.dart';
import 'package:maizedoctor/features/fertilizer_calculator/view_models/fertilizer_view_model.dart';
import 'package:maizedoctor/features/yield_calculator/views/yield_view.dart';
import 'package:maizedoctor/features/yield_calculator/view_models/yield_view_model.dart';
import 'package:maizedoctor/features/analytics/views/analytics_view.dart';
import 'package:maizedoctor/features/analytics/view_models/analytics_view_model.dart';
import '../support/design_fonts.dart';
import 'r04_fixtures.dart' show r04Image, settleImages;
import 'r05_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  for (final entry in [
    ('tools-light', AppRoutes.tools, false, false),
    ('fertilizer-pending-dark', AppRoutes.fertilizer, true, true),
    ('fertilizer-result-light', AppRoutes.fertilizer, false, false),
    ('yield-pending-light', AppRoutes.yieldCalculator, false, true),
    ('yield-result-dark', AppRoutes.yieldCalculator, true, false),
    ('history-light', AppRoutes.history, false, false),
    ('insights-dark', AppRoutes.analytics, true, false),
    ('insights-distribution-light', AppRoutes.analytics, false, false),
    ('profile-guest-light', AppRoutes.profile, false, false),
    ('profile-farmer-dark', AppRoutes.profile, true, false),
    ('profile-editor-light', AppRoutes.editProfile, false, false),
    ('privacy-requested-dark', AppRoutes.dataDeletion, true, false),
  ]) {
    testWidgets('R05 ${entry.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 1400);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final fixture = R05Fixture()..pending = entry.$4;
      fixture.image = (await tester.runAsync(r04Image))!;
      final boundary = GlobalKey();
      await fixture.mount(
        tester,
        dark: entry.$3,
        signedIn: entry.$1 != 'profile-guest-light',
        boundary: boundary,
      );
      await fixture.go(tester, entry.$2);
      Finder? focus;
      if (entry.$1 == 'fertilizer-result-light') {
        final model = tester
            .element(find.byType(FertilizerView))
            .read<FertilizerViewModel>();
        model.setArea('2');
        model.selectRule(model.catalogue!.items.first.id);
        await model.calculate();
        focus = find.byKey(const Key('fertilizer-result-quantity'));
      }
      if (entry.$1 == 'yield-result-dark') {
        final model = tester
            .element(find.byType(YieldView))
            .read<YieldViewModel>();
        model.setArea('2');
        model.selectConfiguration(model.catalogue!.items.first.id);
        await model.calculate();
        focus = find.byKey(const Key('yield-result-quantity'));
      }
      if (entry.$2 == AppRoutes.analytics) {
        final model = tester
            .element(find.byType(AnalyticsView))
            .read<AnalyticsViewModel>();
        await model.selectCalendarRange(
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
        );
        expect(model.summary, isNotNull);
        expect(model.error, isNull);
        if (entry.$1 == 'insights-distribution-light') {
          focus = find.text('Scans over time');
        }
      }
      await tester.pumpAndSettle();
      if (focus != null) {
        await tester.ensureVisible(focus);
        await tester.pumpAndSettle();
      }
      await settleImages(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/r05-${entry.$1}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
