import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/assistant_question.dart';
import '../../../data/models/knowledge.dart';
import '../../../data/repositories/knowledge_repository.dart';

class KnowledgeViewModel extends ChangeNotifier {
  KnowledgeViewModel(this._repository);
  final KnowledgeRepository _repository;
  List<DiseaseSummary> items = const [];
  KnowledgeSearchResult? result;
  bool loading = false;
  bool searching = false;
  AppException? catalogueError;
  AppException? searchError;
  String? query;
  int _searchRevision = 0;
  bool _disposed = false;

  Future<void> load() async {
    if (loading || _disposed) return;
    loading = true;
    catalogueError = null;
    items = const [];
    _changed();
    try {
      final list = await _repository.catalogue();
      if (!_disposed) items = list;
    } on AppException catch (error) {
      if (!_disposed) catalogueError = error;
    } catch (_) {
      if (!_disposed) catalogueError = const AppException(AppErrorKind.network);
    } finally {
      if (!_disposed) {
        loading = false;
        _changed();
      }
    }
  }

  Future<void> search(String input) async {
    if (searching || _disposed) return;
    result = null;
    searchError = null;
    try {
      query = normalizeAssistantQuestion(input);
    } on AppException catch (error) {
      searchError = error;
      _changed();
      return;
    }
    final revision = ++_searchRevision;
    searching = true;
    _changed();
    try {
      final response = await _repository.search(query!);
      if (!_disposed && revision == _searchRevision) result = response;
    } on AppException catch (error) {
      if (!_disposed && revision == _searchRevision) searchError = error;
    } catch (_) {
      if (!_disposed && revision == _searchRevision) {
        searchError = const AppException(AppErrorKind.network);
      }
    } finally {
      if (!_disposed && revision == _searchRevision) {
        searching = false;
        _changed();
      }
    }
  }

  void clearSearch() {
    if (_disposed) return;
    _searchRevision++;
    searching = false;
    query = null;
    result = null;
    searchError = null;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchRevision++;
    super.dispose();
  }
}
