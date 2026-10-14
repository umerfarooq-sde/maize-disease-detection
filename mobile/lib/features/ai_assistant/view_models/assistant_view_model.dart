import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/assistant_answer.dart';
import '../../../data/models/assistant_question.dart';
import '../../../data/models/scan_prediction.dart';
import '../../../data/models/scan_record.dart';
import '../../../data/repositories/assistant_repository.dart';

class AssistantTurn {
  const AssistantTurn({
    required this.id,
    required this.question,
    this.diseaseLabel,
    this.knowledgeType,
    this.scan,
    this.answer,
    this.error,
  });
  final int id;
  final String question;
  final String? diseaseLabel;
  final String? knowledgeType;
  final ScanRecord? scan;
  final AssistantAnswer? answer;
  final AppException? error;

  AssistantTurn completed({AssistantAnswer? answer, AppException? error}) =>
      AssistantTurn(
        id: id,
        question: question,
        diseaseLabel: diseaseLabel,
        knowledgeType: knowledgeType,
        scan: scan,
        answer: answer,
        error: error,
      );
}

/// A bounded route-local conversation. Only the current question and explicit
/// disease/topic scope go to the server; previous messages are never submitted.
class AssistantViewModel extends ChangeNotifier {
  AssistantViewModel(this._repository, {ScanRecord? initialScan}) {
    if (initialScan != null && hasAuthenticatedSession) {
      _selectedScan = initialScan;
      _diseaseLabel = initialScan.prediction?.predictedClass;
    }
  }

  static const maxTurns = 12;
  final AssistantRepository _repository;
  final List<AssistantTurn> _turns = [];
  ScanRecord? _selectedScan;
  String? _diseaseLabel;
  String? _knowledgeType;
  String? _inputError;
  bool _busy = false;
  bool _disposed = false;
  int _generation = 0;
  int _nextId = 0;

  List<AssistantTurn> get turns => List.unmodifiable(_turns);
  bool get busy => _busy;
  bool get hasAuthenticatedSession => _repository.hasAuthenticatedSession;
  ScanRecord? get selectedScan => _selectedScan;
  String? get diseaseLabel => _diseaseLabel;
  String? get knowledgeType => _knowledgeType;
  String? get inputError => _inputError;
  AppException? get error => _turns.isEmpty ? null : _turns.last.error;
  bool get canRetry => !_busy && _turns.isNotEmpty && _turns.last.error != null;

  void selectDisease(String? label) {
    if (_disposed || _busy) return;
    if (label != null && !ScanPrediction.classLabels.contains(label)) return;
    if (_diseaseLabel == label) return;
    _diseaseLabel = label;
    _selectedScan = null;
    _inputError = null;
    _notify();
  }

  void selectTopic(String? topic) {
    if (_disposed || _busy) return;
    if (topic != null && !AssistantAnswer.knowledgeTypes.contains(topic)) {
      return;
    }
    _knowledgeType = topic;
    _inputError = null;
    _notify();
  }

  Future<void> ask(
    String question, {
    String? diseaseLabel,
    String? knowledgeType,
  }) async {
    if (_disposed || _busy) return;
    String normalized;
    try {
      normalized = normalizeAssistantQuestion(question);
    } on AppException {
      _inputError =
          'Use 3–1,000 characters, at most 1,800 UTF-8 bytes, '
          'and no control characters other than line breaks or tabs.';
      _notify();
      return;
    }
    final label = diseaseLabel ?? _diseaseLabel;
    final topic = knowledgeType ?? _knowledgeType;
    if ((label != null && !ScanPrediction.classLabels.contains(label)) ||
        (topic != null && !AssistantAnswer.knowledgeTypes.contains(topic))) {
      _inputError = 'Choose a supported maize disease and topic.';
      _notify();
      return;
    }
    final turn = AssistantTurn(
      id: _nextId++,
      question: normalized,
      diseaseLabel: label,
      knowledgeType: topic,
    );
    _append(turn);
    await _run(turn);
  }

  Future<void> explainScan(ScanRecord scan) async {
    if (_disposed || _busy) return;
    if (!hasAuthenticatedSession) {
      _inputError = 'Sign in to explain a scan from your history.';
      _notify();
      return;
    }
    if (scan.status != ScanStatus.completed || scan.prediction == null) {
      _inputError = 'Choose a completed scan with a model prediction.';
      _notify();
      return;
    }
    _selectedScan = scan;
    _diseaseLabel = scan.prediction!.predictedClass;
    _knowledgeType = null;
    final turn = AssistantTurn(
      id: _nextId++,
      question: 'Explain my selected scan',
      scan: scan,
      diseaseLabel: _diseaseLabel,
    );
    _append(turn);
    await _run(turn);
  }

  void _append(AssistantTurn turn) {
    _inputError = null;
    _turns.add(turn);
    if (_turns.length > maxTurns) _turns.removeAt(0);
  }

  Future<void> retry() async {
    if (_disposed || !canRetry) return;
    final previous = _turns.last;
    final retry = previous.completed();
    _turns[_turns.length - 1] = retry;
    await _run(retry);
  }

  Future<void> _run(AssistantTurn turn) async {
    final generation = ++_generation;
    final authenticated = hasAuthenticatedSession;
    bool active() => !_disposed && generation == _generation;
    _busy = true;
    _notify();
    try {
      final answer = turn.scan == null
          ? await _repository.ask(
              turn.question,
              diseaseLabel: turn.diseaseLabel,
              knowledgeType: turn.knowledgeType,
            )
          : await _repository.explainScan(turn.scan!);
      if (!active()) return;
      if (authenticated != hasAuthenticatedSession) {
        clear();
        return;
      }
      _turns[_turns.length - 1] = turn.completed(answer: answer);
    } on AppException catch (failure) {
      if (!active()) return;
      if (authenticated != hasAuthenticatedSession) {
        clear();
        return;
      }
      _turns[_turns.length - 1] = turn.completed(error: failure);
    } catch (_) {
      if (active()) {
        if (authenticated != hasAuthenticatedSession) {
          clear();
          return;
        }
        _turns[_turns.length - 1] = turn.completed(
          error: const AppException(AppErrorKind.server),
        );
      }
    } finally {
      if (active()) {
        _busy = false;
        _notify();
      }
    }
  }

  void clearScan() {
    if (_disposed || _busy) return;
    _selectedScan = null;
    _diseaseLabel = null;
    _knowledgeType = null;
    _notify();
  }

  void clear() {
    if (_disposed) return;
    _generation++;
    _turns.clear();
    _selectedScan = null;
    _diseaseLabel = null;
    _knowledgeType = null;
    _inputError = null;
    _busy = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _turns.clear();
    _selectedScan = null;
    super.dispose();
  }
}
