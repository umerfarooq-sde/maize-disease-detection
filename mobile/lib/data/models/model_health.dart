import '../../core/exceptions/app_exception.dart';
import 'farmer_analytics.dart';
import 'scan_prediction.dart';

class ModelRegistryEntry {
  const ModelRegistryEntry(
    this.version,
    this.architecture,
    this.datasetVersion,
    this.preprocessingVersion,
    this.status,
    this.registeredAt,
  );
  final String version,
      architecture,
      datasetVersion,
      preprocessingVersion,
      status;
  final DateTime registeredAt;
}

class OfflineClassMetric {
  const OfflineClassMetric(
    this.label,
    this.support,
    this.precision,
    this.recall,
    this.f1,
    this.specificity,
  );
  final String label;
  final int support;
  final double? precision, recall, f1, specificity;
}

class OfflineEvaluation {
  OfflineEvaluation(Map<String, dynamic> data)
    : architecture = _text(data['architecture']),
      datasetVersion = _text(data['datasetVersion']),
      experimentId = _text(data['experimentId']),
      indexFingerprint = _text(data['indexFingerprint']) {
    if (data['trainedAt'] != null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(indexFingerprint)) {
      throw _invalid();
    }
    final evaluation = _object(data['evaluation']);
    sampleCount = _count(evaluation['sample_count']);
    accuracy = _score(evaluation['accuracy'])!;
    precision = _score(evaluation['macro_precision'])!;
    recall = _score(evaluation['macro_recall'])!;
    f1 = _score(evaluation['macro_f1'])!;
    final names = evaluation['class_names'];
    final rows = evaluation['per_class'];
    final matrix = evaluation['confusion_matrix'];
    if (names is! List ||
        rows is! List ||
        matrix is! List ||
        names.length != 4 ||
        rows.length != 4 ||
        matrix.length != 4 ||
        sampleCount == 0) {
      throw _invalid();
    }
    classes = List.unmodifiable(
      List.generate(4, (i) {
        final row = _object(rows[i]);
        if (names[i] != modelLabels[i] || row['label'] != modelLabels[i]) {
          throw _invalid();
        }
        return OfflineClassMetric(
          modelLabels[i],
          _count(row['support']),
          _score(row['precision'], nullable: true),
          _score(row['recall'], nullable: true),
          _score(row['f1'], nullable: true),
          _score(row['specificity'], nullable: true),
        );
      }),
    );
    confusionMatrix = List.unmodifiable(
      List.generate(4, (i) {
        final row = matrix[i];
        if (row is! List || row.length != 4) throw _invalid();
        final counts = row.map(_count).toList();
        if (counts.reduce((a, b) => a + b) != classes[i].support) {
          throw _invalid();
        }
        return List<int>.unmodifiable(counts);
      }),
    );
    if (confusionMatrix.expand((row) => row).reduce((a, b) => a + b) !=
            sampleCount ||
        (List.generate(
                          4,
                          (i) => confusionMatrix[i][i],
                        ).reduce((a, b) => a + b) /
                        sampleCount -
                    accuracy)
                .abs() >
            1e-9) {
      throw _invalid();
    }
  }
  final String architecture, datasetVersion, experimentId, indexFingerprint;
  late final int sampleCount;
  late final double accuracy, precision, recall, f1;
  late final List<OfflineClassMetric> classes;
  late final List<List<int>> confusionMatrix;
}

const modelLabels = ScanPrediction.classLabels;

class ModelRuntime {
  ModelRuntime(Map<String, dynamic> data)
    : since = analyticsTimestamp(data['since']),
      requests = _count(data['requests']),
      inFlight = _count(data['inFlight']),
      successes = _count(data['successes']),
      failures = _count(data['failures']),
      lowConfidence = _count(data['lowConfidence']),
      lowConfidenceRate = _score(data['lowConfidenceRate'], nullable: true) {
    final latency = data['meanLatencyMs'];
    if (latency != null &&
        (latency is! num || !latency.isFinite || latency < 0)) {
      throw _invalid();
    }
    meanLatencyMs = (latency as num?)?.toDouble();
    final raw = _object(data['predictionDistribution']);
    if (raw.length != 4 || !modelLabels.every(raw.containsKey)) {
      throw _invalid();
    }
    distribution = Map.unmodifiable(raw.map((k, v) => MapEntry(k, _count(v))));
    if (data['scope'] != 'PROCESS_SINCE_START' ||
        requests != inFlight + successes + failures ||
        distribution.values.reduce((a, b) => a + b) != successes ||
        lowConfidence > successes ||
        (successes == 0
            ? lowConfidenceRate != null
            : lowConfidenceRate == null ||
                  (lowConfidenceRate! - lowConfidence / successes).abs() >
                      1e-9) ||
        ((successes + failures == 0) != (meanLatencyMs == null))) {
      throw _invalid();
    }
  }
  final DateTime since;
  final int requests, inFlight, successes, failures, lowConfidence;
  final double? lowConfidenceRate;
  late final double? meanLatencyMs;
  late final Map<String, int> distribution;
}

