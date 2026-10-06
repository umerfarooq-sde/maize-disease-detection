import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/core/widgets/app_page.dart';
import 'package:maizedoctor/core/widgets/app_states.dart';
import 'package:maizedoctor/data/models/backend_health.dart';
import 'package:maizedoctor/data/repositories/backend_repository.dart';
import 'package:maizedoctor/features/home/view_models/home_view_model.dart';
import 'package:maizedoctor/features/home/views/home_view.dart';
import '../scans/helpers.dart';

class WidgetRepository implements BackendRepository {
  final Completer<BackendHealth> result = Completer();
  @override
  Future<BackendHealth> checkConnection() => result.future;
}

Future<void> pumpApp(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double scale = 1,
  String route = AppRoutes.home,
  BackendRepository? repository,
  Widget Function(Widget)? wrapper,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final app = MainApp(
    initialLocation: route,
    repository: repository,
    scanRepository: FakeScanRepository(),
  );
  await tester.pumpWidget(wrapper?.call(app) ?? app);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final sdkRoot = Platform.environment['FLUTTER_ROOT'];
    if (sdkRoot == null) {
      throw StateError('Run these tests using flutter test.');
    }
    for (final font in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final bytes = await File(
        '$sdkRoot/bin/cache/artifacts/material_fonts/${font.value}',
      ).readAsBytes();
      final loader = FontLoader(font.key)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  testWidgets('primary Scan Leaf is visible on a small phone and navigates', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(320, 568));
    final action = find.byKey(const Key('scan-leaf-action'));
    expect(action.hitTestable(), findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Scan a maize leaf'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915),
    const Size(640, 360),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1024, 360),
  ]) {
    testWidgets('five farmer areas fit ${size.width}x${size.height}', (
      tester,
    ) async {
      await pumpApp(tester, size: size);
      for (final label in ['Scan', 'Knowledge', 'Tools', 'Profile', 'Home']) {
        await tester.ensureVisible(find.text(label).last);
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      expect(
        find.byType(NavigationRail),
        size.width >= 840 ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('large text preserves all areas and navigation state', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(320, 568), scale: 2);
    final homeContext = tester.element(find.byType(HomeView));
    final original = homeContext.read<HomeViewModel>();
    for (final route in [
      AppRoutes.scan,
      AppRoutes.knowledge,
      AppRoutes.tools,
      AppRoutes.profile,
      AppRoutes.home,
    ]) {
      GoRouter.of(homeContext).go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
    expect(
      tester.element(find.byType(HomeView)).read<HomeViewModel>(),
      same(original),
    );
  });

  testWidgets(
    'nested routes support back; unknown/admin routes expose no data',
    (tester) async {
      await pumpApp(tester, route: AppRoutes.tools);
      final router = GoRouter.of(
        tester.element(find.text('Tools for your field')),
      );
      for (final route in [
        AppRoutes.fertilizer,
        AppRoutes.yieldCalculator,
        AppRoutes.assistant,
        AppRoutes.auth,
        AppRoutes.history,
        AppRoutes.analytics,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        expect(find.byType(BackButton), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
      }
      router.go(AppRoutes.admin);
      await tester.pumpAndSettle();
      expect(find.text('Admin workspace is not available'), findsOneWidget);
      router.go('/unknown/private-path');
      await tester.pumpAndSettle();
      expect(find.text('This page is not available'), findsOneWidget);
      expect(find.textContaining('private-path'), findsNothing);
    },
  );

  testWidgets('connection UI shows loading, safe error and retry', (
    tester,
  ) async {
    final repository = WidgetRepository();
    await pumpApp(tester, repository: repository);
    final check = find.text('Check connection');
    await tester.ensureVisible(check);
    await tester.tap(check);
    await tester.pump();
    expect(find.byType(AppLoadingState), findsOneWidget);
    repository.result.completeError(const AppException(AppErrorKind.network));
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'scroll surface accommodates keyboard, safe insets and long content',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppPage(
              child: Column(
                children: [
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Future field input',
                    ),
                  ),
                  Text('Long readable content. ' * 60),
                  FilledButton(onPressed: () {}, child: const Text('Continue')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home controls meet tap, label and text contrast guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpApp(tester, size: const Size(412, 915));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('empty and error states remain readable with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: AppPage(
              child: AppErrorState(
                error: const AppException(AppErrorKind.timeout),
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'capture rendered phone and tablet foundation for visual review',
    (tester) async {
      for (final size in [
        const Size(320, 568),
        const Size(360, 800),
        const Size(1024, 768),
      ]) {
        final boundaryKey = GlobalKey();
        await pumpApp(
          tester,
          size: size,
          wrapper: (app) => RepaintBoundary(key: boundaryKey, child: app),
        );
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/phase5-preview-${size.width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
