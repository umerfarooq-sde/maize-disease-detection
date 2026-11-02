import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/features/admin/widgets/admin_navigation.dart';
import 'package:maizedoctor/features/admin/widgets/management_editor_form.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';
import 'r06a_navigation_test.dart' show selectAdmin;
import 'r06b_fixtures.dart';

Future<void> r06bEnter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'new sourced document submits a version-zero draft with no automatic embedding or publication',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/manage');
      await r06Tap(tester, find.text('New reviewed draft'));
      for (final item in {
        'documentKey': 'isolated-synthetic-series',
        'title': 'Isolated synthetic draft',
        'content': 'Synthetic UI contract only, not agricultural advice.',
        'region': 'Test scope',
        'sourceSection': 'Test section',
        'source.title': 'Synthetic source',
        'source.publisher': 'UI tests',
        'source.url': 'https://example.invalid/source',
        'source.retrievedAt': '2026-10-01',
        'source.rights': 'Test use only',
        'reviewNote':
            'Reviewed synthetic source for this isolated frontend test.',
      }.entries) {
        await r06bEnter(tester, 'management-${item.key}', item.value);
      }
      await r06Tap(tester, find.byKey(const Key('management-diseaseSlug')));
      await r06Tap(tester, find.text('Common_Rust').last);
      await r06Tap(tester, find.byKey(const Key('management-knowledgeType')));
      await r06Tap(tester, find.text('OVERVIEW').last);
      await r06Tap(tester, find.byType(CheckboxListTile));
      await r06Tap(tester, find.text('Save draft'));
      expect(fixture.writes.length, 1);
      final body = jsonDecode(fixture.writes.single.body) as Map;
      expect(body['expectedVersion'], 0);
      expect(body['documentKey'], 'isolated-synthetic-series');
      expect(fixture.documents.first['status'], 'DRAFT');
      expect(fixture.documents.first['indexed'], isFalse);
    },
  );
  testWidgets(
    'new editor starts at its heading rather than an old list scroll offset',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/manage?area=diseases');
      await r06Tap(tester, find.text('Edit display metadata').at(3));
      expect(
        tester.getTopLeft(find.text('Disease catalogue')).dy,
        greaterThan(0),
      );
      expect(
        tester
            .getTopLeft(
              find.textContaining(
                'Protected identity · Northern_Corn_Leaf_Blight',
              ),
            )
            .dy,
        lessThan(900),
      );
      expect(fixture.writes, isEmpty);
    },
  );
  testWidgets(
    'missing metadata remains unavailable and never becomes an invented zero',
    (tester) async {
      final fixture = R06BFixture();
      fixture.diseases.first['catalogueMetadata'] = {
        'growthStages': 'invalid',
        'severityDescriptors': null,
      };
      await fixture.mount(tester, location: '/admin/manage?area=diseases');
      expect(
        find.text(
          'Metadata entries · unavailable growth-stage entries · unavailable severity descriptors',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'four immutable classifier identities and Healthy scouting context remain distinct',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/manage?area=diseases');
      for (final label in r06bLabels) {
        expect(find.text('Classifier context · $label'), findsOneWidget);
      }
      expect(find.textContaining('Healthy / scouting context'), findsOneWidget);
      await r06Tap(tester, find.text('Edit display metadata').at(2));
      expect(find.byKey(const Key('management-slug')), findsNothing);
      expect(find.byKey(const Key('management-literalLabel')), findsNothing);
      expect(
        find.textContaining('Protected identity · Healthy'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Do not assign disease severity to Healthy'),
        findsOneWidget,
      );
      expect(fixture.writes, isEmpty);
    },
  );
  testWidgets(
    'disease display edit sends revision without renaming model; server failure retains draft',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/manage?area=diseases');
      await r06Tap(tester, find.text('Edit display metadata').first);
      await r06bEnter(
        tester,
        'management-description',
        'Synthetic revised display description.',
      );
      fixture.mutationStatus = 409;
      await r06Tap(tester, find.text('Save display metadata'));
      expect(find.textContaining('Version conflict:'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('management-description')),
            )
            .controller!
            .text,
        'Synthetic revised display description.',
      );
      final body = jsonDecode(fixture.writes.single.body) as Map;
      expect(body['expectedRevision'], 'a' * 64);
      expect(body.containsKey('literalLabel'), isFalse);
      expect(body.containsKey('slug'), isFalse);
      fixture.mutationStatus = 200;
      await r06Tap(tester, find.text('Save display metadata'));
      expect(find.byType(ManagementEditorForm), findsNothing);
      expect(find.text('Display metadata saved.'), findsOneWidget);
    },
  );
  testWidgets(
    'new informational entry remains separate and validates source rather than inventing fields',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/manage?area=diseases');
      await r06Tap(tester, find.text('New informational entry'));
      expect(find.byKey(const Key('management-slug')), findsOneWidget);
      await r06Tap(tester, find.text('Save display metadata'));
      expect(fixture.writes, isEmpty);
      expect(find.text('This field is required.'), findsWidgets);
      expect(
        find.text('Review and approve the source before saving.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'loaded-only filter preserves cursor and versions without fake database search',
    (tester) async {
      final fixture = R06BFixture()..more = true;
      await fixture.mount(tester, location: '/admin/manage');
      final before = fixture.requests.length;
      await r06bEnter(tester, 'admin-content-filter', 'no matching title');
      expect(find.text('No loaded matches'), findsOneWidget);
      expect(fixture.requests.length, before);
      await r06Tap(tester, find.text('Load more versions'));
      expect(fixture.requests.last.url.queryParameters['cursor'], isNotNull);
      await r06bEnter(tester, 'admin-content-filter', '');
      expect(find.text('Status · ARCHIVED'), findsOneWidget);
      expect(find.text('2 matching / 2 loaded records'), findsOneWidget);
    },
  );
  testWidgets(
    'draft, embeddings and activation remain separate server-confirmed operations',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/manage');
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Activate'))
            .onPressed,
        isNull,
      );
      await r06Tap(tester, find.text('Build embeddings'));
      expect(fixture.writes.single.url.path, endsWith('/index'));
      expect(fixture.documents.first['status'], 'DRAFT');
      await r06Tap(tester, find.text('Activate'));
      expect(fixture.writes.length, 1);
      await r06Tap(tester, find.text('Cancel'));
      expect(fixture.writes.length, 1);
      await r06Tap(tester, find.text('Activate'));
      await r06Tap(tester, find.text('Confirm'));
      expect(fixture.documents.first['status'], 'ACTIVE');
      expect(find.text('Status · ACTIVE'), findsOneWidget);
      await r06Tap(tester, find.text('Deactivate'));
      await r06Tap(tester, find.text('Confirm'));
      expect(fixture.documents.first['status'], 'ARCHIVED');
      expect(find.text('Status · ARCHIVED'), findsOneWidget);
    },
  );
  testWidgets(
    'new version preserves series context, fresh source review, immutable save and no auto indexing',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/manage');
      await r06Tap(tester, find.text('New version from this'));
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('management-documentKey')),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('management-diseaseSlug')),
            )
            .onChanged,
        isNull,
      );
      expect(find.text('Source & applicability'), findsOneWidget);
      await r06bEnter(
        tester,
        'management-reviewNote',
        'Synthetic source applicability reviewed for this isolated UI test.',
      );
      await r06Tap(tester, find.byType(CheckboxListTile));
      await r06Tap(tester, find.text('Save draft'));
      expect(fixture.writes.length, 1);
      final body = jsonDecode(fixture.writes.single.body) as Map;
      expect(body['expectedVersion'], 1);
      expect(body['documentKey'], 'synthetic-note');
      expect(body.containsKey('reviewedBy'), isFalse);
      expect(fixture.documents.first['version'], 2);
      expect(fixture.documents.first['status'], 'DRAFT');
      expect(fixture.documents.first['indexed'], isFalse);
    },
  );
  for (final route in [
    'drawer',
    'sidebar',
    'header-back',
    'area',
    'back',
    'farmer',
    'sign-out',
  ]) {
    testWidgets(
      'dirty document guards $route; cancel preserves draft and confirmed leave clears it',
      (tester) async {
        if (route == 'sidebar' || route == 'header-back') {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1280, 915);
          addTearDown(tester.view.reset);
        }
        final fixture = R06BFixture();
        await fixture.mount(tester, location: '/admin/manage');
        await r06Tap(tester, find.text('New reviewed draft'));
        await r06bEnter(
          tester,
          'management-title',
          'PRIVATE UNSAVED UI FIXTURE',
        );
        Future<void> leave() async {
          if (route == 'drawer' || route == 'sidebar') {
            await selectAdmin(tester, AdminDestination.diseases);
          } else if (route == 'header-back') {
            await r06Tap(tester, find.byTooltip('Back from Admin workspace'));
          } else if (route == 'area') {
            await r06Tap(tester, find.widgetWithText(ChoiceChip, 'Diseases'));
          } else if (route == 'back') {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          } else {
            await r06Tap(tester, find.byTooltip('Workspace actions'));
            await r06Tap(
              tester,
              find
                  .text(
                    route == 'farmer'
                        ? 'Return to Farmer App'
                        : 'Admin Sign Out',
                  )
                  .last,
            );
          }
        }

        await leave();
        expect(find.text('Leave unsaved changes?'), findsOneWidget);
        await r06Tap(tester, find.text('Cancel'));
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('management-title')))
              .controller!
              .text,
          'PRIVATE UNSAVED UI FIXTURE',
        );
        expect(fixture.admin.signedIn, isTrue);
        await leave();
        await r06Tap(tester, find.text('Confirm'));
        expect(find.byType(ManagementEditorForm), findsNothing);
        expect(fixture.writes, isEmpty);
        expect(fixture.admin.signedIn, route != 'sign-out');
      },
    );
  }
  testWidgets(
    'pending indexing prevents duplicate actions and late response cannot leak after logout',
    (tester) async {
      final fixture = R06BFixture()..mutationGate = Completer<void>();
      await fixture.mount(tester, location: '/admin/manage');
      await tester.ensureVisible(find.text('Build embeddings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build embeddings'));
      await tester.pump();
      expect(fixture.writes.length, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Build embeddings'),
            )
            .onPressed,
        isNull,
      );
      await tester.runAsync(fixture.admin.signOut);
      fixture.mutationGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ManagementEditorForm), findsNothing);
      expect(find.text('Synthetic sourced note'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pushed editor Back cancellation retains input and confirmed Back returns to originating Profile',
    (tester) async {
      final fixture = R06BFixture();
      await fixture.mount(tester, location: '/admin/manage');
      await fixture.go(tester, '/profile');
      fixture.router.push<void>('/admin/manage');
      await tester.pumpAndSettle();
      await r06Tap(tester, find.text('New reviewed draft'));
      await r06bEnter(tester, 'management-title', 'Private pushed draft');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Leave unsaved changes?'), findsOneWidget);
      await r06Tap(tester, find.text('Cancel'));
      expect(fixture.router.state.uri.path, '/admin/manage');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await r06Tap(tester, find.text('Confirm'));
      expect(fixture.router.state.uri.path, '/profile');
      expect(find.byType(ManagementEditorForm), findsNothing);
    },
  );
}
