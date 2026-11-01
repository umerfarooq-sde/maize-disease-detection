import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/core/theme/design_tokens.dart';
import 'package:maizedoctor/core/widgets/app_button.dart';
import 'package:maizedoctor/core/widgets/app_cards.dart';
import 'package:maizedoctor/core/widgets/app_field.dart';
import 'package:maizedoctor/core/widgets/app_page.dart';
import 'package:maizedoctor/core/widgets/app_states.dart';
import 'package:maizedoctor/core/widgets/feature_card.dart';
import 'package:maizedoctor/core/widgets/source_reference_card.dart';
import 'package:maizedoctor/data/models/assistant_answer.dart';
import '../knowledge/helpers.dart' show sourceJson;
import '../support/design_fonts.dart';

/// Test-only specimens: no route, provider calls, or application content is added.
class _Specimens extends StatelessWidget {
  const _Specimens();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: [
        Text('FIELD INTELLIGENCE', style: theme.textTheme.labelLarge),
        Text('Clear by nature.', style: theme.textTheme.displaySmall),
        Text(
          'Design-system specimens. No live data or agricultural guidance.',
          style: theme.textTheme.bodyMedium,
        ),
        AppButton(
          label: 'Primary action',
          icon: Icons.eco_outlined,
          onPressed: () {},
        ),
        AppButton(
          label: 'Secondary action',
          variant: AppButtonVariant.secondary,
          onPressed: () {},
        ),
        AppButton(
          label: 'Tonal action',
          variant: AppButtonVariant.tonal,
          onPressed: () {},
        ),
        AppButton(
          label: 'Destructive action',
          variant: AppButtonVariant.destructive,
          onPressed: () {},
        ),
        AppButton(label: 'Saving', loading: true, onPressed: () {}),
        const AppButton(label: 'Disabled', onPressed: null),
        const AppField(
          label: 'Labelled input',
          optional: true,
          child: TextField(
            decoration: InputDecoration(
              helperText: 'A persistent label and readable supporting text.',
            ),
          ),
        ),
        const TextField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: 'Review this field before continuing.',
            suffixIcon: Icon(Icons.visibility_outlined),
          ),
        ),
        FeatureCard(
          title: 'Reviewed information',
          description:
              'A consistent navigation surface with a clear next action.',
          icon: Icons.menu_book_outlined,
          onTap: () {},
        ),
        const AppMetricCard(
          label: 'Recorded events',
          value: '1,234',
          note: 'Test specimen only; not production telemetry.',
        ),
        const AppStatusPanel(
          tone: AppStatusTone.warning,
          child: Text(
            'Configuration pending. This status never implies a confirmed diagnosis.',
          ),
        ),
        const AppLoadingState(message: 'Checking availability', inline: true),
        SourceReferenceCard(
          reference: AssistantSourceReference.fromJson(sourceJson()),
          citationLabel: 'S1',
        ),
      ],
    );
  }
}

void main() {
  setUpAll(loadDesignFonts);
  for (final config in [
    (false, 360.0, 1.0),
    (true, 360.0, 1.0),
    (false, 320.0, 2.0),
  ]) {
    final mode = config.$1 ? 'dark' : 'light';
    final name =
        'field-intelligence-$mode-${config.$2.toInt()}-${config.$3.toInt()}x';
    testWidgets(name, (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(config.$2, 1600);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: config.$1 ? AppTheme.dark : AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(config.$3),
                disableAnimations: true,
              ),
              child: const Scaffold(body: AppPage(child: _Specimens())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/$name.png'),
      );
      // Also exercise the content below the captured viewport at large text.
      await tester.ensureVisible(find.byType(SourceReferenceCard));
      await tester.pumpAndSettle();
      expect(find.text('Test-only source metadata.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
