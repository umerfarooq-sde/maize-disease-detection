import '../../core/exceptions/app_exception.dart';

class AiOperationSummary {
  const AiOperationSummary(
    this.scope,
    this.operation,
    this.requests,
    this.successes,
    this.failures,
    this.abstained,
    this.averageMs,
    this.p50Ms,
    this.p95Ms,
  );
  final String scope, operation;
  final int requests, successes, failures, abstained;
  final double averageMs, p50Ms, p95Ms;
}

class AiOperations {
  const AiOperations(
    this.status,
    this.rows,
    this.daily,
    this.dropped, {
    this.pending = 0,
  });
  final int pending;
  final String status;
  final List<AiOperationSummary> rows;
  final List<({String date, String scope, int requests, int failures})> daily;
  final int? dropped;
  factory AiOperations.fromJson(Object? value) {
    const invalid = AppException(AppErrorKind.invalidResponse);
    if (value is! Map<String, dynamic> ||
        !['COLLECTED', 'UNAVAILABLE'].contains(value['status'])) {
      throw invalid;
    }
    if (value['status'] == 'UNAVAILABLE') {
      return const AiOperations('UNAVAILABLE', [], [], null);
    }
    final totals = value['totals'],
        daily = value['daily'],
        collection = value['collection'];
    if (totals is! List ||
        totals.length > 18 ||
        daily is! List ||
        daily.length > 1098 ||
        collection is! Map<String, dynamic>) {
      throw invalid;
    }
    int count(Object? n) {
      if (n is! int || n < 0 || n > 9007199254740991) throw invalid;
      return n;
    }

    double duration(Object? n) {
      if (n is! num || !n.isFinite || n < 0 || n > 86400000) throw invalid;
      return n.toDouble();
    }

    String scope(Object? s) {
      if (s is! String || !['NODE', 'AI_SERVICE', 'PROVIDER'].contains(s)) {
        throw invalid;
      }
      return s;
    }

    final rows = totals
        .map((raw) {
          if (raw is! Map<String, dynamic>) throw invalid;
          final operation = raw['operation'];
          if (operation is! String ||
              ![
                'INFERENCE',
                'RETRIEVAL',
                'GENERATION',
                'EXPLANATION',
                'GEMINI',
                'EMBEDDING',
              ].contains(operation)) {
            throw invalid;
          }
          final requests = count(raw['requests']),
              success = count(raw['successes']),
              failed = count(raw['failures']),
              abstain = count(raw['abstained']);
          if (requests != success + failed + abstain) throw invalid;
          return AiOperationSummary(
            scope(raw['scope']),
            operation,
            requests,
            success,
            failed,
            abstain,
            duration(raw['averageMs']),
            duration(raw['p50Ms']),
            duration(raw['p95Ms']),
          );
        })
        .toList(growable: false);
    final days = daily
        .map((raw) {
          if (raw is! Map<String, dynamic> ||
              raw['date'] is! String ||
              DateTime.tryParse(raw['date'] as String) == null) {
            throw invalid;
          }
          final requests = count(raw['requests']),
              failures = count(raw['failures']);
          if (failures > requests) throw invalid;
          return (
            date: raw['date'] as String,
            scope: scope(raw['scope']),
            requests: requests,
            failures: failures,
          );
        })
        .toList(growable: false);
    return AiOperations(
      'COLLECTED',
      List.unmodifiable(rows),
      List.unmodifiable(days),
      count(collection['localDropped']),
      pending: count(collection['localPending'] ?? 0),
    );
  }
}
