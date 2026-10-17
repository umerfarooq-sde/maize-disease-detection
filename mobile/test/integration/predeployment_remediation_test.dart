import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/storage/access_token_source.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/repositories/profile_repository.dart';
import 'package:maizedoctor/features/profile/view_models/profile_view_model.dart';
import 'package:maizedoctor/features/admin/view_models/admin_dashboard_view_model.dart';
import 'package:maizedoctor/features/admin/views/admin_dashboard_view.dart';
import 'package:maizedoctor/features/disease_knowledge/views/knowledge_detail_view.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/knowledge_detail_view_model.dart';

const enabled = bool.fromEnvironment('RUN_LIVE_PREDEPLOYMENT');

class _RealHttpBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _FixtureTokens implements AccessTokenSource {
  @override
  Future<String?> readAccessToken() async =>
      Platform.environment['PHASE246_FARMER_TOKEN'];
}

void main() {
  if (enabled) _RealHttpBinding();
  testWidgets(
    'real avatar response, operational dashboard and synthetic gallery preserve committed state, sources and scope',
    (tester) async {
      await tester.runAsync(() async {
        final photoApi = ApiClient(
          config: AppConfig.fromEnvironment(),
          tokenSource: _FixtureTokens(),
        );
        final photoModel = ProfileViewModel(
          ApiProfileRepository(photoApi, PickerLeafImageDatasource()),
        );
        try {
          await photoModel.load();
          expect(photoModel.data?.avatarUrl, isNotNull);
          final elapsed = Stopwatch()..start();
          await photoModel.removePhoto();
          expect(photoModel.error, isNull);
          expect(photoModel.data?.avatarUrl, isNull);
          expect(
            elapsed.elapsed,
            lessThan(const Duration(seconds: 15)),
            reason:
                'Committed response must fit the unchanged Flutter request deadline; obsolete provider deletion is a separate16.5s job.',
          );
          debugPrint(
            'Avatar committed response: ${elapsed.elapsedMilliseconds}ms; provider cleanup uses a separate 16500ms delay fixture.',
          );
        } finally {
          photoModel.dispose();
          photoApi.close();
        }
        final admin =
            jsonDecode(Platform.environment['PHASE246_ADMIN']!)
                as Map<String, dynamic>;
        Future<void> until(
          bool Function() condition, {
          String Function()? diagnostic,
        }) async {
          final deadline = DateTime.now().add(const Duration(seconds: 90));
          while (!condition() && DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await tester.pump();
          }
          expect(
            condition(),
            true,
            reason:
                'Actual remediation UI/API operation did not finish. ${diagnostic?.call() ?? 'No stage diagnostic.'}',
          );
        }

        await tester.pumpWidget(
          MainApp(
            config: AppConfig.fromEnvironment(),
            initialLocation: '/admin',
          ),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('admin-email')),
          admin['email'] as String,
        );
        await tester.enterText(
          find.byKey(const Key('admin-password')),
          admin['password'] as String,
        );
        await tester.ensureVisible(find.text('Sign in as Admin'));
        await tester.tap(find.text('Sign in as Admin'));
        await tester.pump();
        await until(
          () => find.byType(AdminDashboardView).evaluate().isNotEmpty,
        );
        await until(
          () =>
              tester
                  .element(find.byType(AdminDashboardView))
                  .read<AdminDashboardViewModel>()
                  .data !=
              null,
        );
        final operations = tester
            .element(find.byType(AdminDashboardView))
            .read<AdminDashboardViewModel>()
            .data!
            .operations!;
        expect(operations.status, 'COLLECTED');
        expect(
          operations.rows.any(
            (row) =>
                row.scope == 'NODE' &&
                row.operation == 'GENERATION' &&
                row.requests > 0,
          ),
          true,
        );
        expect(find.text('AI operations'), findsOneWidget);
        expect(find.textContaining('NODE · GENERATION'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final slug = Platform.environment['PHASE246_SLUG']!;
        await tester.pumpWidget(
          MainApp(
            config: AppConfig.fromEnvironment(),
            initialLocation: '/knowledge/$slug',
          ),
        );
        await until(
          () =>
              find.byType(KnowledgeDetailView).evaluate().isNotEmpty &&
              find
                  .text('Reviewed growth-stage applicability')
                  .evaluate()
                  .isNotEmpty,
          diagnostic: () {
            final view = find.byType(KnowledgeDetailView);
            if (view.evaluate().isEmpty) return 'knowledge-detail: view absent';
            final model = tester.element(view).read<KnowledgeDetailViewModel>();
            return 'knowledge-detail: loading=${model.loading}, error=${model.error?.kind.name}, data=${model.detail != null}, growthStages=${model.detail?.growthStages.length}';
          },
        );
        await until(
          () => find
              .text('SYNTHETIC TEST FIXTURE · not disease evidence')
              .evaluate()
              .isNotEmpty,
        );
        expect(
          find.text(
            'Informational knowledge entry · not a trained classifier output',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Synthetic stage fixture, not an agronomic claim'),
          findsOneWidget,
        );
        expect(
          find.textContaining('SYNTHETIC TEST FIXTURE — NOT DISEASE EVIDENCE'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
