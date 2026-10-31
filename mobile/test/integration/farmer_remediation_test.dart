import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/data/repositories/knowledge_repository.dart';
import 'package:maizedoctor/features/auth/view_models/farmer_session_view_model.dart';
import 'package:maizedoctor/features/auth/view_models/registration_view_model.dart';
import 'package:maizedoctor/features/auth/views/auth_intro_view.dart';
import 'package:maizedoctor/features/auth/views/registration_view.dart';
import 'package:maizedoctor/features/disease_knowledge/views/knowledge_view.dart';
import 'package:maizedoctor/features/disease_knowledge/views/knowledge_detail_view.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/knowledge_view_model.dart';
import 'package:maizedoctor/features/disease_knowledge/view_models/knowledge_detail_view_model.dart';

const _enabled = bool.fromEnvironment('RUN_LIVE_FARMER_REMEDIATION');

// Host widget verification with real HTTP is explicitly opt-in; never a device claim.
class _LiveBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  if (_enabled) _LiveBinding();
  testWidgets(
    'real registration form, login, sourced knowledge browse/search/details and logout',
    (tester) async {
      await tester.runAsync(() async {
        final credentials =
            jsonDecode(Platform.environment['REMEDIATION_FARMER']!)
                as Map<String, dynamic>;
        Future<void> until(bool Function() ready) async {
          final deadline = DateTime.now().add(const Duration(seconds: 55));
          while (!ready() && DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await tester.pump();
          }
          expect(
            ready(),
            true,
            reason: 'The real HTTP widget operation did not complete.',
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
          // Complete route transitions while retaining real network waits above.
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        }

        String knowledgeFailure(String endpoint, AppException? error) =>
            '$endpoint: kind=${error?.kind.name ?? 'none'}, '
            'status=${error?.statusCode ?? 'none'}, '
            'requestId=${error?.requestId ?? 'none'}';

        await tester.pumpWidget(
          MainApp(
            config: AppConfig.fromEnvironment(),
            initialLocation: AppRoutes.register,
          ),
        );
        await tester.pump();
        final registration = tester
            .element(find.byType(RegistrationView))
            .read<RegistrationViewModel>();
        await tester.enterText(
          find.byKey(const Key('registration-email')),
          credentials['email'] as String,
        );
        await tester.enterText(
          find.byKey(const Key('registration-password')),
          credentials['password'] as String,
        );
        await tap(find.byKey(const Key('register-submit')));
        await until(() => !registration.busy);
        expect(registration.error, isNull);
        debugPrint(
          'LIVE verified: registration form → ViewModel → repository → actual Node/PostgreSQL.',
        );
        expect(find.text('Your farmer account is ready'), findsOneWidget);
        expect(
          tester
              .element(find.byType(RegistrationView))
              .read<FarmerSessionViewModel>()
              .signedIn,
          false,
        );
        await tap(find.byKey(const Key('registration-sign-in')));
        await tester.enterText(
          find.byType(TextFormField).first,
          credentials['email'] as String,
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          credentials['password'] as String,
        );
        final session = tester
            .element(find.byType(AuthIntroView))
            .read<FarmerSessionViewModel>();
        await tap(find.widgetWithText(FilledButton, 'Sign in'));
        await until(() => !session.busy);
        expect(session.error, isNull);
        expect(session.signedIn, true);
        debugPrint('LIVE verified: farmer login form and real session.');
        await tap(find.text('Knowledge').last);
        final knowledgeContext = tester.element(find.byType(KnowledgeView));
        final knowledge = knowledgeContext.read<KnowledgeViewModel>();
        await until(() => !knowledge.loading);
        expect(
          knowledge.catalogueError,
          isNull,
          reason: knowledgeFailure(
            'GET /api/v1/diseases',
            knowledge.catalogueError,
          ),
        );
        expect(knowledge.items, hasLength(4));
        for (final disease in knowledge.items) {
          await tap(find.byKey(ValueKey('knowledge-${disease.slug}')));
          final detail = tester
              .element(find.byType(KnowledgeDetailView))
              .read<KnowledgeDetailViewModel>();
          await until(() => !detail.loading);
          expect(
            detail.error,
            isNull,
            reason: knowledgeFailure(
              'GET /api/v1/diseases/${disease.slug}',
              detail.error,
            ),
          );
          expect(detail.detail!.sections, isNotEmpty);
          expect(
            detail.detail!.sections.every(
              (s) => s.source.url.scheme == 'https',
            ),
            true,
          );
          expect(
            find.text(detail.detail!.sections.first.source.publisher),
            findsWidgets,
          );
          if (disease.slug == 'healthy') {
            expect(detail.detail!.sections, hasLength(4));
            expect(
              detail.detail!.sections.any(
                (s) => s.knowledgeType == 'MANAGEMENT',
              ),
              false,
            );
          } else {
            expect(detail.detail!.sections, hasLength(7));
          }
          await tester.pageBack();
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        }
        debugPrint(
          'LIVE verified: all four real catalogue details and 25 sourced sections.',
        );
        await tester.enterText(
          find.byKey(const Key('knowledge-query')),
          'common rust symptoms',
        );
        await tap(find.byKey(const Key('knowledge-search')));
        await until(() => !knowledge.searching);
        expect(
          knowledge.searchError,
          isNull,
          reason: knowledgeFailure(
            'POST /api/v1/knowledge/search',
            knowledge.searchError,
          ),
        );
        expect(knowledge.result!.matches, isNotEmpty);
        expect(
          knowledge.result!.matches.any((m) => m.diseaseLabel == 'Common_Rust'),
          true,
        );
        expect(find.text('Retrieved passages'), findsOneWidget);
        // Verify real duplicate and ADMIN injection contracts using the same public transport.
        final api = knowledgeContext.read<ApiClient>();
        await expectLater(
          api.request(ApiMethod.post, 'auth/register', body: credentials),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              AppErrorKind.conflict,
            ),
          ),
        );
        await expectLater(
          api.request(
            ApiMethod.post,
            'auth/register',
            body: {...credentials, 'role': 'ADMIN'},
          ),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              AppErrorKind.validation,
            ),
          ),
        );
        final refreshed = await api.request(ApiMethod.post, 'auth/refresh');
        expect(refreshed.statusCode, 200);
        await tap(find.text('Profile').last);
        await tap(find.text('Sign out'));
        await until(() => !session.busy);
        expect(session.signedIn, false);
        await tap(find.text('Knowledge').last);
        await tap(find.text('Clear search'));
        await tap(find.text('Refresh catalogue'));
        await until(() => !knowledge.loading);
        expect(knowledge.items, hasLength(4));
        final guestRepo = knowledgeContext.read<KnowledgeRepository>();
        final guestDetail = await guestRepo.detail('healthy');
        expect(guestDetail.sections, hasLength(4));
        await expectLater(
          guestRepo.detail('not-a-published-disease'),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              AppErrorKind.notFound,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
