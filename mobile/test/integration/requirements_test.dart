import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/features/auth/views/auth_intro_view.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:maizedoctor/features/profile/views/profile_editor_view.dart';
import 'package:maizedoctor/features/profile/view_models/profile_view_model.dart';
import 'package:maizedoctor/features/admin/views/admin_access_view.dart';
import 'package:maizedoctor/features/admin/views/farmer_management_view.dart';
import 'package:maizedoctor/features/admin/views/audit_log_view.dart';
import 'package:maizedoctor/features/admin/view_models/admin_session_view_model.dart';
import 'package:maizedoctor/features/admin/view_models/admin_dashboard_view_model.dart';
import 'package:maizedoctor/features/admin/views/admin_dashboard_view.dart';
import 'package:maizedoctor/features/admin/view_models/farmer_management_view_model.dart';
import 'package:maizedoctor/features/admin/view_models/audit_log_view_model.dart';
import 'scan_upload_test.dart' show FixtureImageSource;

const _enabled = bool.fromEnvironment('RUN_LIVE_REQUIREMENTS');

class _RealHttpBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  if (_enabled) _RealHttpBinding();
  testWidgets(
    'real private profile/photo persistence, restart, Admin status confirmation and audit history',
    (tester) async {
      await tester.runAsync(() async {
        final farmer =
            jsonDecode(Platform.environment['REQUIREMENTS_FARMER']!)
                as Map<String, dynamic>;
        final admin =
            jsonDecode(Platform.environment['REQUIREMENTS_ADMIN']!)
                as Map<String, dynamic>;
        Future<void> until(bool Function() ready) async {
          final deadline = DateTime.now().add(const Duration(seconds: 105));
          while (!ready() && DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await tester.pump();
          }
          expect(
            ready(),
            true,
            reason: 'The live widget/API operation did not finish.',
          );
          await tester.pump();
        }

        Future<void> tap(Finder finder) async {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump();
          await Scrollable.ensureVisible(
            tester.element(finder),
            alignment: 0.5,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(finder.hitTestable(), findsOneWidget);
          await tester.tap(finder);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        }

        Future<void> mount() async {
          await tester.pumpWidget(
            MainApp(
              config: AppConfig.fromEnvironment(),
              initialLocation: AppRoutes.auth,
              profileImages: FixtureImageSource(),
            ),
          );
          await tester.pump();
        }

        Future<FarmerSessionViewModel> signIn() async {
          await tester.enterText(
            find.byType(TextFormField).first,
            farmer['email'] as String,
          );
          await tester.enterText(
            find.byType(TextFormField).last,
            farmer['password'] as String,
          );
          final session = tester
              .element(find.byType(AuthIntroView))
              .read<FarmerSessionViewModel>();
          await tap(find.widgetWithText(FilledButton, 'Sign in'));
          await until(() => !session.busy);
          expect(session.error, isNull);
          expect(session.signedIn, true);
          return session;
        }

        Future<ProfileViewModel> editProfile() async {
          await tap(find.byKey(const Key('edit-farmer-profile')));
          final model = tester
              .element(find.byType(ProfileEditorView))
              .read<ProfileViewModel>();
          await until(() => !model.loading);
          expect(model.error, isNull);
          return model;
        }

        await mount();
        var session = await signIn();
        var profile = await editProfile();
        expect(profile.data, isNull);
        await tester.enterText(
          find.byKey(const Key('profile-display-name')),
          'Field Researcher',
        );
        await tester.enterText(
          find.byKey(const Key('profile-region')),
          'Fixture Region',
        );
        await tester.enterText(find.byKey(const Key('profile-country')), 'PK');
        await tester.enterText(find.byKey(const Key('profile-area')), '1.2345');
        await tap(find.byKey(const Key('profile-save')));
        await until(() => !profile.busy);
        expect(profile.error, isNull);
        expect(profile.data!.displayName, 'Field Researcher');
        for (var index = 0; index < 2; index++) {
          await tap(find.byKey(const Key('profile-choose-photo')));
          await until(() => !profile.busy);
          expect(
            find.byKey(const Key('profile-photo-preview')),
            findsOneWidget,
          );
          await tap(find.text('Upload selected photo'));
          await until(() => !profile.busy);
          expect(profile.error, isNull);
          expect(profile.data!.avatarUrl, isNotNull);
          expect(profile.progress, 1);
        }
        debugPrint(
          'LIVE verified: real profile form, Cloudinary replacement and durable PostgreSQL metadata.',
        );
        await tap(find.text('Profile').last);
        await tap(find.text('Sign out'));
        await until(() => !session.busy);
        expect(session.signedIn, false);
        await tap(find.text('Sign in'));
        session = await signIn();
        profile = await editProfile();
        expect(profile.data!.displayName, 'Field Researcher');
        expect(profile.data!.fieldAreaHectares, '1.2345');
        expect(profile.data!.avatarUrl, isNotNull);
        // Simulate process/widget-tree restart; credentials stay volatile, profile stays in PostgreSQL.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await mount();
        session = await signIn();
        profile = await editProfile();
        expect(profile.data!.region, 'Fixture Region');
        expect(profile.data!.countryCode, 'PK');
        expect(profile.data!.avatarUrl, isNotNull);
        await tap(find.text('Remove saved photo'));
        await tap(find.text('Remove photo'));
        await until(() => !profile.busy);
        expect(profile.error, isNull);
        expect(profile.data!.avatarUrl, isNull);
        debugPrint(
          'LIVE verified: profile persists across logout/login and app-tree restart; photo removal.',
        );
        await tap(find.text('Profile').last);
        await tap(find.text('Administrator workspace'));
        await tester.enterText(
          find.byKey(const Key('admin-email')),
          admin['email'] as String,
        );
        await tester.enterText(
          find.byKey(const Key('admin-password')),
          admin['password'] as String,
        );
        final adminSession = tester
            .element(find.byType(AdminAccessView))
            .read<AdminSessionViewModel>();
        await tap(find.text('Sign in as Admin'));
        await until(() => !adminSession.busy);
        expect(adminSession.error, isNull);
        final dashboard = tester
            .element(find.byType(AdminDashboardView))
            .read<AdminDashboardViewModel>();
        await until(() => !dashboard.loading);
        expect(dashboard.error, isNull);
        await tap(find.byKey(const Key('admin-farmers-link')));
        final accounts = tester
            .element(find.byType(FarmerManagementView))
            .read<FarmerManagementViewModel>();
        await until(() => !accounts.busy);
        expect(accounts.error, isNull);
        for (final status in ['SUSPENDED', 'DEACTIVATED', 'ACTIVE']) {
          final card = find.byKey(ValueKey('managed-farmer-${farmer['id']}'));
          await tap(
            find.descendant(of: card, matching: find.text('Set $status')),
          );
          await tap(find.text('Confirm status change'));
          await until(() => !accounts.busy);
          expect(accounts.error, isNull);
          expect(
            accounts.items
                .singleWhere((item) => item.id == farmer['id'])
                .status,
            status,
          );
        }
        await tap(find.byTooltip('Return to Admin overview'));
        final currentDashboard = tester
            .element(find.byType(AdminDashboardView))
            .read<AdminDashboardViewModel>();
        await until(() => !currentDashboard.loading);
        await tap(find.byKey(const Key('admin-audit-link')));
        final audit = tester
            .element(find.byType(AuditLogView))
            .read<AuditLogViewModel>();
        await until(() => !audit.busy);
        expect(audit.error, isNull);
        expect(audit.items, isNotEmpty);
        expect(
          audit.items.any(
            (item) =>
                item.entityId == farmer['id'] && item.action == 'ACTIVATE',
          ),
          true,
        );
        final date = DateTime.now().toUtc().toIso8601String().split('T').first;
        await tester.enterText(find.byKey(const Key('audit-from')), date);
        await tester.enterText(find.byKey(const Key('audit-to')), date);
        await tap(find.byKey(const Key('audit-filter')));
        await until(() => !audit.busy);
        expect(audit.error, isNull);
        expect(
          audit.items.every(
            (item) => !item.metadata.containsKey('passwordHash'),
          ),
          true,
        );
        await tap(find.text('Sign out'));
        await until(() => !adminSession.busy);
        expect(adminSession.signedIn, false);
        expect(find.byType(AuditLogView), findsNothing);
        debugPrint(
          'LIVE verified: Admin account statuses, revocation and filtered read-only audit widgets.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
