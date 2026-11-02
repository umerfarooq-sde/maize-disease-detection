import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/features/admin/widgets/admin_navigation.dart';
import 'package:maizedoctor/features/admin/views/admin_access_view.dart';
import 'package:maizedoctor/features/admin/view_models/admin_management_view_model.dart';
import 'package:maizedoctor/features/admin/views/admin_management_view.dart';
import 'package:maizedoctor/features/admin/views/ai_operations_view.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';

Finder navItem(AdminDestination destination) => find.descendant(
  of: find.byType(AdminNavigation),
  matching: find.byKey(ValueKey('admin-nav-${destination.name}')),
);
Future<void> selectAdmin(
  WidgetTester tester,
  AdminDestination destination,
) async {
  final menu = find.byTooltip('Open Admin navigation');
  if (menu.evaluate().isNotEmpty) await r06Tap(tester, menu);
  final scroll = find.descendant(
    of: find.byType(AdminNavigation),
    matching: find.byType(Scrollable),
  );
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    navItem(destination),
    300,
    scrollable: scroll,
  );
  await r06Tap(tester, navItem(destination));
}

void main() {
  setUpAll(loadDesignFonts);
  for (final width in [412.0, 1280.0]) {
    testWidgets(
      'all twelve Admin destinations work through labelled navigation at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 915);
        addTearDown(tester.view.reset);
        final fixture = R06Fixture();
        await fixture.mount(tester);
        expect(find.byType(NavigationBar), findsNothing);
        for (final destination in AdminDestination.values) {
          await selectAdmin(tester, destination);
          expect(fixture.router.state.uri.toString(), destination.location);
          if (destination.area != null) {
            final model = tester
                .element(find.byType(AdminManagementView))
                .read<AdminManagementViewModel>();
            expect(model.area, destination.area);
            expect(
              find.text(switch (destination.area) {
                ManagementArea.diseases => 'Disease catalogue',
                ManagementArea.knowledge => 'Knowledge documents',
                _ => 'Knowledge & configuration',
              }),
              findsOneWidget,
            );
          }
          if (width >= 840) {
            final navigation = tester.widget<AdminNavigation>(
              find.byType(AdminNavigation),
            );
            expect(navigation.selected, destination);
            final link = tester.widget<AdminNavigationLink>(
              find
                  .ancestor(
                    of: navItem(destination),
                    matching: find.byType(AdminNavigationLink),
                  )
                  .first,
            );
            expect(link.selected, isTrue);
          } else {
            expect(find.byType(Drawer), findsNothing);
          }
          expect(tester.takeException(), isNull, reason: destination.label);
        }
        expect(
          fixture.requests
              .where((r) => r.url.path.endsWith('/admin/dashboard'))
              .length,
          1,
        );
        expect(
          fixture.requests
              .where((r) => r.url.path.endsWith('/admin/ai-operations'))
              .length,
          1,
        );
        expect(
          fixture.requests
              .where((r) => r.url.path.contains('/admin/'))
              .every((r) => r.method == 'GET'),
          isTrue,
        );
      },
    );
  }

  testWidgets(
    'legacy management links and chips select actual areas and keep the active route in sync',
    (tester) async {
      final fixture = R06Fixture();
      await fixture.mount(tester, location: '/admin/manage');
      expect(
        fixture.requests.any(
          (r) => r.url.path.endsWith('/admin/knowledge/documents'),
        ),
        isTrue,
      );
      expect(
        fixture.requests.any((r) => r.url.path.endsWith('/admin/dashboard')),
        isFalse,
      );
      await r06Tap(tester, find.widgetWithText(ChoiceChip, 'Diseases'));
      expect(fixture.router.state.uri.queryParameters['area'], 'diseases');
      expect(
        fixture.requests.last.url.path,
        '/api/v1/admin/knowledge/diseases',
      );
      await fixture.go(tester, '/admin/manage?area=unrecognized');
      expect(
        tester
            .element(find.byType(AdminManagementView))
            .read<AdminManagementViewModel>()
            .area
            .name,
        'knowledge',
      );
    },
  );

  testWidgets(
    'guest and Farmer sessions cannot load Admin reports; Admin sign-out preserves Farmer session',
    (tester) async {
      final fixture = R06Fixture();
      await fixture.mount(
        tester,
        location: '/admin/ai-operations',
        signedIn: false,
      );
      expect(fixture.requests, isEmpty);
      await tester.runAsync(
        () =>
            fixture.farmer.signIn('farmer@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Administrator sign-in'), findsOneWidget);
      expect(
        fixture.requests.where((r) => r.url.path.contains('/admin/')),
        isEmpty,
      );
      await tester.runAsync(
        () => fixture.admin.signIn('admin@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AiOperationsView), findsOneWidget);
      await r06Tap(tester, find.byTooltip('Workspace actions'));
      await r06Tap(tester, find.text('Admin Sign Out'));
      expect(fixture.admin.signedIn, isFalse);
      expect(fixture.farmer.signedIn, isTrue);
      expect(find.byType(AiOperationsView), findsNothing);
      expect(find.text('Registered farmers'), findsNothing);
      await r06Tap(tester, find.byTooltip('Workspace actions'));
      await r06Tap(tester, find.text('Return to Farmer App'));
      expect(fixture.router.state.uri.path, AppRoutes.home);
      expect(find.byType(AdminAccessView), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets(
    'a Farmer token returned to Admin login is rejected and revoked',
    (tester) async {
      final fixture = R06Fixture()..farmerGrant = true;
      await fixture.mount(tester);
      expect(fixture.admin.signedIn, isFalse);
      expect(find.text('You do not have access to this area.'), findsOneWidget);
      expect(
        fixture.requests.where((r) => r.url.path.contains('/admin/')),
        isEmpty,
      );
      expect(fixture.requests.last.url.path, '/api/v1/auth/logout');
    },
  );

  testWidgets(
    'Android Back closes the drawer, then returns direct Operations to Overview and Farmer',
    (tester) async {
      final fixture = R06Fixture();
      await fixture.mount(tester, location: '/admin/ai-operations');
      await r06Tap(tester, find.byTooltip('Open Admin navigation'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.router.state.uri.path, '/admin/ai-operations');
      expect(find.byType(Drawer), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.router.state.uri.path, '/admin');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.router.state.uri.path, '/home');
    },
  );

  testWidgets(
    'workspace header identifies the real Admin and Back returns to its originating Profile',
    (tester) async {
      final fixture = R06Fixture();
      await fixture.mount(tester);
      await r06Tap(tester, find.byTooltip('Workspace actions'));
      expect(
        find.text('Signed in as Admin\nadmin@example.test'),
        findsOneWidget,
      );
      await r06Tap(tester, find.text('Return to Farmer App'));
      expect(fixture.admin.signedIn, isTrue);
      await fixture.go(tester, '/profile');
      fixture.router.push('/admin');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.router.state.uri.path, '/profile');
    },
  );

  testWidgets(
    'active sidebar destination is announced and Admin actions meet Android tap-target guidance',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 1000);
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final fixture = R06Fixture();
      await fixture.mount(tester);
      final selected = find.descendant(
        of: find.byType(AdminNavigation),
        matching: find.byKey(const ValueKey('admin-semantic-overview')),
      );
      expect(
        tester
            .getSemantics(selected)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
        reason:
            'The selected sidebar route must remain exposed beside the nested Navigator.',
      );
      expect(tester.getSemantics(selected).label, 'System Overview');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );
}
