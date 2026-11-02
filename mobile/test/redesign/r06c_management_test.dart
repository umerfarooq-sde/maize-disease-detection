import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import 'package:maizedoctor/features/admin/widgets/admin_navigation.dart';
import 'package:maizedoctor/features/admin/widgets/management_editor_form.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';
import 'r06a_navigation_test.dart' show selectAdmin;
import 'r06b_content_test.dart' show r06bEnter;
import 'r06c_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'empty configurations and unavailable database remain different, with explicit retry',
    (tester) async {
      final fixture = R06CFixture()..listStatus = 503;
      await fixture.mount(tester, location: '/admin/manage?area=yieldRules');
      expect(find.text('No managed content yet'), findsNothing);
      expect(find.text('Something needs attention'), findsOneWidget);
      fixture.listStatus = 200;
      fixture.emptyCalculators = true;
      await r06Tap(tester, find.text('Try again'));
      expect(find.text('No managed content yet'), findsOneWidget);
      expect(find.text('0 matching / 0 loaded records'), findsOneWidget);
      expect(fixture.writes, isEmpty);
    },
  );
  testWidgets(
    'pending save disables duplicate submissions and late acknowledgement cannot restore a logged-out draft',
    (tester) async {
      final fixture = R06CFixture();
      await fixture.mount(tester, location: '/admin/manage?area=yieldRules');
      await r06Tap(tester, find.text('New version from this'));
      await r06bEnter(
        tester,
        'management-reviewNote',
        'Synthetic source review for this isolated pending save test.',
      );
      await r06Tap(tester, find.byType(CheckboxListTile));
      fixture.mutationGate = Completer<void>();
      await tester.ensureVisible(find.text('Save draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save draft'));
      await tester.pump();
      expect(fixture.writes.length, 1);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      await tester.runAsync(fixture.admin.signOut);
      fixture.mutationGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ManagementEditorForm), findsNothing);
      expect(
        find.textContaining('Synthetic source review for this isolated'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'product composition, sources, revision and frozen-copy behavior are explicit',
    (tester) async {
      final fixture = R06CFixture();
      fixture.records[ManagementArea.fertilizers]!
        ..['contentEditable'] = false
        ..['rulesCount'] = 1;
      await fixture.mount(tester, location: '/admin/manage?area=fertilizers');
      expect(find.textContaining('N 12.50%'), findsOneWidget);
      expect(find.textContaining('Frozen product:'), findsOneWidget);
      expect(find.textContaining('Composition information'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Edit product metadata'),
            )
            .onPressed,
        isNull,
      );
      await r06Tap(tester, find.text('Copy product to a new slug'));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('management-product.slug')),
            )
            .controller!
            .text,
        '',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('management-product.nitrogenPercent')),
            )
            .controller!
            .text,
        '12.50',
      );
      await r06bEnter(
        tester,
        'management-product.slug',
        'new-synthetic-product',
      );
      await r06bEnter(
        tester,
        'management-reviewNote',
        'Synthetic reviewed product source for isolated UI test.',
      );
      await r06Tap(tester, find.byType(CheckboxListTile));
      await r06Tap(tester, find.text('Save product metadata'));
      final body = jsonDecode(fixture.writes.single.body) as Map;
      expect(fixture.writes.single.method, 'POST');
      expect(body.containsKey('expectedRevision'), isFalse);
      expect((body['product'] as Map)['nitrogenPercent'], '12.50');
      expect(body.containsKey('rateKgPerHectare'), isFalse);
    },
  );
  testWidgets(
    'product conflict retains fields and numeric validation rejects out-of-range percentages',
    (tester) async {
      final fixture = R06CFixture();
      await fixture.mount(tester, location: '/admin/manage?area=fertilizers');
      await r06Tap(tester, find.text('Edit product metadata'));
      await r06bEnter(tester, 'management-product.nitrogenPercent', '100.01');
      await r06Tap(tester, find.text('Save product metadata'));
      expect(fixture.writes, isEmpty);
      expect(
        find.text('Enter 0–100 with up to 2 decimal places.'),
        findsOneWidget,
      );
      await r06bEnter(tester, 'management-product.nitrogenPercent', '12.50');
      await r06bEnter(
        tester,
        'management-reviewNote',
        'Synthetic reviewed product source for isolated UI test.',
      );
      await r06Tap(tester, find.byType(CheckboxListTile));
      fixture.mutationStatus = 409;
      await r06Tap(tester, find.text('Save product metadata'));
      expect(find.textContaining('Version conflict:'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('management-product.nitrogenPercent')),
            )
            .controller!
            .text,
        '12.50',
      );
      expect(
        (jsonDecode(fixture.writes.single.body) as Map)['expectedRevision'],
        'a' * 64,
      );
    },
  );
  for (final area in [ManagementArea.fertilizer, ManagementArea.yieldRules]) {
    testWidgets(
      '${area.name} exact rate, assumptions, draft save and separate activation/deactivation',
      (tester) async {
        final fixture = R06CFixture();
        await fixture.mount(
          tester,
          location: '/admin/manage?area=${area.name}',
        );
        expect(find.textContaining('kg/ha'), findsWidgets);
        if (area == ManagementArea.yieldRules) {
          await r06Tap(tester, find.text('Workflow and scope'));
          expect(
            find.textContaining('not a field-specific forecast'),
            findsOneWidget,
          );
        }
        await r06Tap(tester, find.text('New version from this'));
        await r06bEnter(tester, 'management-rate', '999999.123456');
        await r06bEnter(
          tester,
          'management-reviewNote',
          'Synthetic review of source and applicability for this test.',
        );
        await r06Tap(tester, find.byType(CheckboxListTile));
        await r06Tap(tester, find.text('Save draft'));
        expect(fixture.writes.length, 1);
        final body = jsonDecode(fixture.writes.single.body) as Map;
        expect(
          area == ManagementArea.fertilizer
              ? (body['rule'] as Map)['rateKgPerHectare']
              : body['expectedYieldKgPerHectare'],
          '999999.123456',
        );
        expect(fixture.records[area]!['status'], 'DRAFT');
        await r06Tap(tester, find.text('Activate'));
        expect(fixture.writes.length, 1);
        await r06Tap(tester, find.text('Confirm'));
        expect(fixture.records[area]!['status'], 'ACTIVE');
        await r06Tap(tester, find.text('Deactivate'));
        await r06Tap(tester, find.text('Confirm'));
        expect(fixture.records[area]!['status'], 'INACTIVE');
        expect(body.containsKey('formula'), isFalse);
      },
    );
    testWidgets(
      '${area.name} rejects exponents, excess precision and impossible values without saving',
      (tester) async {
        final fixture = R06CFixture();
        await fixture.mount(
          tester,
          location: '/admin/manage?area=${area.name}',
        );
        await r06Tap(tester, find.text('New version from this'));
        for (final value in ['-1', '1e3', '1.1234567', '1000001']) {
          await r06bEnter(tester, 'management-rate', value);
          await r06Tap(tester, find.text('Save draft'));
          expect(find.textContaining('Use a decimal from 0'), findsOneWidget);
        }
        expect(fixture.writes, isEmpty);
      },
    );
  }
  for (final area in [
    ManagementArea.fertilizers,
    ManagementArea.fertilizer,
    ManagementArea.yieldRules,
    ManagementArea.modelSpecifications,
  ]) {
    testWidgets(
      '${area.name} dirty area switch and drawer leave preserve cancelled input; logout clears it',
      (tester) async {
        final fixture = R06CFixture();
        await fixture.mount(
          tester,
          location: '/admin/manage?area=${area.name}',
        );
        await r06Tap(
          tester,
          find.text(
            area == ManagementArea.fertilizers
                ? 'Edit product metadata'
                : 'New version from this',
          ),
        );
        final key = area == ManagementArea.fertilizers
            ? 'management-product.name'
            : 'management-title';
        await r06bEnter(tester, key, 'Private synthetic draft');
        final target = area == ManagementArea.yieldRules
            ? 'Fertilizer rules'
            : 'Yield rules';
        await r06Tap(tester, find.widgetWithText(ChoiceChip, target));
        await r06Tap(tester, find.text('Cancel'));
        expect(fixture.router.state.uri.queryParameters['area'], area.name);
        expect(
          tester
              .widget<TextFormField>(find.byKey(ValueKey(key)))
              .controller!
              .text,
          'Private synthetic draft',
        );
        await selectAdmin(tester, AdminDestination.overview);
        await r06Tap(tester, find.text('Cancel'));
        expect(find.byType(ManagementEditorForm), findsOneWidget);
        await tester.runAsync(fixture.admin.signOut);
        await tester.pumpAndSettle();
        expect(find.byType(ManagementEditorForm), findsNothing);
        expect(fixture.writes, isEmpty);
      },
    );
  }
  testWidgets(
    'unchanged structured specification view and advanced toggles do not dirty the editor',
    (tester) async {
      final fixture = R06CFixture();
      await fixture.mount(
        tester,
        location: '/admin/manage?area=modelSpecifications',
      );
      await r06Tap(tester, find.text('New version from this'));
      await r06Tap(tester, find.text('Advanced JSON · inputs'));
      await r06Tap(tester, find.text('Structured inputs'));
      await r06Tap(tester, find.text('Cancel editing'));
      expect(find.text('Leave unsaved changes?'), findsNothing);
      expect(find.byType(ManagementEditorForm), findsNothing);
      expect(fixture.writes, isEmpty);
    },
  );
}
