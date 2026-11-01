import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/core/widgets/app_button.dart';
import 'package:maizedoctor/core/widgets/app_cards.dart';
import 'package:maizedoctor/core/widgets/app_field.dart';
import 'package:maizedoctor/core/widgets/app_page.dart';
import 'package:maizedoctor/core/widgets/app_states.dart';
import 'package:maizedoctor/core/widgets/app_confirmation_dialog.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import '../support/design_fonts.dart';

Widget host(
  Widget child, {
  bool dark = false,
  double scale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(body: AppPage(child: child)),
  ),
);

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'long field labels wrap and retain validation and input callbacks',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      final form = GlobalKey<FormState>();
      var value = '';
      const caption =
          'Reviewed source identity and supporting publication information';
      await tester.pumpWidget(
        host(
          Form(
            key: form,
            child: AppField(
              label: caption,
              optional: true,
              child: TextFormField(
                onChanged: (text) => value = text,
                validator: (text) =>
                    text == 'source' ? null : 'Enter source information.',
              ),
            ),
          ),
          scale: 2,
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter source information.'), findsOneWidget);
      final label = tester.widget<Text>(find.text('$caption (optional)'));
      expect(label.maxLines, isNull);
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'source');
      expect(value, 'source');
      expect(form.currentState!.validate(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'existing error/empty states also work in a plain Material host',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const AppEmptyState(
                  title: 'No records',
                  message: 'No items are available.',
                ),
                AppErrorState(
                  error: const AppException(AppErrorKind.network),
                  onRetry: () => retries++,
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    },
  );
  testWidgets(
    'button variants preserve intent and block disabled/loading taps',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              for (final variant in AppButtonVariant.values)
                AppButton(
                  label: variant.name,
                  onPressed: () => calls++,
                  variant: variant,
                ),
              AppButton(
                label: 'Saving',
                onPressed: () => calls++,
                loading: true,
              ),
              const AppButton(label: 'Disabled', onPressed: null),
            ],
          ),
        ),
      );
      for (final variant in AppButtonVariant.values) {
        await tester.tap(find.text(variant.name));
      }
      expect(calls, 4);
      await tester.tap(find.text('Saving'));
      await tester.tap(find.text('Disabled'));
      expect(calls, 4);
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'primary')).height,
        greaterThanOrEqualTo(56),
      );
      expect(
        tester.getSize(find.widgetWithText(OutlinedButton, 'secondary')).height,
        greaterThanOrEqualTo(48),
      );
    },
  );

  testWidgets(
    'metric unavailable and actual zero are different; error retry is retained',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              const AppMetricCard(label: 'Observed activity', value: null),
              const AppMetricCard(label: 'Observed activity', value: '0'),
              AppErrorState(
                error: const AppException(AppErrorKind.network),
                onRetry: () => retries++,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    },
  );

  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} components at ${width.toInt()}dp and 200% text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 740);
          addTearDown(() {
            tester.view.resetDevicePixelRatio();
            tester.view.resetPhysicalSize();
          });
          final field = TextEditingController();
          addTearDown(field.dispose);
          await tester.pumpWidget(
            host(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'Review this source before continuing',
                    onPressed: () {},
                    icon: Icons.menu_book_outlined,
                  ),
                  TextField(
                    controller: field,
                    decoration: const InputDecoration(
                      labelText: 'Land area (optional)',
                      helperText:
                          'Enter the reviewed field area and select its unit.',
                      errorText: 'Review this field before continuing.',
                    ),
                  ),
                  const AppMetricCard(
                    label: 'Requests in the selected period',
                    value: '123456789',
                    unit: 'requests',
                    note: 'Operational count, not accuracy.',
                  ),
                  const AppEmptyState(
                    title: 'No approved information',
                    message: 'Only reviewed content will appear here.',
                    tone: AppStatusTone.information,
                  ),
                  const AppEmptyState(
                    title: 'Configuration pending',
                    message: 'No calculation is enabled.',
                    tone: AppStatusTone.warning,
                  ),
                  const AppSuccessState(
                    title: 'Saved',
                    message: 'Your update is complete.',
                  ),
                  const AppLoadingState(
                    message: 'Checking the service',
                    inline: true,
                  ),
                ],
              ),
              dark: dark,
              scale: 2,
              reduceMotion: true,
            ),
          );
          await tester.pumpAndSettle();
          for (final label in [
            'Review this source before continuing',
            'Configuration pending',
            'Your update is complete.',
            'Checking the service',
          ]) {
            await tester.ensureVisible(find.text(label));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );
    }
  }

  testWidgets('confirmation cancel/confirm return unchanged values', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => AppButton(
            label: 'Remove',
            onPressed: () async {
              result = await showAppConfirmation(
                context,
                title: 'Remove selected item?',
                message: 'Only this item is affected.',
                confirmLabel: 'Remove item',
                destructive: true,
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove item'));
    await tester.pumpAndSettle();
    expect(result, true);
  });
}
