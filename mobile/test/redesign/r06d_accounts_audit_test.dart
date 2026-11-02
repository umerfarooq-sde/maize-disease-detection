import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/data/models/admin_accounts.dart';
import 'package:maizedoctor/features/admin/widgets/audit_entry_card.dart';
import 'package:maizedoctor/features/admin/widgets/admin_record_presentation.dart';
import 'package:maizedoctor/features/admin/views/farmer_management_view.dart';
import '../support/design_fonts.dart';
import 'r06d_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  });
  testWidgets(
    'exact-email/status filters wait for apply, normalize in existing repository and clear',
    (tester) async {
      final fixture = R06DFixture();
      await fixture.mount(tester, location: '/admin/farmers');
      final email = find.byKey(const Key('farmer-account-email'));
      await tester.enterText(email, 'FARMER@EXAMPLE.TEST');
      await r06dTap(tester, find.widgetWithText(ChoiceChip, 'SUSPENDED'));
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/admin/farmers'))
            .length,
        1,
      );
      await r06dTap(tester, find.text('Apply / refresh accounts'));
      expect(fixture.requests.last.url.queryParameters, {
        'limit': '20',
        'email': 'farmer@example.test',
        'status': 'SUSPENDED',
      });
      expect(find.textContaining('Applied: SUSPENDED'), findsOneWidget);
      await r06dTap(tester, find.text('Clear filters'));
      expect(fixture.requests.last.url.queryParameters, {'limit': '20'});
      expect(tester.widget<TextField>(email).controller!.text, isEmpty);
    },
  );
  testWidgets(
    'accounts paginate lazily, details use the loaded record and refresh resets pages',
    (tester) async {
      final fixture = R06DFixture()..paginate = true;
      await fixture.mount(tester, location: '/admin/farmers');
      await r06dTap(tester, find.text('Account details'));
      expect(find.textContaining('Revision:'), findsOneWidget);
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/admin/farmers'))
            .length,
        1,
      );
      await r06dTap(tester, find.text('Load more accounts'));
      expect(fixture.requests.last.url.queryParameters['cursor'], isNotNull);
      await r06dReveal(
        tester,
        find.byKey(const ValueKey('42345678-1234-4123-8123-123456789abc')),
      );
      expect(find.text('Load more accounts'), findsNothing);
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await r06dTap(tester, find.text('Apply / refresh accounts'));
      expect(
        fixture.requests.last.url.queryParameters.containsKey('cursor'),
        false,
      );
      expect(
        find.byKey(const ValueKey('42345678-1234-4123-8123-123456789abc')),
        findsNothing,
      );
      expect(find.text('Edit password'), findsNothing);
      expect(find.text('Change role'), findsNothing);
    },
  );
  testWidgets(
    'status change waits for acknowledgement and suppresses duplicate submission',
    (tester) async {
      final fixture = R06DFixture()..mutationGate = Completer();
      await fixture.mount(tester, location: '/admin/farmers');
      await r06dTap(tester, find.text('Set SUSPENDED'));
      expect(
        find.textContaining('Current loaded status: ACTIVE'),
        findsOneWidget,
      );
      expect(
        find.textContaining('All existing sessions will be revoked'),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm status change'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Status: ACTIVE'), findsOneWidget);
      expect(find.textContaining('Account status saved'), findsNothing);
      final buttons = tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(buttons.every((button) => button.onPressed == null), true);
      expect(fixture.requests.where((r) => r.method == 'PATCH').length, 1);
      final body = jsonDecode(fixture.requests.last.body) as Map;
      expect(body.keys.toSet(), {'status', 'expectedRevision'});
      fixture.mutationGate!.complete();
      await tester.pumpAndSettle();
      await r06dReveal(tester, find.text('Status: SUSPENDED'));
      expect(find.text('Status: SUSPENDED'), findsOneWidget);
      expect(find.textContaining('Account status saved'), findsOneWidget);
    },
  );
  for (final status in [409, 503]) {
    testWidgets(
      'status failure $status preserves old state and offers authoritative refresh',
      (tester) async {
        final fixture = R06DFixture()..mutationStatus = status;
        await fixture.mount(tester, location: '/admin/farmers');
        await r06dTap(tester, find.text('Set SUSPENDED'));
        await r06dTap(tester, find.text('Confirm status change'));
        expect(find.textContaining('Account status saved'), findsNothing);
        await r06dReveal(tester, find.text('Status: ACTIVE'));
        expect(find.text('Status: ACTIVE'), findsOneWidget);
        await r06dTap(tester, find.text('Try again'));
        expect(fixture.requests.last.method, 'GET');
      },
    );
  }
  testWidgets(
    'account confirmation closes with Admin session and cannot act for a new identity',
    (tester) async {
      final fixture = R06DFixture();
      await fixture.mount(tester, location: '/admin/farmers');
      await r06dTap(tester, find.text('Set SUSPENDED'));
      await fixture.admin.signOut();
      await tester.pumpAndSettle();
      expect(find.textContaining('Account: farmer@example.test'), findsNothing);
      expect(find.text('Confirm status change'), findsNothing);
      expect(find.byType(FarmerManagementView), findsNothing);
      expect(fixture.requests.where((r) => r.method == 'PATCH'), isEmpty);
    },
  );
  testWidgets(
    'ambiguous mutation timeout refreshes committed state without repeating the write',
    (tester) async {
      final fixture = R06DFixture()..lostMutationReply = true;
      await fixture.mount(tester, location: '/admin/farmers');
      await r06dTap(tester, find.text('Set SUSPENDED'));
      await r06dTap(tester, find.text('Confirm status change'));
      expect(find.textContaining('Account status saved'), findsNothing);
      expect(find.textContaining('outcome may be uncertain'), findsOneWidget);
      await r06dTap(tester, find.text('Try again'));
      await r06dReveal(tester, find.text('Status: SUSPENDED'));
      expect(find.text('Status: SUSPENDED'), findsOneWidget);
      expect(fixture.requests.where((r) => r.method == 'PATCH').length, 1);
    },
  );
  for (final path in ['/admin/farmers', '/admin/audit']) {
    testWidgets('$path discards delayed refresh after identity change', (
      tester,
    ) async {
      final fixture = R06DFixture();
      await fixture.mount(tester, location: path);
      final gate = Completer<void>();
      if (path.endsWith('farmers')) {
        fixture.accountGate = gate;
      } else {
        fixture.auditGate = gate;
      }
      final apply = find.text(
        path.endsWith('farmers')
            ? 'Apply / refresh accounts'
            : 'Apply / refresh audit filters',
      );
      await r06dReveal(tester, apply);
      await tester.tap(apply);
      await tester.pump();
      await fixture.admin.signOut();
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Fixture farmer'), findsNothing);
      expect(find.text('Farmer account status change'), findsNothing);
      fixture.accountGate = null;
      fixture.auditGate = null;
      fixture.accountsEmpty = true;
      fixture.auditsEmpty = true;
      await fixture.admin.signIn(
        'admin.second@example.test',
        'synthetic-password',
      );
      await tester.pumpAndSettle();
      await r06dReveal(
        tester,
        find.text(
          path.endsWith('farmers')
              ? 'No farmer accounts match'
              : 'No recorded actions match',
        ),
      );
      expect(find.text('Fixture farmer'), findsNothing);
      expect(find.text('Farmer account status change'), findsNothing);
    });
  }
  testWidgets(
    'audit filters retain literal UTC dates and exact actor; apply and clear are explicit',
    (tester) async {
      final fixture = R06DFixture();
      await fixture.mount(tester, location: '/admin/audit');
      await r06dTap(tester, find.byType(DropdownButtonFormField<String>).first);
      await tester.tap(find.text('Deactivation recorded').last);
      await tester.pumpAndSettle();
      final actor = '32345678-1234-4123-8123-123456789abc';
      for (final entry in [
        ('audit-actor', actor),
        ('audit-from', '2026-10-15'),
        ('audit-to', '2026-10-16'),
      ]) {
        await r06dReveal(tester, find.byKey(Key(entry.$1)));
        await tester.enterText(find.byKey(Key(entry.$1)), entry.$2);
      }
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/admin/audit-logs'))
            .length,
        1,
      );
      await r06dTap(tester, find.byKey(const Key('audit-filter')));
      expect(fixture.requests.last.url.queryParameters, {
        'limit': '20',
        'action': 'DEACTIVATE',
        'actorId': actor,
        'from': '2026-10-15',
        'to': '2026-10-16',
      });
      await r06dTap(tester, find.text('Clear filters'));
      expect(fixture.requests.last.url.queryParameters, {'limit': '20'});
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/admin/audit-logs'))
            .every((r) => r.method == 'GET'),
        true,
      );
    },
  );
  testWidgets(
    'audit details preserve metadata, original codes and read-only semantics across pages',
    (tester) async {
      final fixture = R06DFixture()..paginate = true;
      await fixture.mount(tester, location: '/admin/audit');
      await r06dTap(tester, find.text('Recorded event details'));
      expect(
        find.textContaining('Original action: DEACTIVATE'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Original entity: farmer_account'),
        findsOneWidget,
      );
      expect(find.text('Revoked sessions: 2'), findsOneWidget);
      expect(find.textContaining('does not establish success'), findsOneWidget);
      expect(find.textContaining('2026-10-15T00:00:00.000Z'), findsWidgets);
      await r06dTap(tester, find.text('Load more audit records'));
      expect(fixture.requests.last.url.queryParameters['cursor'], isNotNull);
      await r06dReveal(
        tester,
        find.byKey(const ValueKey('52345678-1234-4123-8123-123456789abc')),
      );
      expect(find.text('Load more audit records'), findsNothing);
      expect(find.text('Delete Event'), findsNothing);
      expect(find.text('Edit Event'), findsNothing);
    },
  );
  test(
    'known actions have readable labels and unknown codes have a safe fallback',
    () {
      for (final code in accountAuditActions) {
        expect(auditActionLabel(code), isNot(contains('_')));
      }
      expect(auditActionLabel('FUTURE_EVENT'), 'Recorded event · future event');
      expect(auditEntityLabel('future_entity'), 'Other recorded entity');
    },
  );
  testWidgets(
    'unknown typed event retains original code in technical disclosure',
    (tester) async {
      final entry = AdminAuditEntry(
        'id',
        'FUTURE_EVENT',
        'future_entity',
        'target',
        DateTime.utc(2026),
        null,
        null,
        const {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AuditEntryCard(entry: entry)),
          ),
        ),
      );
      expect(find.text('Recorded event · future event'), findsOneWidget);
      await tester.tap(find.text('Recorded event details'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Original action: FUTURE_EVENT'),
        findsOneWidget,
      );
      expect(find.text('Actor identity unavailable'), findsOneWidget);
    },
  );
  for (final path in [
    '/admin/farmers',
    '/admin/audit',
    '/admin/model-health',
  ]) {
    testWidgets(
      '$path rejects guest/Farmer sessions and clears private content after sign-out',
      (tester) async {
        final fixture = R06DFixture();
        await fixture.mount(tester, location: path, signedIn: false);
        await fixture.farmer.signIn(
          'farmer@example.test',
          'synthetic-password',
        );
        await tester.pumpAndSettle();
        expect(
          fixture.requests.where((r) => r.url.path.contains('/admin/')),
          isEmpty,
        );
        await fixture.admin.signIn('admin@example.test', 'synthetic-password');
        await tester.pumpAndSettle();
        expect(
          fixture.requests.where((r) => r.url.path.contains('/admin/')).length,
          1,
        );
        await fixture.admin.signOut();
        await tester.pumpAndSettle();
        expect(find.text('Admin sign-in'), findsOneWidget);
        expect(fixture.farmer.signedIn, true);
        expect(find.text('Fixture farmer'), findsNothing);
        expect(
          find.text('Offline evaluation — research evidence'),
          findsNothing,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(fixture.router.state.uri.path, '/admin');
      },
    );
  }
}
