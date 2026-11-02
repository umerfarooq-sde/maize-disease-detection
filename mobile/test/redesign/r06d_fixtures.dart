import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizedoctor/features/admin/views/model_health_view.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import '../admin/accounts_helpers.dart';
import '../admin/model_health_test.dart' show healthFixture;
import '../auth/session_test.dart' show response;
import 'r06a_fixtures.dart';

class R06DFixture extends R06Fixture {
  bool accountsEmpty = false,
      auditsEmpty = false,
      paginate = false,
      longValues = false;
  int accountStatus = 200,
      auditStatus = 200,
      healthStatus = 200,
      mutationStatus = 200;
  String farmerStatus = 'ACTIVE';
  bool lostMutationReply = false;
  Map<String, dynamic> health = healthFixture();
  Completer<void>? accountGate, auditGate, healthGate, mutationGate;
  @override
  http.Client client() {
    final fallback = super.client();
    addTearDown(fallback.close);
    return MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/admin/farmers') || path.contains('/admin/farmers/')) {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer admin.access.token');
        if (request.method == 'PATCH') {
          await mutationGate?.future;
          if (mutationStatus != 200) {
            return response(null, status: mutationStatus);
          }
          farmerStatus = (jsonDecode(request.body) as Map)['status'] as String;
          if (lostMutationReply) throw const AppException(AppErrorKind.timeout);
          return response({'farmer': farmerAccountJson(status: farmerStatus)});
        }
        await accountGate?.future;
        final page = request.url.queryParameters['cursor'] == null ? 0 : 1;
        return response({
          'items': accountsEmpty
              ? <Object>[]
              : [
                  {
                    ...farmerAccountJson(
                      id: page == 0
                          ? farmerId
                          : '42345678-1234-4123-8123-123456789abc',
                      status: farmerStatus,
                    ),
                    if (longValues)
                      'email': '${'field.' * 30}farmer@example.test',
                    if (longValues)
                      'displayName':
                          'Long synthetic farmer identity for responsive account management verification',
                  },
                ],
          'nextCursor': paginate && page == 0 ? farmerId : null,
        }, status: accountStatus);
      }
      if (path.endsWith('/admin/audit-logs')) {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer admin.access.token');
        await auditGate?.future;
        final page = request.url.queryParameters['cursor'] == null ? 0 : 1;
        final data = auditJson();
        if (page == 1) data['id'] = '52345678-1234-4123-8123-123456789abc';
        if (longValues) {
          data['metadata'] = {
            'fromStatus': 'ACTIVE',
            'toStatus': 'DEACTIVATED',
            'revokedSessions': 2147483647,
            'fieldsChanged': [
              'name',
              'description',
              'scientificName',
              'status',
            ],
            'documentVersion': 2147483647,
          };
        }
        return response({
          'items': auditsEmpty ? <Object>[] : [data],
          'nextCursor': paginate && page == 0 ? data['id'] : null,
        }, status: auditStatus);
      }
      if (path.endsWith('/admin/model-health')) {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer admin.access.token');
        await healthGate?.future;
        return response(
          healthStatus == 200 ? health : null,
          status: healthStatus,
        );
      }
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await fallback.send(copy));
    });
  }
}

/// Scroll real slivers until a control is hittable, including lazily built rows.
Future<void> r06dReveal(WidgetTester tester, Finder finder) async {
  final scroll = find.byType(CustomScrollView).evaluate().isNotEmpty
      ? find.byType(CustomScrollView).first
      : find
            .descendant(
              of: find.byType(ModelHealthView),
              matching: find.byType(SingleChildScrollView),
            )
            .first;
  for (var i = 0; i < 80; i++) {
    if (finder.hitTestable().evaluate().isNotEmpty) {
      return;
    }
    final upward =
        finder.evaluate().isNotEmpty &&
        tester.getRect(finder.first).bottom < tester.getRect(scroll).top;
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
        )
        .position;
    final step = position.viewportDimension * 0.6;
    position.jumpTo(
      (position.pixels + (upward ? -step : step)).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pumpAndSettle();
  }
  throw TestFailure('Could not reveal $finder');
}

Future<void> r06dTap(WidgetTester tester, Finder finder) async {
  await r06dReveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
