import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/data/models/scan_history_page.dart';
import 'package:maizedoctor/features/profile/view_models/profile_view_model.dart';
import 'package:maizedoctor/features/profile/views/profile_editor_view.dart';
import 'package:maizedoctor/features/scan_history/view_models/scan_history_view_model.dart';
import 'package:maizedoctor/features/analytics/widgets/analytics_charts.dart';
import 'package:maizedoctor/features/analytics/widgets/analytics_cards.dart';
import 'package:maizedoctor/features/tools/widgets/planning_disclosure.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import '../history/helpers.dart';
import '../history/widget_test.dart' as history;
import '../profile/helpers.dart';
import '../profile/widget_test.dart' show pumpProfile;
import '../support/design_fonts.dart';
import 'r05_fixtures.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'Tools navigation fetches configuration only inside each calculator',
    (tester) async {
      final fixture = R05Fixture()..pending = true;
      await fixture.mount(tester, signedIn: false);
      expect(fixture.paths.where((p) => p.contains('calculators')), isEmpty);
      await tap(tester, find.text('Fertilizer planning'));
      expect(fixture.router.state.uri.path, AppRoutes.fertilizer);
      expect(
        find.text('Approved fertilizer rules are pending'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Yield planning'));
      expect(fixture.router.state.uri.path, AppRoutes.yieldCalculator);
      expect(find.text('Yield configuration pending'), findsOneWidget);
      expect(fixture.paths.where((p) => p.endsWith('/calculate')), isEmpty);
    },
  );

  testWidgets(
    'date groups continue across cursor boundary without sorting or duplicate header',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 1800);
      addTearDown(tester.view.reset);
      ScanRecord dated(int index, String timestamp) {
        final json = historyScanJson(index);
        return ScanRecord.fromJson({
          ...json,
          'createdAt': timestamp,
          'finishedAt': timestamp,
          'prediction': {
            ...json['prediction'] as Map<String, Object?>,
            'inferredAt': timestamp,
          },
        });
      }

      final first = dated(1, '2026-10-08T12:00:00Z');
      final second = dated(2, '2026-10-08T11:00:00Z');
      final third = dated(3, '2026-10-07T12:00:00Z');
      final repository = FakeScanRecordsRepository()
        ..responses.add(
          Future.value(ScanHistoryPage(items: [first], nextCursor: first.id)),
        );
      final model = ScanHistoryViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(history.page(model));
      repository.responses.add(
        Future.value(ScanHistoryPage(items: [second, third], nextCursor: null)),
      );
      await tap(tester, find.byKey(const Key('history-load-more')));
      expect(model.items.map((s) => s.id), [first.id, second.id, third.id]);
      expect(repository.requests.last.cursor, first.id);
      final day = first.createdAt.toLocal();
      expect(
        find.byKey(
          ValueKey('history-date-${day.year}-${day.month}-${day.day}'),
        ),
        findsOneWidget,
      );
      final previous = third.createdAt.toLocal();
      expect(
        find.byKey(
          ValueKey(
            'history-date-${previous.year}-${previous.month}-${previous.day}',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'planning disclosure can reopen after selectable text stores scroll state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PlanningDisclosure(
                title: 'Exact server evidence',
                child: Column(
                  children: [
                    SelectableText('123456789012345.125 kg'),
                    SizedBox(height: 800),
                    Text('Evidence footer'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Exact server evidence'));
      await tester.ensureVisible(find.text('Evidence footer'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Exact server evidence'));
      await tap(tester, find.text('Exact server evidence'));
      expect(find.text('123456789012345.125 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Field insights exposes actual chart counts and semantic dates, never accuracy',
    (tester) async {
      final fixture = R05Fixture();
      await fixture.mount(tester);
      await fixture.go(tester, AppRoutes.analytics);
      final chart = tester.widget<ScanActivityChart>(
        find.byType(ScanActivityChart),
      );
      expect(chart.periods.fold<int>(0, (sum, p) => sum + p.count), 8);
      final summary = tester
          .widget<AnalyticsSummaryCards>(find.byType(AnalyticsSummaryCards))
          .summary;
      expect(summary.totals['totalScans'], 8);
      await tester.ensureVisible(find.text('Scans over time'));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp(r'UTC: \d+ scans')), findsWidgets);
      expect(find.textContaining('accuracy', findRichText: true), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'ambiguous avatar upload shows reconciled state without duplicate write or false success',
    (tester) async {
      final repo = FakeProfileRepository()
        ..uploadAcknowledgementFailure = const AppException(
          AppErrorKind.timeout,
        );
      await pumpProfile(tester, repo);
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('profile-choose-photo')));
      await tap(tester, find.text('Upload selected photo'));
      final model = tester
          .element(find.byType(ProfileEditorView))
          .read<ProfileViewModel>();
      expect(repo.uploads, 1);
      expect(repo.reads, 2);
      expect(model.data!.avatarUrl, isNotNull);
      expect(model.photo, isNull);
      expect(find.text('Your profile photo is saved.'), findsNothing);
      expect(find.text('Reload saved profile'), findsOneWidget);
    },
  );

  testWidgets(
    'saved-avatar removal requires confirmation and remains one mutation',
    (tester) async {
      final repo = FakeProfileRepository();
      await pumpProfile(tester, repo);
      await tester.pumpAndSettle();
      final model = tester
          .element(find.byType(ProfileEditorView))
          .read<ProfileViewModel>();
      await model.choosePhoto();
      await model.uploadPhoto();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Remove saved photo'));
      expect(repo.removals, 0);
      await tap(tester, find.text('Cancel'));
      expect(model.data!.avatarUrl, isNotNull);
      await tap(tester, find.text('Remove saved photo'));
      await tap(tester, find.text('Remove photo'));
      expect(repo.removals, 1);
      expect(model.data!.avatarUrl, isNull);
      expect(find.text('Your profile photo was removed.'), findsOneWidget);
    },
  );
}
