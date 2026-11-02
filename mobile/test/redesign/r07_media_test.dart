import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/core/widgets/private_image.dart';
import 'package:maizedoctor/data/repositories/private_image_repository.dart';
import 'package:maizedoctor/features/admin/widgets/reference_editor.dart';
import '../scans/helpers.dart' show leafImage;

class ImageFixture implements PrivateImageRepository {
  Object? failure;
  Completer<Uint8List>? pending;
  int calls = 0;
  @override
  int? get sessionRevision => 1;
  @override
  Future<Uint8List> read(String path, {String? anonymousKey}) async {
    calls++;
    if (failure case final error?) throw error;
    return pending?.future ?? leafImage.bytes;
  }
}

void main() {
  testWidgets(
    'reference dates reject impossible days without normalizing or losing input',
    (tester) async {
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReferenceEditor(
                media: null,
                image: null,
                busy: false,
                onChoose: () {},
                onSave: (_) async => saves++,
              ),
            ),
          ),
        ),
      );
      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('reference-retrievedAt')),
      );
      for (final date in [
        '2026-02-30',
        '2026-04-31',
        '2025-02-29',
        '2026-00-01',
        '2026-13-01',
        '2026-01-00',
        '2026-01-32',
        '2026-2-01',
        'not-a-date',
      ]) {
        field.controller!.text = date;
        expect(field.validator!(date), isNotNull, reason: date);
        expect(field.controller!.text, date);
      }
      for (final date in [
        '2024-02-29',
        '2000-02-29',
        '2026-04-30',
        '2096-12-31',
      ]) {
        expect(field.validator!(date), isNull, reason: date);
      }
      expect(field.validator!('1900-02-29'), isNotNull);
      field.controller!.text = '2026-02-30';
      await tester.ensureVisible(find.text('Save reviewed draft metadata'));
      await tester.tap(find.text('Save reviewed draft metadata'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(field.controller!.text, '2026-02-30');
      expect(find.text('Use an actual YYYY-MM-DD date.'), findsOneWidget);
    },
  );

  for (final entry in {
    AppErrorKind.network: 'Check your connection and retry the photo.',
    AppErrorKind.timeout: 'The photo request timed out. Please retry.',
    AppErrorKind.authentication: 'Sign in again to view this photo.',
    AppErrorKind.authorization: 'You do not have access to this photo.',
    AppErrorKind.notFound: 'This photo is no longer available.',
    AppErrorKind.server: 'The photo could not be loaded. Please retry.',
  }.entries) {
    testWidgets(
      'safe image feedback for ${entry.key.name}, bounded layout and retry',
      (tester) async {
        final repository = ImageFixture()
          ..failure = AppException(
            entry.key,
            requestId: 'private-do-not-display',
          );
        await tester.pumpWidget(
          Provider<PrivateImageRepository>.value(
            value: repository,
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: PrivateImage(
                    path: 'fixture-only',
                    semanticLabel: 'Fixture protected photo',
                    width: 200,
                    height: 200,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.textContaining('private-do-not-display'), findsNothing);
        repository.failure = null;
        await tester.tap(find.byTooltip('Retry photo'));
        await tester.pumpAndSettle();
        expect(repository.calls, 2);
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unknown image failures stay generic; reduced-motion loading is static',
    (tester) async {
      final repository = ImageFixture()..pending = Completer<Uint8List>();
      await tester.pumpWidget(
        Provider<PrivateImageRepository>.value(
          value: repository,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: const Scaffold(
                body: PrivateImage(
                  path: 'fixture',
                  semanticLabel: 'Private photo',
                  width: 48,
                  height: 48,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
      repository.pending!.completeError(
        StateError('secret/path'),
      ); // Unknown cause must not be guessed.
      await tester.pumpAndSettle();
      expect(find.textContaining('secret'), findsNothing);
      expect(find.byTooltip('Retry photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
