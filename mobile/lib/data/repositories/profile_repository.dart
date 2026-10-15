import '../../core/utils/request_key.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../datasources/leaf_image_datasource.dart';
import '../models/farmer_profile.dart';
import '../models/selected_leaf_image.dart';

abstract interface class ProfileRepository {
  bool get signedIn;
  int? get sessionRevision;
  Future<FarmerProfile?> read();
  Future<FarmerProfile> save(ProfileDraft draft, String? revision);
  Future<SelectedLeafImage?> choosePhoto();
  Future<FarmerProfile> uploadPhoto(
    SelectedLeafImage photo,
    String revision,
    void Function(double) progress,
  );
  Future<FarmerProfile> removePhoto(String revision);
}

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._api, this._images);
  final ApiClient _api;
  final LeafImageDatasource _images;
  @override
  bool get signedIn => _api.hasAuthenticatedSession;
  @override
  int? get sessionRevision => _api.sessionRevision;
  @override
  Future<FarmerProfile?> read() async => FarmerProfile.fromResponse(
    (await _api.get('profile', authenticated: true)).data,
  );
  @override
  Future<FarmerProfile> save(ProfileDraft draft, String? revision) async =>
      _required(
        (await _api.request(
          ApiMethod.patch,
          'profile',
          authenticated: true,
          body: draft.toJson(revision),
        )).data,
      );
  @override
  Future<SelectedLeafImage?> choosePhoto() =>
      _images.pick(LeafImageSource.gallery);
  @override
  Future<FarmerProfile> uploadPhoto(
    SelectedLeafImage photo,
    String revision,
    void Function(double) progress,
  ) async {
    if (photo.width < 16 || photo.height < 16) {
      throw const AppException(AppErrorKind.invalidImage);
    }
    final key = newRequestKey();
    return _required(
      (await _api.uploadImage(
        bytes: photo.bytes,
        filename: photo.filename,
        mimeType: photo.mimeType,
        idempotencyKey: key,
        path: 'profile/avatar',
        profileRevision: revision,
        onProgress: progress,
      )).data,
    );
  }

  @override
  Future<FarmerProfile> removePhoto(String revision) async => _required(
    (await _api.request(
      ApiMethod.delete,
      'profile/avatar',
      authenticated: true,
      body: {'expectedRevision': revision},
    )).data,
  );
  FarmerProfile _required(Object? value) =>
      FarmerProfile.fromResponse(value) ??
      (throw const AppException(AppErrorKind.invalidResponse));
}
