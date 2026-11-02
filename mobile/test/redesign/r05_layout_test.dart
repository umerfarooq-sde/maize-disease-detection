import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/features/fertilizer_calculator/views/fertilizer_view.dart';
import 'package:maizedoctor/features/fertilizer_calculator/view_models/fertilizer_view_model.dart';
import 'package:maizedoctor/features/yield_calculator/views/yield_view.dart';
import 'package:maizedoctor/features/yield_calculator/view_models/yield_view_model.dart';
import '../support/design_fonts.dart';
import 'r05_fixtures.dart';

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
        'R05 $width / $scale tools, exact results, history, insights, account, keyboard and privacy in both themes',
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
          final fixture = R05Fixture()..longContent = true;
          await fixture.mount(tester);
          for (final mode in [ThemeMode.light, ThemeMode.dark]) {
            await fixture.theme.setMode(mode);
            for (final path in [
              AppRoutes.tools,
              AppRoutes.fertilizer,
              AppRoutes.yieldCalculator,
              AppRoutes.history,
              AppRoutes.analytics,
              AppRoutes.profile,
              AppRoutes.editProfile,
              AppRoutes.dataDeletion,
            ]) {
              await fixture.go(tester, path);
              if (path == AppRoutes.fertilizer) {
                final model = tester
                    .element(find.byType(FertilizerView))
                    .read<FertilizerViewModel>();
                model.setArea('2');
                model.selectRule(model.catalogue!.items.first.id);
                await model.calculate();
                await tester.pumpAndSettle();
                expect(find.text('123456789012345.125 kg'), findsOneWidget);
                await tester.ensureVisible(find.text('Review selected rule'));
                await tester.pumpAndSettle();
                await tester.tap(find.text('Review selected rule'));
                await tester.pumpAndSettle();
              }
              if (path == AppRoutes.yieldCalculator) {
                final model = tester
                    .element(find.byType(YieldView))
                    .read<YieldViewModel>();
                model.setArea('2');
                model.selectConfiguration(model.catalogue!.items.first.id);
                await model.calculate();
                await tester.pumpAndSettle();
                expect(find.text('123456789012345.125 kg'), findsOneWidget);
              }
              if (path == AppRoutes.editProfile) {
                tester.view.viewInsets = const FakeViewPadding(bottom: 280);
                await tester.pumpAndSettle();
                await tester.ensureVisible(
                  find.byKey(const Key('profile-display-name')),
                );
                await tester.pumpAndSettle();
                await tester.tap(find.byKey(const Key('profile-display-name')));
                await tester.pumpAndSettle();
                await tester.ensureVisible(
                  find.byKey(const Key('profile-save')),
                );
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const Key('profile-save')).hitTestable(),
                  findsOneWidget,
                );
                tester.view.viewInsets = const FakeViewPadding();
                FocusManager.instance.primaryFocus?.unfocus();
              }
              if (path == AppRoutes.analytics) {
                expect(find.text('Saved scans'), findsOneWidget);
                expect(find.text('Scans over time'), findsOneWidget);
                expect(find.text('Something needs attention'), findsNothing);
              }
              // Traverse lazy lists as well as the initial viewport.
              for (var i = 0; i < 3; i++) {
                await tester.drag(
                  find
                      .byWidgetPredicate(
                        (widget) =>
                            widget is Scrollable &&
                            widget.axisDirection == AxisDirection.down,
                      )
                      .hitTestable()
                      .first,
                  const Offset(0, -600),
                );
                await tester.pumpAndSettle();
              }
              expect(
                tester.takeException(),
                isNull,
                reason: '$path $width $scale $mode',
              );
            }
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
