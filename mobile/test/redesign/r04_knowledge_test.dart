import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/app.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/core/routes/app_routes.dart';
import 'package:maizedoctor/core/widgets/source_reference_card.dart';
import 'package:maizedoctor/core/widgets/private_image.dart';
import 'package:maizedoctor/features/disease_knowledge/widgets/reference_image_viewer.dart';
import '../auth/session_test.dart' show response;
import '../scans/widget_test.dart' show tapVisible;
import '../scans/helpers.dart' show leafImage;
import '../support/design_fonts.dart';
import 'r04_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'gallery keeps only four protected thumbnails mounted and paginates without reloading metadata',
    (tester) async {
      var lists = 0, reads = 0;
      await tester.pumpWidget(
        MainApp(
          initialLocation: '${AppRoutes.knowledge}/common-rust',
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/images')) {
              lists++;
              return response({
                'items': [
                  for (var i = 1; i <= 5; i++)
                    {
                      ...r04Media(),
                      'id': '00000000-0000-4000-8000-00000000000$i',
                      'imagePath':
                          'disease-images/00000000-0000-4000-8000-00000000000$i/image',
                    },
                ],
              });
            }
            if (request.url.path.endsWith('/image')) {
              reads++;
              return http.Response.bytes(
                leafImage.bytes,
                200,
                headers: {'content-type': 'image/png'},
              );
            }
            return response(r04Detail());
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PrivateImage), findsNWidgets(4));
      expect(reads, 4);
      await tapVisible(tester, find.text('Next photographs'));
      expect(find.byType(PrivateImage), findsOneWidget);
      expect(reads, 5);
      expect(lists, 1);
      expect(find.text('Reference images').hitTestable(), findsOneWidget);
      expect(find.text('Reference photographs · page 2 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'dynamic section navigation preserves content, version and copyable provenance',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MainApp(
          initialLocation: '${AppRoutes.knowledge}/common-rust',
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: r04Client(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNWidgets(2));
      expect(find.text('Causes'), findsNothing);
      await tapVisible(
        tester,
        find.byKey(
          const ValueKey('section-link-22345678-1234-4123-8123-123456789abc'),
        ),
      );
      final heading = find.text('UI fixture prevention');
      expect(heading.hitTestable(), findsOneWidget);
      expect(find.textContaining('document version 2'), findsOneWidget);
      final sources = find.byType(SourceReferenceCard);
      await tester.ensureVisible(sources.last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Copy source URL').last);
      expect(copied, 'https://extension.example.test/reviewed');
      expect(find.text('Source URL copied'), findsOneWidget);
      expect(
        find.textContaining('No reviewed reference photographs'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'published gallery opens protected contain-fit zoom with attribution and closes',
    (tester) async {
      var imageRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/images')) {
          return response({
            'items': [
              r04Media(),
              {...r04Media(), 'status': 'INACTIVE'},
            ],
          });
        }
        if (request.url.path.endsWith('/image')) {
          imageRequests++;
          expect(request.url.host, 'api.example.test');
          return http.Response.bytes(
            leafImage.bytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return response(r04Detail());
      });
      await tester.pumpWidget(
        MainApp(
          initialLocation: '${AppRoutes.knowledge}/common-rust',
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: client,
        ),
      );
      await tester.pumpAndSettle();
      final image = find.byKey(
        const ValueKey('reference-open-12345678-1234-4123-8123-123456789abc'),
      );
      expect(
        image,
        findsOneWidget,
        reason: 'Inactive metadata must never display as published media',
      );
      await tapVisible(tester, image);
      expect(find.byType(ReferenceImageViewer), findsOneWidget);
      final zoom = tester.widget<InteractiveViewer>(
        find.byKey(const Key('reference-image-zoom')),
      );
      expect(zoom.maxScale, greaterThan(zoom.minScale));
      expect(
        find.text('SYNTHETIC TEST FIXTURE · not disease evidence'),
        findsWidgets,
      );
      expect(
        find.textContaining('Credit: Test generator').last,
        findsOneWidget,
      );
      expect(
        imageRequests,
        2,
        reason:
            'Separate bounded thumbnail and modal readers, no arbitrary URL fetch',
      );
      await tester.tap(find.byTooltip('Close reference image'));
      await tester.pumpAndSettle();
      expect(find.byType(ReferenceImageViewer), findsNothing);
      expect(imageRequests, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery list failure is retryable and protected image denial is not fake content',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MainApp(
          initialLocation: '${AppRoutes.knowledge}/common-rust',
          config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/images')) {
              return ++attempts == 1
                  ? response(null, status: 503)
                  : response({
                      'items': [r04Media()],
                    });
            }
            if (request.url.path.endsWith('/image')) {
              return response(null, status: 403);
            }
            return response(r04Detail());
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Try again'));
      expect(attempts, 2);
      await tester.ensureVisible(
        find.byKey(
          const ValueKey('reference-open-12345678-1234-4123-8123-123456789abc'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No reviewed photographs yet'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byTooltip('Retry photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
