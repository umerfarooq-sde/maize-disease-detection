import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/access_token_source.dart';
import 'package:maizedoctor/data/models/farmer_profile.dart';
import 'package:maizedoctor/data/repositories/profile_repository.dart';
import '../auth/session_test.dart' show response;
import '../integration/scan_upload_test.dart' show FixtureImageSource;
import '../scans/helpers.dart' show leafImage;
import 'helpers.dart';

class ProfileTokens implements AccessTokenSource {
  @override
  Future<String?> readAccessToken() async => 'header.payload.signature';
}

void main() {
  test(
    'profile metadata validates Unicode, nullable optional fields and exact hectares',
    () {
      final json = const ProfileDraft(
        ' 🌽 Farmer ',
        '',
        'pk',
        '1.2345',
      ).toJson(null);
      expect(json, {
        'expectedRevision': null,
        'displayName': '🌽 Farmer',
        'region': null,
        'countryCode': 'PK',
        'fieldAreaHectares': '1.2345',
      });
      for (final area in ['0', '-1', '1e2', '01', '1.12345', '100000000']) {
        expect(ProfileDraft.areaError(area), isNotNull);
      }
      for (final name in ['', ' ' * 3, 'a' * 121, 'bad\u0000name']) {
        expect(ProfileDraft.nameError(name), isNotNull);
      }
      expect(ProfileDraft.nameError('🌽' * 120), isNull);
      expect(ProfileDraft.countryError('pak'), isNotNull);
      expect(FarmerProfile.fromResponse({'profile': null}), isNull);
    },
  );
  test(
    'profile model rejects raw internal fields and untrusted avatar URLs',
    () {
      for (final photo in [
        'http://res.cloudinary.com/p.png',
        'https://other.example.test/p.png',
        'https://name:secret@res.cloudinary.com/p.png',
      ]) {
        expect(
          () => FarmerProfile.fromResponse(profileJson(photo: photo)),
          throwsA(isA<AppException>()),
        );
      }
      final raw = profileJson()['profile'] as Map<String, Object?>;
      expect(
        () => FarmerProfile.fromResponse({
          'profile': {...raw, 'userId': 'internal'},
        }),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'profile repository uses authenticated own-profile PATCH and nullable clear semantics',
    () async {
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: ProfileTokens(),
        client: MockClient((request) async {
          expect(
            request.headers['Authorization'],
            'Bearer header.payload.signature',
          );
          expect(request.url.path, '/api/v1/profile');
          expect(request.url.query, isEmpty);
          if (request.method == 'PATCH') {
            expect(
              jsonDecode(request.body),
              const ProfileDraft('Fixture farmer', '', '', '').toJson('a' * 64),
            );
          }
          return response(profileJson());
        }),
      );
      addTearDown(api.close);
      final repo = ApiProfileRepository(api, FixtureImageSource());
      expect((await repo.read())!.displayName, 'Fixture farmer');
      await repo.save(
        const ProfileDraft('Fixture farmer', '', '', ''),
        'a' * 64,
      );
    },
  );
  test(
    'profile photo reuses multipart client, preview picker and authenticated transport',
    () async {
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        tokenSource: ProfileTokens(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/profile/avatar');
          expect(request.headers['Authorization'], isNotNull);
          if (request.method == 'POST') {
            final body = request.bodyBytes;
            expect(
              utf8.decode(body, allowMalformed: true),
              contains('expectedRevision'),
            );
            expect(utf8.decode(body, allowMalformed: true), contains('a' * 64));
          }
          return response(profileJson());
        }),
      );
      addTearDown(api.close);
      final repo = ApiProfileRepository(api, FixtureImageSource());
      expect(await repo.choosePhoto(), leafImage);
      await repo.uploadPhoto(leafImage, 'a' * 64, (_) {});
      await repo.removePhoto('a' * 64);
    },
  );
  test(
    'invalid profile draft and unauthenticated avatar never reach the server',
    () async {
      var calls = 0;
      final api = ApiClient(
        config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
        client: MockClient((_) async {
          calls++;
          return response(profileJson());
        }),
      );
      addTearDown(api.close);
      final repo = ApiProfileRepository(api, FixtureImageSource());
      await expectLater(
        repo.save(const ProfileDraft('', '', '', ''), null),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.uploadPhoto(leafImage, 'a' * 64, (_) {}),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            AppErrorKind.authentication,
          ),
        ),
      );
      expect(calls, 0);
    },
  );
}
