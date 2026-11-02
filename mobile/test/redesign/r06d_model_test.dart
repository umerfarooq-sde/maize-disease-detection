import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/features/admin/views/model_health_view.dart';
import 'package:maizedoctor/features/admin/widgets/admin_metric_grid.dart';
import '../support/design_fonts.dart';
import 'r06a_fixtures.dart';
import 'r06d_fixtures.dart';

void main() {
  setUpAll(loadDesignFonts);
  testWidgets(
    'reported identity, research evidence and process statistics stay separate and read-only',
    (tester) async {
      final fixture = R06DFixture();
      await fixture.mount(tester, location: '/admin/model-health');
      expect(find.text('synthetic-v1'), findsOneWidget);
      expect(find.text('Live service: READY'), findsOneWidget);
      expect(find.textContaining('No model has been promoted'), findsOneWidget);
      expect(find.textContaining('not a fresh inference test'), findsOneWidget);
      expect(
        find.text('Offline evaluation — research evidence'),
        findsOneWidget,
      );
      await r06dTap(tester, find.text('Per-class test metrics'));
      expect(find.text('Support: 1 unique contents'), findsNWidgets(4));
      expect(find.textContaining('Specificity: 100.00%'), findsNWidgets(4));
      await r06dTap(tester, find.text('Saved confusion matrix'));
      expect(find.byType(DataTable), findsOneWidget);
      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.rows.length, 4);
      await r06dTap(tester, find.text('Evaluation provenance'));
      expect(find.textContaining('Experiment: synthetic-test'), findsOneWidget);
      expect(find.textContaining('not recorded in artifact'), findsOneWidget);
      await r06dReveal(tester, find.text('Runtime operational statistics'));
      final metrics = tester.widgetList<AdminMetricCard>(
        find.byType(AdminMetricCard),
      );
      expect(
        metrics.firstWhere((m) => m.label == 'Handler attempts').value,
        '3',
      );
      expect(
        metrics
            .firstWhere((m) => m.label == 'Mean completed-request latency')
            .value,
        '12.0 ms',
      );
      expect(find.textContaining('100.00% of successes'), findsOneWidget);
      await r06dTap(tester, find.text('Prediction distribution'));
      expect(find.text('Healthy: 1'), findsOneWidget);
      await r06dTap(tester, find.text('Technical details and registry'));
      expect(find.textContaining('Common Rust · Common_Rust'), findsOneWidget);
      expect(find.textContaining('Status: VALIDATED'), findsOneWidget);
      expect(find.textContaining('Model Confidence 99%'), findsNothing);
      for (final unsupported in [
        'Retrain Model',
        'Promote Model',
        'Change Threshold',
        'Run Calibration',
      ]) {
        expect(find.text(unsupported), findsNothing);
      }
      expect(
        fixture.requests.where((r) => r.url.path.contains('/admin/')).length,
        1,
      );
      expect(
        fixture.requests
            .where((r) => r.url.path.contains('/admin/'))
            .every((r) => r.method == 'GET'),
        true,
      );
      await r06dTap(tester, find.text('View AI Operations'));
      expect(fixture.router.state.uri.path, '/admin/ai-operations');
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/ai-operations'))
            .length,
        1,
      );
    },
  );
  testWidgets(
    'unconfigured policy explains raw scores without inventing numeric settings',
    (tester) async {
      final fixture = R06DFixture();
      await fixture.mount(tester, location: '/admin/model-health');
      expect(find.text('Reported policy: UNCONFIGURED'), findsOneWidget);
      expect(
        find.textContaining(
          'Every successful prediction is marked low confidence',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Numeric threshold, temperature'),
        findsOneWidget,
      );
      expect(find.textContaining('Temperature: 1'), findsNothing);
      expect(find.textContaining('Threshold: 0.'), findsNothing);
    },
  );
  for (final status in ['UNAVAILABLE', 'INCOMPATIBLE']) {
    testWidgets(
      '$status shows missing measurements without a false zero or invented integrity cause',
      (tester) async {
        final fixture = R06DFixture();
        fixture.health['service'] = {
          'status': status,
          'configuredVersion': 'synthetic-v1',
          'registered': false,
          'matchesProduction': false,
          'data': null,
        };
        await fixture.mount(tester, location: '/admin/model-health');
        expect(find.text('Live service: $status'), findsOneWidget);
        expect(find.text('Offline evidence unavailable'), findsOneWidget);
        expect(
          find.textContaining('Live statistics unavailable'),
          findsOneWidget,
        );
        expect(find.byType(AdminMetricCard), findsNothing);
        expect(find.textContaining('SHA256 mismatch'), findsNothing);
        expect(find.text('Reported policy: Unavailable'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'NOT_LOADED reports readiness separately from returned process counters',
    (tester) async {
      final fixture = R06DFixture();
      final service = fixture.health['service'] as Map;
      service['status'] = 'NOT_LOADED';
      service['data'] = <String, dynamic>{
        ...service['data'] as Map<String, dynamic>,
        'ready': false,
        'modelVersion': null,
        'preprocessingVersion': null,
        'development': null,
      };
      await fixture.mount(tester, location: '/admin/model-health');
      expect(find.text('Live service: NOT_LOADED'), findsOneWidget);
      expect(find.text('Loaded model unavailable'), findsOneWidget);
      expect(find.text('Offline evidence unavailable'), findsOneWidget);
      expect(find.text('Handler attempts'), findsOneWidget);
      expect(find.textContaining('Test accuracy'), findsNothing);
    },
  );
  testWidgets(
    'actual zero attempts remains zero while undefined rates and latency remain unavailable',
    (tester) async {
      final fixture = R06DFixture();
      final data = (fixture.health['service'] as Map)['data'] as Map;
      data['runtime'] = {
        'scope': 'PROCESS_SINCE_START',
        'since': '2026-10-15T00:00:00Z',
        'requests': 0,
        'inFlight': 0,
        'successes': 0,
        'failures': 0,
        'lowConfidence': 0,
        'lowConfidenceRate': null,
        'meanLatencyMs': null,
        'predictionDistribution': {
          'Common_Rust': 0,
          'Gray_Leaf_Spot': 0,
          'Healthy': 0,
          'Northern_Corn_Leaf_Blight': 0,
        },
      };
      await fixture.mount(tester, location: '/admin/model-health');
      final metrics = tester.widgetList<AdminMetricCard>(
        find.byType(AdminMetricCard),
      );
      expect(
        metrics.firstWhere((m) => m.label == 'Handler attempts').value,
        '0',
      );
      expect(
        metrics
            .firstWhere((m) => m.label == 'Mean completed-request latency')
            .value,
        isNull,
      );
      expect(
        find.text('Low-confidence results: 0 · Unavailable of successes'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'health failure retries without retaining success; corrupt matrix fails typed contract',
    (tester) async {
      final fixture = R06DFixture()..healthStatus = 503;
      await fixture.mount(tester, location: '/admin/model-health');
      expect(find.text('Try again'), findsOneWidget);
      fixture.healthStatus = 200;
      await r06Tap(tester, find.text('Try again'));
      expect(find.text('Live service: READY'), findsOneWidget);
      final evaluation =
          (((fixture.health['service'] as Map)['data'] as Map)['development']
                  as Map)['evaluation']
              as Map;
      evaluation['sample_count'] = 99;
      await r06Tap(tester, find.byTooltip('Refresh model health'));
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Offline evaluation — research evidence'), findsNothing);
      expect(find.textContaining('100.00%'), findsNothing);
    },
  );
  testWidgets(
    'late health response is discarded after logout and next identity loads fresh data',
    (tester) async {
      final fixture = R06DFixture();
      await fixture.mount(tester, location: '/admin/model-health');
      fixture.healthGate = Completer();
      await tester.tap(find.byTooltip('Refresh model health'));
      await tester.pump();
      expect(find.text('Checking model health…'), findsOneWidget);
      await fixture.admin.signOut();
      await tester.pump();
      fixture.healthGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ModelHealthView), findsNothing);
      expect(find.text('synthetic-v1'), findsNothing);
      fixture.healthGate = null;
      await fixture.admin.signIn(
        'admin.second@example.test',
        'synthetic-password',
      );
      await tester.pumpAndSettle();
      expect(find.text('Live service: READY'), findsOneWidget);
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/model-health'))
            .length,
        3,
      );
    },
  );
}
