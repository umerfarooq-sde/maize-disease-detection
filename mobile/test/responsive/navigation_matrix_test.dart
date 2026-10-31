import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/data/models/backend_health.dart';
import 'package:maizedoctor/data/repositories/backend_repository.dart';
import 'package:maizedoctor/features/home/views/home_view.dart';
import 'package:maizedoctor/features/shell/views/farmer_shell.dart';
import '../scans/helpers.dart';

class _OfflineBackend implements BackendRepository {
  @override
  Future<BackendHealth> checkConnection() => Completer<BackendHealth>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final config in <(Size, double)>[
    (const Size(320, 568), 1),
    (const Size(320, 740), 2),
    (const Size(360, 800), 1),
    (const Size(480, 800), 1.5),
    (const Size(768, 1024), 1),
    (const Size(840, 900), 2),
    (const Size(1280, 900), 1),
  ]) {
    testWidgets('farmer navigation ${config.$1.width}dp scale ${config.$2}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = config.$1;
      tester.platformDispatcher.textScaleFactorTestValue = config.$2;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(
        MainApp(
          repository: _OfflineBackend(),
          scanRepository: FakeScanRepository(),
          httpClient: MockClient((_) async => http.Response('{}', 503)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FarmerShell), findsOneWidget);
      expect(
        find.byType(NavigationRail),
        config.$1.width >= 840 ? findsOneWidget : findsNothing,
      );
      final router = GoRouter.of(tester.element(find.byType(HomeView)));
      for (final route in [
        AppRoutes.scan,
        AppRoutes.tools,
        AppRoutes.profile,
        AppRoutes.home,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route at $config');
      }
    });
  }
}
