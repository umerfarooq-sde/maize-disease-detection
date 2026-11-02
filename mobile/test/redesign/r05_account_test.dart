import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/testing.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/features/profile/views/profile_view.dart';
import 'package:maizedoctor/features/profile/views/profile_editor_view.dart';
import 'package:maizedoctor/features/profile/widgets/profile_account_header.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import '../auth/session_test.dart' show grant, response, cookie;
import '../profile/helpers.dart';
import '../support/design_fonts.dart';
import '../scans/widget_test.dart' show tapVisible;

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'account centre loads real owner projection once and refreshes after editing',
    (tester) async {
      var reads = 0;
      var stored = profileJson();
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.profile,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/auth/login')) {
              return response(grant(), setCookie: cookie);
            }
            if (request.url.path.endsWith('/profile')) {
              if (request.method == 'GET') {
                reads++;
                return response(stored);
              }
              stored = profileJson(name: 'Updated fixture farmer');
              (stored['profile'] as Map<String, Object?>)['revision'] =
                  'b' * 64;
              return response(stored);
            }
            return response(null, status: 503);
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, 0, reason: 'Guests must not read an authenticated profile');
      final session = tester
          .element(find.byType(ProfileView))
          .read<FarmerSessionViewModel>();
      await tester.runAsync(
        () => session.signIn('fixture@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(
        tester
            .widget<ProfileAccountHeader>(find.byType(ProfileAccountHeader))
            .profile
            ?.displayName,
        'Fixture farmer',
      );
      await tester.pump();
      expect(reads, 1);
      await tapVisible(tester, find.byKey(const Key('edit-farmer-profile')));
      expect(reads, 2);
      await tester.enterText(
        find.byKey(const Key('profile-display-name')),
        'Updated fixture farmer',
      );
      await tapVisible(tester, find.byKey(const Key('profile-save')));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(find.text('Updated fixture farmer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dirty profile Back confirms discard, cancel preserves private local draft',
    (tester) async {
      var writes = 0;
      await tester.pumpWidget(
        MainApp(
          initialLocation: AppRoutes.editProfile,
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/auth/login')) {
              return response(grant(), setCookie: cookie);
            }
            if (request.url.path.endsWith('/profile')) {
              if (request.method != 'GET') writes++;
              return response(profileJson());
            }
            return response(null, status: 503);
          }),
        ),
      );
      await tester.pumpAndSettle();
      final session = tester
          .element(find.byType(ProfileEditorView))
          .read<FarmerSessionViewModel>();
      await tester.runAsync(
        () => session.signIn('fixture@example.test', 'synthetic-password'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-display-name')),
        'Unpublished draft',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved profile changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('profile-display-name')),
            )
            .controller!
            .text,
        'Unpublished draft',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditorView), findsNothing);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
