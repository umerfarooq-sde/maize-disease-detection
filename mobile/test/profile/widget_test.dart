import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/features/profile/view_models/profile_view_model.dart';
import 'package:maizedoctor/features/profile/views/profile_editor_view.dart';
import '../scans/widget_test.dart' show tapVisible;
import 'helpers.dart';

Future<void> pumpProfile(
  WidgetTester tester,
  FakeProfileRepository repo,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => ProfileViewModel(repo)..load(),
          child: const ProfileEditorView(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'profile shows saved details, validates and saves editable non-sensitive fields',
    (tester) async {
      final repo = FakeProfileRepository();
      await pumpProfile(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Fixture farmer'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('profile-display-name')), '');
      await tapVisible(tester, find.byKey(const Key('profile-save')));
      expect(repo.writes, 0);
      await tester.enterText(
        find.byKey(const Key('profile-display-name')),
        'Saved farmer',
      );
      await tapVisible(tester, find.byKey(const Key('profile-save')));
      expect(find.text('Your profile is saved.'), findsOneWidget);
      expect(find.text('Saved farmer'), findsOneWidget);
      expect(repo.writes, 1);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Role'), findsNothing);
    },
  );
  testWidgets(
    'profile loading, network failure/retry, and guest sign-in state',
    (tester) async {
      final repo = FakeProfileRepository()..pendingRead = Completer();
      await pumpProfile(tester, repo);
      expect(find.text('Loading your saved profile…'), findsOneWidget);
      repo.pendingRead!.completeError(const AppException(AppErrorKind.network));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your internet'), findsOneWidget);
      repo.pendingRead = null;
      await tapVisible(tester, find.text('Reload saved profile'));
      expect(find.text('Fixture farmer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpProfile(tester, FakeProfileRepository()..signedIn = false);
      await tester.pumpAndSettle();
      expect(find.text('Sign in to edit your profile'), findsOneWidget);
    },
  );
  testWidgets(
    'profile photo selection previews without uploading until explicit submission',
    (tester) async {
      final repo = FakeProfileRepository();
      await pumpProfile(tester, repo);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('profile-choose-photo')));
      expect(find.byKey(const Key('profile-photo-preview')), findsOneWidget);
      expect(repo.uploads, 0);
      await tapVisible(tester, find.text('Discard selection'));
      expect(find.byKey(const Key('profile-photo-preview')), findsNothing);
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(640, 360),
    const Size(1024, 768),
  ]) {
    testWidgets('profile form scrolls at $size with 200 percent text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final repo = FakeProfileRepository();
      await pumpProfile(tester, repo);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('profile-save')));
      expect(repo.writes, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
