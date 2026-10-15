import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/storage/memory_session_tokens.dart';
import 'package:maizedoctor/data/models/admin_management.dart';
import 'package:maizedoctor/data/models/session_account.dart';
import 'package:maizedoctor/data/repositories/admin_management_repository.dart';
import 'package:maizedoctor/data/repositories/session_repository.dart';
import 'package:maizedoctor/features/admin/view_models/admin_management_view_model.dart';

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_MANAGEMENT_CHECK');
  test(
    'real Flutter Admin creates/indexes/publishes/archives reviewed knowledge and reads calculator versions',
    () async {
      final tokens = MemorySessionTokens(),
          apiConfig = AppConfig.fromEnvironment();
      final api = ApiClient(
        config: apiConfig,
        tokenSource: tokens,
        timeout: const Duration(seconds: 30),
      );
      final session = SessionRepository(
        api,
        tokens,
        requiredRole: AccountRole.admin,
      );
      final repository = ApiAdminManagementRepository(api),
          model = AdminManagementViewModel(ApiAdminManagementRepository(api));
      try {
        await session.signIn(
          Platform.environment['MANAGEMENT_ADMIN_EMAIL']!,
          Platform.environment['MANAGEMENT_ADMIN_PASSWORD']!,
        );
        final diseases = await repository.list(ManagementArea.diseases);
        expect(diseases.items.length, 4);
        expect(
          diseases.items.any(
            (item) => item.values['literalLabel'] == 'Common_Rust',
          ),
          true,
        );
        final body =
            jsonDecode(Platform.environment['MANAGEMENT_DRAFT']!)
                as Map<String, dynamic>;
        await repository.save(
          ManagementEditor(ManagementArea.knowledge, null, {}),
          body,
        );
        await model.load();
        expect(model.error, isNull);
        var row = model.items.singleWhere(
          (item) => item.values['documentKey'] == body['documentKey'],
        );
        expect(row.status, 'DRAFT');
        expect(row.ready, false);
        await model.index(row);
        expect(model.error, isNull);
        row = model.items.singleWhere((item) => item.id == row.id);
        expect(row.ready, true);
        await model.status(row, 'ACTIVE');
        expect(model.error, isNull);
        row = model.items.singleWhere((item) => item.id == row.id);
        expect(row.status, 'ACTIVE');
        final detail = await repository.document(row.id);
        expect(detail.values['content'], body['content']);
        expect(
          (detail.values['source'] as Map)['rights'],
          (body['source'] as Map)['rights'],
        );
        await model.status(row, 'ARCHIVED');
        expect(model.error, isNull);
        for (final area in [
          ManagementArea.fertilizer,
          ManagementArea.yieldRules,
        ]) {
          final page = await repository.list(area);
          expect(page.items.length, 2);
          expect(page.items.any((item) => item.status == 'INACTIVE'), true);
          final entry = page.items.singleWhere(
            (item) => item.status == 'ACTIVE',
          );
          final fields = managementEditorValues(area, entry);
          expect(fields['rate'], '20');
          expect(fields['version'], '3');
          expect(fields['reviewNote'], '');
        }
        await session.signOut();
        expect(repository.hasSession, false);
        expect(model.items, isEmpty);
      } finally {
        model.dispose();
        session.clear();
        api.close();
        tokens.dispose();
      }
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
