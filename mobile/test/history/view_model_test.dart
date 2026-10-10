import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/scan_history_page.dart';
import 'package:maizedoctor/features/scan_history/view_models/scan_history_view_model.dart';
import 'helpers.dart';

void main() {
  test('guest history stays empty without querying personal records', () async {
    final repository = FakeScanRecordsRepository()
      ..hasAuthenticatedSession = false;
    final model = ScanHistoryViewModel(repository);
    addTearDown(model.dispose);
    await model.load();
    await model.refresh();
    await model.loadMore();
    expect(repository.requests, isEmpty);
    expect(model.items, isEmpty);
    expect(model.hasAuthenticatedSession, false);
  });

  test(
    'initial page loading is explicit, suppresses duplicates and preserves cursor',
    () async {
      final pending = Completer<ScanHistoryPage>();
      final repository = FakeScanRecordsRepository()
        ..responses.add(pending.future);
      final model = ScanHistoryViewModel(repository);
      addTearDown(model.dispose);
      final loading = model.load();
      expect(model.isLoading, true);
      await model.load();
      expect(repository.requests.length, 1);
      pending.complete(
        ScanHistoryPage(items: [historyScan(1)], nextCursor: historyId(1)),
      );
      await loading;
      expect(model.isLoading, false);
      expect(model.items.single.id, historyId(1));
      expect(model.hasMore, true);
    },
  );

  test(
    'load more deduplicates records and retains previous items after a recoverable error',
    () async {
      final repository = FakeScanRecordsRepository()
        ..responses.add(
          Future.value(
            ScanHistoryPage(items: [historyScan(1)], nextCursor: historyId(1)),
          ),
        );
      final model = ScanHistoryViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      repository.responses.add(
        Future.error(const AppException(AppErrorKind.network)),
      );
      await model.loadMore();
      expect(model.items.single.id, historyId(1));
      expect(model.loadMoreError?.kind, AppErrorKind.network);
      expect(model.hasMore, true);
      repository.responses.add(
        Future.value(
          ScanHistoryPage(
            items: [historyScan(1), historyScan(2)],
            nextCursor: null,
          ),
        ),
      );
      await model.loadMore();
      expect(model.items.map((item) => item.id), [historyId(1), historyId(2)]);
      expect(model.loadMoreError, null);
      expect(model.hasMore, false);
      expect(repository.requests.last.cursor, historyId(1));
    },
  );

  test(
    'refresh invalidates an older load-more request and replaces the list',
    () async {
      final more = Completer<ScanHistoryPage>();
      final refreshed = Completer<ScanHistoryPage>();
      final repository = FakeScanRecordsRepository()
        ..responses.add(
          Future.value(
            ScanHistoryPage(items: [historyScan(1)], nextCursor: historyId(1)),
          ),
        )
        ..responses.add(more.future)
        ..responses.add(refreshed.future);
      final model = ScanHistoryViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      final oldRequest = model.loadMore();
      expect(model.isLoadingMore, true);
      final refresh = model.refresh();
      refreshed.complete(
        ScanHistoryPage(items: [historyScan(3)], nextCursor: null),
      );
      await refresh;
      more.complete(ScanHistoryPage(items: [historyScan(2)], nextCursor: null));
      await oldRequest;
      expect(model.items.single.id, historyId(3));
      expect(model.isLoadingMore, false);
    },
  );

  test(
    'session expiry clears personal records and returns to the sign-in boundary',
    () async {
      final repository = FakeScanRecordsRepository()
        ..responses.add(
          Future.value(
            ScanHistoryPage(items: [historyScan(1)], nextCursor: historyId(1)),
          ),
        );
      final model = ScanHistoryViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      repository.responses.add(
        Future.error(const AppException(AppErrorKind.authentication)),
      );
      await model.loadMore();
      expect(model.items, isEmpty);
      expect(model.hasAuthenticatedSession, false);
      expect(model.hasMore, false);
    },
  );

  test('sign-out during loading discards late private results', () async {
    final pending = Completer<ScanHistoryPage>();
    final repository = FakeScanRecordsRepository()
      ..responses.add(pending.future);
    final model = ScanHistoryViewModel(repository);
    addTearDown(model.dispose);
    final request = model.load();
    repository.hasAuthenticatedSession = false;
    pending.complete(
      ScanHistoryPage(items: [historyScan(1)], nextCursor: null),
    );
    await request;
    expect(model.items, isEmpty);
    expect(model.isLoading, false);
  });

  test('disposed history does not notify or retain a late response', () async {
    final pending = Completer<ScanHistoryPage>();
    final repository = FakeScanRecordsRepository()
      ..responses.add(pending.future);
    final model = ScanHistoryViewModel(repository);
    var notifications = 0;
    model.addListener(() => notifications++);
    final request = model.load();
    final before = notifications;
    model.dispose();
    pending.complete(
      ScanHistoryPage(items: [historyScan(1)], nextCursor: null),
    );
    await request;
    expect(notifications, before);
    expect(model.items, isEmpty);
  });

  test(
    'unknown failures expose only safe state and refresh retries the first page',
    () async {
      final repository = FakeScanRecordsRepository()
        ..responses.add(Future.error(StateError('private-provider-message')));
      final model = ScanHistoryViewModel(repository);
      addTearDown(model.dispose);
      await model.load();
      expect(model.error?.kind, AppErrorKind.server);
      expect(model.error?.message, isNot(contains('private-provider-message')));
      repository.responses.add(
        Future.value(
          ScanHistoryPage(items: [historyScan(2)], nextCursor: null),
        ),
      );
      await model.refresh();
      expect(model.error, null);
      expect(model.items.single.id, historyId(2));
      expect(repository.requests.last.cursor, null);
    },
  );
}
