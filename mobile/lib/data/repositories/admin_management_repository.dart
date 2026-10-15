import '../../core/network/api_client.dart';
import '../models/admin_management.dart';

abstract interface class AdminManagementRepository {
  bool get hasSession;
  int? get revision;
  Future<ManagementPage> list(ManagementArea area, {String? cursor});
  Future<ManagementEntry> document(String id);
  Future<void> save(ManagementEditor editor, Map<String, Object?> body);
  Future<void> index(String id);
  Future<void> status(
    ManagementArea area,
    ManagementEntry entry,
    String status,
  );
}

class ApiAdminManagementRepository implements AdminManagementRepository {
  const ApiAdminManagementRepository(this._api);
  final ApiClient _api;
  @override
  bool get hasSession => _api.hasAuthenticatedSession;
  @override
  int? get revision => _api.sessionRevision;
  String _path(ManagementArea area) => switch (area) {
    ManagementArea.diseases => 'admin/knowledge/diseases',
    ManagementArea.knowledge => 'admin/knowledge/documents',
    ManagementArea.fertilizer => 'admin/calculators/fertilizer/rules',
    ManagementArea.yieldRules => 'admin/calculators/yield/configurations',
  };
  @override
  Future<ManagementPage> list(ManagementArea area, {String? cursor}) async =>
      ManagementPage.fromJson(
        (await _api.get(
          _path(area),
          authenticated: true,
          query: cursor == null ? null : {'cursor': cursor},
        )).data,
        area,
      );
  @override
  Future<ManagementEntry> document(String id) async => ManagementEntry.fromJson(
    (await _api.get('admin/knowledge/documents/$id', authenticated: true)).data,
    ManagementArea.knowledge,
  );
  @override
  Future<void> save(ManagementEditor editor, Map<String, Object?> body) async {
    await _api.request(
      editor.area == ManagementArea.diseases ? ApiMethod.patch : ApiMethod.post,
      _path(editor.area) +
          (editor.area == ManagementArea.diseases
              ? '/${editor.entry!.values['slug']}'
              : ''),
      body: body,
      authenticated: true,
    );
  }

  @override
  Future<void> index(String id) async {
    await _api.request(
      ApiMethod.post,
      'admin/knowledge/documents/$id/index',
      body: {},
      authenticated: true,
      requestTimeout: const Duration(seconds: 150),
    );
  }

  @override
  Future<void> status(
    ManagementArea area,
    ManagementEntry entry,
    String status,
  ) async {
    await _api.request(
      ApiMethod.patch,
      '${_path(area)}/${entry.id}/status',
      authenticated: true,
      body: {
        'status': status,
        if (area == ManagementArea.knowledge) 'expectedStatus': entry.status,
      },
      requestTimeout: const Duration(seconds: 150),
    );
  }
}
