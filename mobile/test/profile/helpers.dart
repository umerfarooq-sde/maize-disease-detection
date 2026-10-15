import 'dart:async';
import 'package:maizedoctor/data/models/farmer_profile.dart';
import 'package:maizedoctor/data/models/selected_leaf_image.dart';
import 'package:maizedoctor/data/repositories/profile_repository.dart';
import '../scans/helpers.dart' show leafImage;

Map<String, Object?> profileJson({
  String name = 'Fixture farmer',
  String? photo,
}) => {
  'profile': {
    'displayName': name,
    'region': 'Fixture region',
    'countryCode': 'PK',
    'fieldAreaHectares': '1.2345',
    'avatarUrl': photo,
    'updatedAt': '2026-10-15T00:00:00Z',
    'revision': 'a' * 64,
  },
};

class FakeProfileRepository implements ProfileRepository {
  @override
  bool signedIn = true;
  @override
  int? sessionRevision = 1;
  FarmerProfile? saved = FarmerProfile.fromResponse(profileJson());
  Completer<FarmerProfile?>? pendingRead;
  Completer<FarmerProfile>? pendingSave;
  Object? failure;
  int reads = 0, writes = 0, uploads = 0, removals = 0;
  @override
  Future<FarmerProfile?> read() async {
    reads++;
    if (failure case final error?) throw error;
    return pendingRead?.future ?? saved;
  }

  @override
  Future<FarmerProfile> save(ProfileDraft draft, String? revision) async {
    writes++;
    draft.toJson(revision);
    if (failure case final error?) throw error;
    if (pendingSave != null) return pendingSave!.future;
    return saved = FarmerProfile.fromResponse(
      profileJson(name: draft.displayName),
    )!;
  }

  @override
  Future<SelectedLeafImage?> choosePhoto() async {
    if (failure case final error?) throw error;
    return leafImage;
  }

  @override
  Future<FarmerProfile> uploadPhoto(
    SelectedLeafImage photo,
    String revision,
    void Function(double) progress,
  ) async {
    uploads++;
    if (failure case final error?) throw error;
    progress(0.5);
    progress(1);
    return saved = FarmerProfile.fromResponse(
      profileJson(photo: 'profile/avatar?v=${'b' * 64}'),
    )!;
  }

  @override
  Future<FarmerProfile> removePhoto(String revision) async {
    removals++;
    if (failure case final error?) throw error;
    return saved = FarmerProfile.fromResponse(profileJson())!;
  }
}
