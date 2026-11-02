import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/features/admin/widgets/admin_content_management.dart';
import 'package:maizedoctor/features/fertilizer_calculator/views/fertilizer_view.dart';
import 'package:maizedoctor/features/fertilizer_calculator/view_models/fertilizer_view_model.dart';
import 'package:maizedoctor/features/yield_calculator/views/yield_view.dart';
import 'package:maizedoctor/features/yield_calculator/view_models/yield_view_model.dart';
import '../admin/management_test.dart' show managementDocument;
import 'r06b_fixtures.dart';
import 'r05_fixtures.dart';
import 'r06d_fixtures.dart';

void main() {
  testWidgets(
    'Audit persistent labels and long selected actions wrap at 320dp and 200 percent',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final fixture = R06DFixture();
      await fixture.mount(tester, location: '/admin/audit');
      final dropdown = find.byKey(const ValueKey('audit-action-'));
      await r06dReveal(tester, dropdown);
      tester.widget<DropdownButtonFormField<String>>(dropdown).onChanged!(
        'MODEL_PROMOTION',
      );
      await tester.pumpAndSettle();
      final selection = find.text('Model promotion recorded');
      await r06dReveal(tester, selection);
      final paragraph = tester.renderObject<RenderParagraph>(selection);
      expect(paragraph.didExceedMaxLines, false);
      expect(paragraph.size.height, greaterThan(48));
      final label = find.text('Through UTC date (optional)');
      await r06dReveal(tester, label);
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        false,
      );
      expect(tester.takeException(), isNull);
      expect(
        fixture.requests.every(
          (request) =>
              request.method == 'GET' ||
              request.url.path.endsWith('/auth/login'),
        ),
        true,
      );
    },
  );
  testWidgets(
    'large loaded knowledge catalogue mounts only nearby cards and retains filtering',
    (tester) async {
      final fixture = R06BFixture();
      fixture.documents.clear();
      for (var i = 0; i < 100; i++) {
        fixture.documents.add({
          ...managementDocument(),
          'id': '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
          'title': 'Fixture document $i',
        });
      }
      await fixture.mount(tester, location: '/admin/manage?area=knowledge');
      expect(
        find.byType(AdminContentEntryCard).evaluate().length,
        lessThan(20),
      );
      await tester.ensureVisible(find.byKey(const Key('admin-content-filter')));
      await tester.enterText(
        find.byKey(const Key('admin-content-filter')),
        'Fixture document 99',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 matching / 100 loaded records'), findsOneWidget);
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AdminContentEntryCard),
          matching: find.text('Fixture document 99'),
        ),
        findsOneWidget,
      );
      expect(fixture.writes, isEmpty);
    },
  );

  for (final yieldPlanning in [false, true]) {
    testWidgets(
      '${yieldPlanning ? 'Yield' : 'Fertilizer'} button calculation reveals acknowledged quantity once without a rebuild jump',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        });
        final fixture = R05Fixture();
        await fixture.mount(tester);
        await fixture.go(
          tester,
          yieldPlanning ? AppRoutes.yieldCalculator : AppRoutes.fertilizer,
        );
        if (yieldPlanning) {
          final model = tester
              .element(find.byType(YieldView))
              .read<YieldViewModel>();
          model.setArea('2');
          model.selectConfiguration(model.catalogue!.items.first.id);
        } else {
          final model = tester
              .element(find.byType(FertilizerView))
              .read<FertilizerViewModel>();
          model.setArea('2');
          model.selectRule(model.catalogue!.items.first.id);
        }
        await tester.pumpAndSettle();
        final prefix = yieldPlanning ? 'yield' : 'fertilizer';
        final button = find.byKey(Key('$prefix-calculate'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('$prefix-result-quantity')).hitTestable(),
          findsOneWidget,
        );
        final scroll = find
            .descendant(
              of: yieldPlanning
                  ? find.byType(YieldView)
                  : find.byType(FertilizerView),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scroll).position;
        position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(position.pixels, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