class AdminModelHealth {
  AdminModelHealth.fromJson(Object? value) {
    final data = _object(value);
    asOf = analyticsTimestamp(data['asOf']);
    final registry = _object(data['registry']);
    registryStatus = _text(registry['status']);
    productionVersion = _optionalText(registry['productionVersion']);
    if (![
          'NOT_PROMOTED',
          'SINGLE_PRODUCTION',
          'MULTIPLE_PRODUCTION',
        ].contains(registryStatus) ||
        ((registryStatus == 'SINGLE_PRODUCTION') !=
            (productionVersion != null)) ||
        data['drift'] != 'NOT_AVAILABLE_NO_GROUND_TRUTH') {
      throw _invalid();
    }
    final models = registry['models'];
    if (models is! List || models.length > 50) throw _invalid();
    entries = List.unmodifiable(
      models.map((raw) {
        final row = _object(raw);
        return ModelRegistryEntry(
          _text(row['version']),
          _text(row['architecture']),
          _text(row['datasetVersion']),
          _text(row['preprocessingVersion']),
          _text(row['status']),
          analyticsTimestamp(row['registeredAt']),
        );
      }),
    );
    final service = _object(data['service']);
    status = _text(service['status']);
    configuredVersion = _optionalText(service['configuredVersion']);
    if (![
          'READY',
          'NOT_LOADED',
          'UNAVAILABLE',
          'INCOMPATIBLE',
        ].contains(status) ||
        service['registered'] is! bool ||
        service['matchesProduction'] is! bool) {
      throw _invalid();
    }
    registered = service['registered'] as bool;
    matchesProduction = service['matchesProduction'] as bool;
    final raw = service['data'];
    if (raw == null) {
      if (['READY', 'NOT_LOADED'].contains(status)) throw _invalid();
      modelVersion = preprocessingVersion = null;
      confidencePolicy = null;
      offline = null;
      runtime = null;
    } else {
      final live = _object(raw);
      modelVersion = _optionalText(live['modelVersion']);
      preprocessingVersion = _optionalText(live['preprocessingVersion']);
      confidencePolicy = _text(live['confidencePolicy']);
      if (live['ready'] != (status == 'READY') ||
          ((status == 'READY') !=
              (modelVersion != null && preprocessingVersion != null)) ||
          !['VALIDATION_BASED', 'UNCONFIGURED'].contains(confidencePolicy) ||
          (status == 'READY' && modelVersion != configuredVersion)) {
        throw _invalid();
      }
      offline = live['development'] == null
          ? null
          : OfflineEvaluation(_object(live['development']));
      if (status != 'READY' && offline != null) throw _invalid();
      runtime = ModelRuntime(_object(live['runtime']));
    }
  }
  late final DateTime asOf;
  late final String registryStatus, status;
  late final String? productionVersion,
      configuredVersion,
      modelVersion,
      preprocessingVersion,
      confidencePolicy;
  late final bool registered, matchesProduction;
  late final List<ModelRegistryEntry> entries;
  late final OfflineEvaluation? offline;
  late final ModelRuntime? runtime;
}

AppException _invalid() => const AppException(AppErrorKind.invalidResponse);
Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) throw _invalid();
  return value;
}

String _text(Object? value) {
  if (value is! String || value.isEmpty || value.length > 160) throw _invalid();
  return value;
}

String? _optionalText(Object? value) => value == null ? null : _text(value);
int _count(Object? value) {
  if (value is! int || value < 0 || value > 9007199254740991) throw _invalid();
  return value;
}

double? _score(Object? value, {bool nullable = false}) {
  if (value == null && nullable) return null;
  if (value is! num || !value.isFinite || value < 0 || value > 1) {
    throw _invalid();
  }
  return value.toDouble();
}
