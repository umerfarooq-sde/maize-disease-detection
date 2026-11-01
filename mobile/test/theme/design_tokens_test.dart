import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/core/theme/app_fonts.dart';
import 'package:maizedoctor/core/theme/design_tokens.dart';
import '../support/design_fonts.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    test('${theme.brightness.name}: semantic text pairs meet AA', () {
      final c = theme.colorScheme, s = theme.extension<AppSemanticColors>()!;
      final pairs = <String, (Color, Color)>{
        'primary': (c.onPrimary, c.primary),
        'primaryContainer': (c.onPrimaryContainer, c.primaryContainer),
        'secondary': (c.onSecondary, c.secondary),
        'secondaryContainer': (c.onSecondaryContainer, c.secondaryContainer),
        'tertiary': (c.onTertiary, c.tertiary),
        'highlight': (c.onTertiaryContainer, c.tertiaryContainer),
        'error': (c.onError, c.error),
        'errorContainer': (c.onErrorContainer, c.errorContainer),
        'inverse': (c.onInverseSurface, c.inverseSurface),
        'inverse action': (c.inversePrimary, c.inverseSurface),
        'success': (s.onSuccess, s.success),
        'successContainer': (s.onSuccessContainer, s.successContainer),
        'info': (s.onInfo, s.info),
        'infoContainer': (s.onInfoContainer, s.infoContainer),
        'warning': (s.onWarning, s.warning),
        'warningContainer': (s.onWarningContainer, s.warningContainer),
        'hero': (s.onHero, s.hero),
      };
      for (final background in [
        c.surface,
        c.surfaceContainerLowest,
        c.surfaceContainerLow,
        c.surfaceContainer,
        c.surfaceContainerHigh,
        c.surfaceContainerHighest,
        theme.scaffoldBackgroundColor,
      ]) {
        for (final foreground in [
          c.onSurface,
          c.onSurfaceVariant,
          c.primary,
          c.error,
        ]) {
          expect(
            contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason:
                'Readable text on ${background.toARGB32().toRadixString(16)}',
          );
        }
      }
      for (final pair in pairs.entries) {
        expect(
          contrast(pair.value.$1, pair.value.$2),
          greaterThanOrEqualTo(4.5),
          reason: pair.key,
        );
      }
      expect(contrast(c.outline, c.surface), greaterThanOrEqualTo(3));
    });
  }

  test('approved palette, spacing, width, motion and typography roles', () {
    expect(AppTheme.light.colorScheme.primary, const Color(0xFF174C38));
    expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFF7F8F3));
    expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF101A15));
    expect(
      [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.section,
      ],
      [4, 8, 12, 16, 24, 32, 48],
    );
    expect(
      [AppRadii.small, AppRadii.medium, AppRadii.card, AppRadii.hero],
      [10, 14, 20, 24],
    );
    expect(
      [
        AppSizing.readingMaxWidth,
        AppSizing.authenticationMaxWidth,
        AppSizing.formMaxWidth,
        AppSizing.contentMaxWidth,
      ],
      [720, 480, 760, 1120],
    );
    expect(
      [
        AppMotion.button.inMilliseconds,
        AppMotion.navigation.inMilliseconds,
        AppMotion.reveal.inMilliseconds,
        AppMotion.theme.inMilliseconds,
      ],
      [100, 180, 220, 240],
    );
    expect(
      AppTypography.metric.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.textTheme.bodyMedium!.fontFamily, AppTypography.family);
      expect(theme.textTheme.bodyMedium!.fontSize, 16);
      expect(theme.textTheme.displaySmall!.fontSize, 32);
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
        56,
      );
      expect(
        theme.outlinedButtonTheme.style!.minimumSize!.resolve({})!.height,
        48,
      );
    }
    // Earth is intentionally decorative, not a white-body-text background.
    expect(contrast(Colors.white, AppColors.earth), lessThan(4.5));
  });

  test(
    'upright/italic faces and license are present in the asset bundle',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json'))
              as List<dynamic>;
      final font = manifest.cast<Map<String, dynamic>>().singleWhere(
        (f) => f['family'] == AppTypography.family,
      );
      final faces = (font['fonts'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final italic in [false, true]) {
        final subset = faces.where((f) => (f['style'] == 'italic') == italic);
        expect(subset.map((f) => f['weight']).toSet(), {400, 500, 600, 700});
        final data = await rootBundle.load(subset.first['asset'] as String);
        expect(data.lengthInBytes, greaterThan(100000));
        expect(data.getUint32(0), 0x00010000);
      }
      final notice = await rootBundle.loadString(
        'assets/fonts/plus_jakarta_sans/OFL.txt',
      );
      expect(notice, contains('SIL OPEN FONT LICENSE'));
      registerAppFontLicense();
      expect(
        await LicenseRegistry.licenses.any(
          (entry) => entry.packages.contains('Plus Jakarta Sans'),
        ),
        isTrue,
      );
    },
  );

  testWidgets('reduced motion resolves timings without changing text scale', (
    tester,
  ) async {
    late BuildContext inner;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: Builder(
            builder: (context) {
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(AppMotion.resolve(inner, AppMotion.reveal), Duration.zero);
    expect(MediaQuery.textScalerOf(inner).scale(16), 32);
  });
}
