import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/core/widgets/private_image.dart';
import 'package:maizedoctor/core/widgets/private_image_view_model.dart';
import 'package:maizedoctor/data/repositories/private_image_repository.dart';
import '../scans/helpers.dart' show leafImage, savedScan;

void main() {
  final path = savedScan.imageUrl.toString();
  const key = 'bca6b985-b681-4dc2-af08-ae7e6ed40b35';
  test(
    'thumbnail queue bounds concurrency and never sends queued work under a new account',
    () async {
      final tokens = MemorySessionTokens()
        ..save('header.payload.signature', const Duration(minutes: 5));
      final responses = <Completer<http.Response>>[];
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'http://localhost:3000/api/v1'),
        tokenSource: tokens,
        client: MockClient((_) {
          final response = Completer<http.Response>();
          responses.add(response);
          return response.future;
        }),
      );
      addTearDown(api.close);
      addTearDown(tokens.dispose);
      final repository = PrivateImageRepository(api);
      final first = repository.read(path), second = repository.read(path);
      final third = repository.read(path), stale = repository.read(path);
      final staleAssertion = expectLater(stale, throwsA(isA<AppException>()));
      await Future<void>.delayed(Duration.zero);
      expect(responses, hasLength(2));
      http.Response image() => http.Response.bytes(
        leafImage.bytes,
        200,
        headers: {'content-type': 'image/png'},
      );
      responses[0].complete(image());
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(responses, hasLength(3));
      responses[1].complete(image());
      // The waiting request has not acquired the released slot yet.
      tokens.invalidate();
      await expectLater(second, throwsA(isA<AppException>()));
      responses[2].complete(image());
      await expectLater(third, throwsA(isA<AppException>()));
      await staleAssertion;
      expect(responses, hasLength(3));
    },
  );
  test(
    'owner and capability image requests are bounded to the configured Node origin',
    () async {
      final tokens = MemorySessionTokens()
        ..save('header.payload.signature', const Duration(minutes: 5));
      var calls = 0;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'http://localhost:3000/api/v1'),
        tokenSource: tokens,
        client: MockClient((request) async {
          calls++;
          expect(request.url.origin, 'http://localhost:3000');
          expect(request.url.path, '/api/v1/$path');
          expect(request.url.hasQuery, false);
          expect(request.headers['Idempotency-Key'], calls == 1 ? null : key);
          expect(
            request.headers['Authorization'],
            calls == 1 ? 'Bearer header.payload.signature' : null,
          );
          expect(request.headers['Cookie'], isNull);
          return http.Response.bytes(
            leafImage.bytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      addTearDown(api.close);
      addTearDown(tokens.dispose);
      final repo = PrivateImageRepository(api);
      expect(await repo.read(path), leafImage.bytes);
      expect(await repo.read(path, anonymousKey: key), leafImage.bytes);
      for (final invalid in [
        'https://res.cloudinary.com/private.png',
        '//other.invalid/private',
        '../auth/me',
        'profile/avatar?v=bad',
      ]) {
        await expectLater(repo.read(invalid), throwsA(isA<AppException>()));
      }
      expect(calls, 2);
    },
  );

  test(
    'image transport refuses unsupported responses, expired identity and stalled requests',
    () async {
      final tokens = MemorySessionTokens()
        ..save('header.payload.signature', const Duration(minutes: 5));
      final pending = Completer<http.Response>();
      var invalid = true;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'http://localhost:3000/api/v1'),
        tokenSource: tokens,
        timeout: const Duration(milliseconds: 30),
        client: MockClient((_) async {
          if (invalid) {
            return http.Response(
              '<svg/>',
              200,
              headers: {'content-type': 'image/svg+xml'},
            );
          }
          return pending.future;
        }),
      );
      addTearDown(api.close);
      addTearDown(tokens.dispose);
      await expectLater(
        api.readPrivateImage(path),
        throwsA(isA<AppException>()),
      );
      invalid = false;
      await expectLater(
        api.readPrivateImage(path),
        throwsA(
          isA<AppException>().having(
            (error) => error.kind,
            'kind',
            AppErrorKind.timeout,
          ),
        ),
      );
      pending.complete(
        http.Response.bytes(
          leafImage.bytes,
          200,
          headers: {'content-type': 'image/png'},
        ),
      );
      tokens.invalidate();
      await expectLater(
        api.readPrivateImage(path),
        throwsA(isA<AppException>()),
      );
    },
  );

  test(
    'image ViewModel discards results after identity change or disposal',
    () async {
      final tokens = MemorySessionTokens()
        ..save('header.payload.signature', const Duration(minutes: 5));
      final pending = Completer<http.Response>();
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'http://localhost:3000/api/v1'),
        tokenSource: tokens,
        client: MockClient((_) => pending.future),
      );
      addTearDown(api.close);
      addTearDown(tokens.dispose);
      final model = PrivateImageViewModel(
        PrivateImageRepository(api),
        path,
        null,
      );
      final loading = model.load();
      expect(model.loading, true);
      tokens.invalidate();
      pending.complete(
        http.Response.bytes(
          leafImage.bytes,
          200,
          headers: {'content-type': 'image/png'},
        ),
      );
      await loading;
      expect(model.bytes, isNull);
      model.dispose();
      await model.load();
      expect(model.bytes, isNull);
    },
  );

  testWidgets(
    'protected image displays loading, retry and successful in-memory rendering',
    (tester) async {
      var fail = true;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'http://localhost:3000/api/v1'),
        client: MockClient(
          (_) async => fail
              ? http.Response('unavailable', 503)
              : http.Response.bytes(
                  leafImage.bytes,
                  200,
                  headers: {'content-type': 'image/png'},
                ),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        Provider(
          create: (_) => PrivateImageRepository(api),
          child: MaterialApp(
            home: Scaffold(
              body: PrivateImage(
                path: path,
                anonymousKey: key,
                semanticLabel: 'Private fixture photo',
                width: 200,
                height: 200,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry photo'), findsOneWidget);
      fail = false;
      await tester.tap(find.byTooltip('Retry photo'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<ResizeImage>().having(
          (value) => value.imageProvider,
          'byte provider',
          isA<MemoryImage>(),
        ),
      );
    },
  );
}
