import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/data/models/selected_leaf_image.dart';
import 'package:maizedoctor/features/admin/widgets/reference_editor.dart';
import '../support/design_fonts.dart';
import 'r04_fixtures.dart' show r04Image, settleImages;
import 'r06a_fixtures.dart';
import 'r06b_fixtures.dart';
import 'r06b_content_test.dart' show r06bEnter;

Future<void> fillReference(WidgetTester tester) async {
  for (final item in {
    'altText': 'Synthetic UI fixture only',
    'sortOrder': '2',
    'title': 'Synthetic source',
    'publisher': 'UI tests',
    'url': 'https://example.invalid/test',
    'retrievedAt': '2026-10-01',
    'rights': 'Synthetic test only',
    'license': 'Test permission only',
    'contributor': 'Test generator',
    'attribution': 'Synthetic, not disease evidence',
  }.entries) {
    await r06bEnter(tester, 'reference-${item.key}', item.value);
  }
}

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'friendly catalogue choices send exact slug; empty gallery is not an error',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/reference-images');
      expect(find.text('No reference images'), findsOneWidget);
      expect(find.text('Catalogue slug'), findsNothing);
      await r06Tap(tester, find.byType(DropdownButtonFormField<String>));
      await r06Tap(tester, find.text('Healthy').last);
      expect(fixture.requests.last.url.path, endsWith('/healthy/items'));
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/knowledge/diseases'))
            .length,
        1,
      );
    },
  );
  testWidgets(
    'media catalogue failure is retryable and cannot masquerade as empty',
    (tester) async {
      final fixture = R06BFixture()..listStatus = 503;
      await fixture.mount(tester, location: '/admin/reference-images');
      expect(find.text('No reference images'), findsNothing);
      expect(find.text('Something needs attention'), findsNWidgets(2));
      fixture.listStatus = 200;
      await r06Tap(tester, find.text('Try again').first);
      await r06Tap(tester, find.text('Load / refresh catalogue media'));
      expect(find.text('No reference images'), findsOneWidget);
    },
  );
  testWidgets(
    'protected preview failure retries with Admin credentials and exposes no storage URL',
    (tester) async {
      final fixture = R06BFixture()
        ..addMedia()
        ..imageStatus = 503;
      await fixture.mount(tester, location: '/admin/reference-images');
      expect(find.byTooltip('Retry photo'), findsOneWidget);
      expect(
        fixture.requests.last.headers['authorization'],
        'Bearer admin.access.token',
      );
      expect(find.textContaining('cloudinary.com'), findsNothing);
      fixture.image = await tester.runAsync(r04Image);
      fixture.imageStatus = 200;
      await r06Tap(tester, find.byTooltip('Retry photo'));
      await settleImages(tester);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byTooltip('Retry photo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'metadata save preserves source rights, revision, order and requires deliberate publication',
    (tester) async {
      final fixture = R06BFixture()..addMedia();
      fixture.image = await tester.runAsync(r04Image);
      await fixture.mount(tester, location: '/admin/reference-images');
      await r06Tap(tester, find.text('Edit metadata / reorder / replace'));
      expect(find.text('Usage rights'), findsOneWidget);
      await r06bEnter(tester, 'reference-sortOrder', '7');
      await r06Tap(tester, find.byType(CheckboxListTile));
      await r06Tap(tester, find.text('Save reviewed draft metadata'));
      final body = jsonDecode(fixture.writes.single.body) as Map;
      expect(body['sortOrder'], 7);
      expect(body['expectedRevision'], 'a' * 64);
      expect((body['provenance'] as Map)['rightsConfirmed'], isTrue);
      expect(fixture.media.single['status'], 'DRAFT');
      await r06Tap(tester, find.text('Publish'));
      expect(fixture.writes.length, 1);
      await r06Tap(tester, find.text('Cancel'));
      expect(fixture.writes.length, 1);
      await r06Tap(tester, find.text('Publish'));
      await r06Tap(tester, find.text('Confirm'));
      expect(fixture.media.single['status'], 'ACTIVE');
      await r06Tap(tester, find.text('Hide'));
      await r06Tap(tester, find.text('Confirm'));
      expect(fixture.media.single['status'], 'INACTIVE');
      await r06Tap(tester, find.text('Retire and clean'));
      expect(
        find.text('Retire image and queue asset cleanup?'),
        findsOneWidget,
      );
      await r06Tap(tester, find.text('Confirm'));
      expect(fixture.media, isEmpty);
      expect(fixture.writes.every((r) => r.method == 'PATCH'), isTrue);
    },
  );
  testWidgets(
    'invalid provenance stays local; declined catalogue navigation retains entered text',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/reference-images');
      await r06Tap(tester, find.text('New draft image'));
      await r06bEnter(tester, 'reference-altText', 'Private draft description');
      await r06Tap(tester, find.text('Save reviewed draft metadata'));
      expect(fixture.writes, isEmpty);
      expect(find.text('Required source or image information.'), findsWidgets);
      await r06Tap(tester, find.byType(DropdownButtonFormField<String>));
      await r06Tap(tester, find.text('Healthy').last);
      await r06Tap(tester, find.text('Cancel'));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('reference-altText')))
            .controller!
            .text,
        'Private draft description',
      );
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/healthy/items')),
        isEmpty,
      );
    },
  );
  for (final replace in [false, true]) {
    testWidgets(
      '${replace ? 'replacement' : 'new upload'} uses selected bytes, retains prior asset and stays draft',
      (tester) async {
        final fixture = R06BFixture();
        fixture.image = await tester.runAsync(r04Image);
        fixture.images = R06BPicker(
          SelectedLeafImage(
            bytes: Uint8List.fromList(fixture.image!),
            mimeType: 'image/png',
            width: 400,
            height: 300,
          ),
        );
        if (replace) {
          fixture.addMedia();
          fixture.media.first['status'] = 'ACTIVE';
        }
        await fixture.mount(tester, location: '/admin/reference-images');
        await r06Tap(
          tester,
          find.text(
            replace ? 'Edit metadata / reorder / replace' : 'New draft image',
          ),
        );
        await r06Tap(
          tester,
          find.text(
            replace
                ? 'Choose replacement image (new draft)'
                : 'Choose draft image',
          ),
        );
        await settleImages(tester);
        expect(
          find.bySemanticsLabel('Selected draft image preview'),
          findsOneWidget,
        );
        expect(fixture.writes, isEmpty);
        await fillReference(tester);
        await r06Tap(tester, find.byType(CheckboxListTile));
        await r06Tap(tester, find.text('Save reviewed draft metadata'));
        expect(fixture.writes.length, 1);
        expect(fixture.uploaded!['diseaseSlug'], 'common-rust');
        expect(
          fixture.uploaded!['replacementFor'],
          replace ? '12345678-1234-4123-8123-123456789abc' : null,
        );
        expect(fixture.media.last['status'], 'DRAFT');
        if (replace) expect(fixture.media.first['status'], 'ACTIVE');
        expect(find.byType(ReferenceEditor), findsNothing);
      },
    );
  }
  testWidgets(
    'media failure retains review input; session removal clears drafts and private thumbnails',
    (tester) async {
      final fixture = R06BFixture()
        ..addMedia()
        ..mutationStatus = 409;
      fixture.image = await tester.runAsync(r04Image);
      await fixture.mount(tester, location: '/admin/reference-images');
      await r06Tap(tester, find.text('Edit metadata / reorder / replace'));
      await r06bEnter(tester, 'reference-altText', 'Private metadata change');
      await r06Tap(tester, find.text('Save reviewed draft metadata'));
      expect(find.textContaining('Your input is retained'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('reference-altText')))
            .controller!
            .text,
        'Private metadata change',
      );
      await tester.runAsync(fixture.admin.signOut);
      await tester.pumpAndSettle();
      expect(find.byType(ReferenceEditor), findsNothing);
      expect(find.byType(Image), findsNothing);
    },
  );
}
