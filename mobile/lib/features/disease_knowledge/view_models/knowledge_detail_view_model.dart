import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/knowledge.dart';
import '../../../data/repositories/knowledge_repository.dart';

class KnowledgeDetailViewModel extends ChangeNotifier {
  KnowledgeDetailViewModel(this._repository, this.slug);
  final KnowledgeRepository _repository;
  final String slug;
  DiseaseDetail? detail;
  AppException? error;
  bool loading = false;
  bool _disposed = false;
  Future<void> load() async {
    if (loading || _disposed) return;
    loading = true;
    detail = null;
    error = null;
    notifyListeners();
    try {
      final response = await _repository.detail(slug);
      if (!_disposed) detail = response;
    } on AppException catch (failure) {
      if (!_disposed) error = failure;
    } catch (_) {
      if (!_disposed) error = const AppException(AppErrorKind.network);
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
