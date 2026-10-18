import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/access_token_source.dart';
import 'package:maizedoctor/core/theme/app_theme.dart';
import 'package:maizedoctor/data/models/deletion_request.dart';
import 'package:maizedoctor/data/repositories/privacy_repository.dart';
import 'package:maizedoctor/features/profile/view_models/privacy_view_model.dart';
import 'package:maizedoctor/features/profile/views/privacy_view.dart';
import '../auth/session_test.dart' show response;
import '../scans/widget_test.dart' show tapVisible;

Map<String, Object?> receipt() => {
  'request': {
    'id': 'synthetic-public-request',
    'status': 'REQUESTED',
    'requestedAt': '2026-10-18T00:00:00Z',
    'completedAt': null,
    'erasureAutomaticallyEnabled': false,
  },
};

class Tokens implements AccessTokenSource {
  @override
  Future<String?> readAccessToken() async => 'header.payload.signature';
}

class Repository implements PrivacyRepository {
  @override
  bool signedIn = true;
  @override
  int? sessionRevision = 1;
  int writes = 0;
  Object? failure;
  Completer<DeletionRequest?>? pending;
  DeletionRequest? saved;
  @override
  Future<DeletionRequest?> read() async {
    if (failure case final error?) throw error;
    return pending?.future ?? saved;
  }

  @override
  Future<DeletionRequest> submit() async {
    writes++;
    if (failure case final error?) throw error;
    return saved = DeletionRequest.fromResponse(receipt())!;
  }
}

void main() {
  test(
    'privacy response rejects unknown or misleading automatic-erasure states',
    () {
      expect(DeletionRequest.fromResponse({'request': null}), isNull);
      expect(
        DeletionRequest.fromResponse(receipt())!.description,
        contains('not been deleted'),
      );
      for (final value in [
        {},
        {'request': {}},
        {
          'request': {
            'status': 'REQUESTED',
            'requestedAt': '2026-10-18',
            'erasureAutomaticallyEnabled': true,
          },
        },
      ]) {
        expect(
          () => DeletionRequest.fromResponse(value),
          throwsA(isA<AppException>()),
        );
      }
    },
  );
  test(
    'repository uses owner authentication, empty JSON and one read to reconcile a committed timeout',
    () async {
      final methods = <String>[];
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: Tokens(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/profile/data-deletion');
          expect(
            request.headers['Authorization'],
            'Bearer header.payload.signature',
          );
          methods.add(request.method);
          if (request.method == 'POST') {
            expect(request.headers['X-Auth-Request'], '1');
            expect(jsonDecode(request.body), isEmpty);
            throw TimeoutException('synthetic lost acknowledgement');
          }
          return response(receipt());
        }),
      );
      addTearDown(api.close);
      expect((await ApiPrivacyRepository(api).submit()).status, 'REQUESTED');
      expect(methods, ['POST', 'GET']);
    },
  );
  test(
    'ViewModel retries errors and does not resubmit an existing request',
    () async {
      final repo = Repository()
        ..failure = const AppException(AppErrorKind.network);
      final model = PrivacyViewModel(repo);
      addTearDown(model.dispose);
      await model.load();
      expect(model.busy, false);
      expect(model.error?.kind, AppErrorKind.network);
      repo.failure = null;
      await model.load();
      await model.submit();
      await model.submit();
      expect(repo.writes, 1);
      expect(model.request?.status, 'REQUESTED');
    },
  );
  test(
    'account revision changes hide old requests and release busy state',
    () async {
      final repo = Repository()..pending = Completer<DeletionRequest?>();
      final model = PrivacyViewModel(repo);
      addTearDown(model.dispose);
      final loading = model.load();
      repo.sessionRevision = 2;
      repo.pending!.complete(DeletionRequest.fromResponse(receipt()));
      await loading;
      expect(model.request, isNull);
      expect(model.busy, false);
      expect(model.signedIn, false);
    },
  );
  testWidgets(
    'request requires confirmation and clearly distinguishes review from erasure',
    (tester) async {
      final repo = Repository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => PrivacyViewModel(repo)..load(),
              child: const PrivacyView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Request data deletion'));
      expect(repo.writes, 0);
      await tapVisible(tester, find.text('Cancel'));
      expect(repo.writes, 0);
      await tapVisible(tester, find.text('Request data deletion'));
      await tapVisible(tester, find.text('Send request'));
      expect(repo.writes, 1);
      expect(find.textContaining('have not been deleted'), findsOneWidget);
    },
  );
  testWidgets('privacy screen handles error retry and signed-out state', (
    tester,
  ) async {
    final repo = Repository()
      ..failure = const AppException(AppErrorKind.network);
    final model = PrivacyViewModel(repo);
    await model.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider.value(
            value: model,
            child: const PrivacyView(),
          ),
        ),
      ),
    );
    expect(find.text('Try again'), findsOneWidget);
    repo.failure = null;
    await tapVisible(tester, find.text('Try again'));
    expect(find.text('Request data deletion'), findsOneWidget);
    repo.signedIn = false;
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
