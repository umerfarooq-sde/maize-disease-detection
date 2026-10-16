import 'dart:convert';
import 'dart:typed_data';
import '../../core/network/api_client.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/request_key.dart';
import '../datasources/leaf_image_datasource.dart';
import '../models/reference_media.dart';
import '../models/selected_leaf_image.dart';

class ReferenceMediaRepository {
  ReferenceMediaRepository(
    this.api, {
    this.admin = false,
    LeafImageDatasource? picker,
  }) : _picker = picker;
  final ApiClient api;
  final bool admin;
  final LeafImageDatasource? _picker;
  int? get revision => api.sessionRevision;
  bool get enabled => !admin || api.hasAuthenticatedSession;
  Future<List<ReferenceMedia>> list(String slug) async {
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      throw const AppException(AppErrorKind.validation);
    }
    final raw = (await api.get(
      admin ? 'admin/disease-images/$slug/items' : 'diseases/$slug/images',
      authenticated: admin,
    )).data;
    if (raw is! Map<String, dynamic> ||
        raw['items'] is! List ||
        (raw['items'] as List).length > 100) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return List.unmodifiable(
      (raw['items'] as List).map(ReferenceMedia.fromJson),
    );
  }

  Future<Uint8List> image(ReferenceMedia media) => api.readPrivateImage(
    media.path ?? (throw const AppException(AppErrorKind.notFound)),
  );
  Future<SelectedLeafImage?> choose() =>
      _picker?.pick(LeafImageSource.gallery) ?? Future.value(null);
  Future<void> upload(
    SelectedLeafImage image,
    Map<String, Object?> metadata,
  ) async {
    await api.uploadImage(
      bytes: image.bytes,
      filename: image.filename,
      mimeType: image.mimeType,
      idempotencyKey: newRequestKey(),
      path: 'admin/disease-images',
      referenceMetadata: jsonEncode(metadata),
    );
  }

  Future<void> edit(ReferenceMedia media, Map<String, Object?> metadata) async {
    await api.request(
      ApiMethod.patch,
      'admin/disease-images/${media.id}',
      authenticated: true,
      body: {...metadata, 'expectedRevision': media.revision},
    );
  }

  Future<void> status(ReferenceMedia media, String status, String note) async {
    await api.request(
      ApiMethod.patch,
      'admin/disease-images/${media.id}/status',
      authenticated: true,
      body: {
        'status': status,
        'expectedRevision': media.revision,
        'reviewNote': note,
      },
    );
  }
}

class AdminReferenceMediaRepository extends ReferenceMediaRepository {
  AdminReferenceMediaRepository(super.api, {super.picker}) : super(admin: true);
}
