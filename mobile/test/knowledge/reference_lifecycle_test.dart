import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/access_token_source.dart';
import 'package:maizedoctor/data/repositories/reference_media_repository.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/reference_gallery_view_model.dart';
import '../admin/predeployment_test.dart' show mediaJson;
import '../auth/session_test.dart' show response;

class _Session implements SessionTokenSource {
  @override
  int revision = 0;
  @override
  bool hasSession = true;
  @override
  void invalidate() => revision++;
  @override
  Future<String?> readAccessToken() async => 'Synthetic.Payload.Signature';
}

void main() {
  test(
    'account change during gallery load clears busy/stale state and permits an explicit fresh read',
    () async {
      final session = _Session();
      final pending = Completer<http.Response>();
      var calls = 0;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: session,
        client: MockClient((request) async {
          calls++;
          return calls == 1
              ? pending.future
              : response({
                  'items': [mediaJson()],
                });
        }),
      );
      addTearDown(api.close);
      final model = ReferenceGalleryViewModel(
        ReferenceMediaRepository(api),
        'healthy',
      );
      addTearDown(model.dispose);
      final loading = model.load();
      await Future<void>.delayed(Duration.zero);
      expect(model.busy, true);
      session.invalidate();
      pending.complete(
        response({
          'items': [mediaJson()],
        }),
      );
      await loading;
      expect(model.busy, false);
      expect(model.items, isEmpty);
      expect(model.error?.kind, AppErrorKind.authentication);
      await model.load();
      expect(calls, 2);
      expect(model.error, isNull);
      expect(model.items.single.synthetic, true);
    },
  );

  test(
    'navigation disposal suppresses late gallery notifications and data',
    () async {
      final pending = Completer<http.Response>();
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((_) => pending.future),
      );
      addTearDown(api.close);
      final model = ReferenceGalleryViewModel(
        ReferenceMediaRepository(api),
        'healthy',
      );
      var notifications = 0;
      model.addListener(() => notifications++);
      final loading = model.load();
      await Future<void>.delayed(Duration.zero);
      model.dispose();
      final before = notifications;
      pending.complete(
        response({
          'items': [mediaJson()],
        }),
      );
      await loading;
      expect(notifications, before);
      expect(model.items, isEmpty);
    },
  );

  test(
    'a stale Admin selection cannot publish after an account change',
    () async {
      final session = _Session();
      var reads = 0, mutations = 0;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: session,
        client: MockClient((request) async {
          if (request.method != 'GET') mutations++;
          reads++;
          return response({
            'items': [mediaJson()],
          });
        }),
      );
      addTearDown(api.close);
      final model = ReferenceGalleryViewModel(
        AdminReferenceMediaRepository(api),
        'healthy',
      );
      addTearDown(model.dispose);
      await model.load();
      final old = model.items.single;
      model.edit(old);
      session.invalidate();
      await model.status(old, 'ACTIVE', 'Synthetic fixture review only');
      expect(mutations, 0);
      expect(model.editing, isNull);
      expect(model.items, isEmpty);
      expect(model.error?.kind, AppErrorKind.authentication);
      await model.load();
      expect(reads, 2);
      expect(model.error, isNull);
    },
  );
}
