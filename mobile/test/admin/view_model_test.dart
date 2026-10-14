import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/models/admin_dashboard.dart';
import 'package:maizedoctor/features/admin/view_models/admin_dashboard_view_model.dart';
import '../analytics/helpers.dart' show clock;
import 'helpers.dart';

void main() {
  test(
    'dashboard loads server aggregates, filters, safe failure and retry without retaining old counts',
    () async {
      final repository = FakeAdminRepository();
      final model = AdminDashboardViewModel(repository, now: () => clock);
      addTearDown(model.dispose);
      await model.load();
      expect(model.data!.scans.totals['totalScans'], 8);
      expect(repository.calls.single.days, 30);
      await model.selectDays(7);
      expect(repository.calls.last.days, 7);
      repository.respond = (_) async =>
          throw const AppException(AppErrorKind.network);
      await model.load();
      expect(model.data, isNull);
      expect(model.error!.kind, AppErrorKind.network);
      repository.respond = (range) async =>
          AdminDashboard.fromJson(dashboardJson(range: range, empty: true));
      await model.load();
      expect(model.error, isNull);
      expect(model.data!.scans.totals['totalScans'], 0);
    },
  );
  test(
    'no session requests no data; sign-out and identity revisions immediately hide private system counts',
    () async {
      final repository = FakeAdminRepository()..hasSession = false;
      final model = AdminDashboardViewModel(repository, now: () => clock);
      addTearDown(model.dispose);
      await model.load();
      expect(repository.calls, isEmpty);
      repository.hasSession = true;
      await model.load();
      expect(model.data, isNotNull);
      repository.revision = 2;
      expect(model.data, isNull);
      repository.hasSession = false;
      expect(model.data, isNull);
    },
  );
  test(
    'late dashboard responses after revision change, disposal or a new filter never restore old data',
    () async {
      for (final action in ['revision', 'dispose', 'filter']) {
        final repository = FakeAdminRepository();
        final gate = Completer<AdminDashboard>();
        repository.respond = (_) => gate.future;
        final model = AdminDashboardViewModel(repository, now: () => clock);
        final pending = model.load();
        final original = model.range;
        if (action == 'revision') repository.revision = 2;
        if (action == 'dispose') model.dispose();
        if (action == 'filter') {
          repository.respond = (range) async =>
              AdminDashboard.fromJson(dashboardJson(range: range));
          await model.selectDays(7);
        }
        gate.complete(AdminDashboard.fromJson(dashboardJson(range: original)));
        await pending;
        if (action == 'filter') {
          expect(model.data!.scans.range.days, 7);
        } else {
          expect(model.data, isNull);
        }
        if (action != 'dispose') model.dispose();
      }
    },
  );
}
