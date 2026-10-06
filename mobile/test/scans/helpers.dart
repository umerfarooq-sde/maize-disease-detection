import 'dart:async';
import 'dart:convert';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
import 'package:maizedoctor/data/models/selected_leaf_image.dart';
import 'package:maizedoctor/data/repositories/scan_repository.dart';

final leafImage = SelectedLeafImage(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAIAAABvFaqvAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAAJ0lEQVQ4jWNQCXGmCmIYNUhlNIxURtNRyGgWCRktRpxHS0jngaxFANZppNDL7oSMAAAAAElFTkSuQmCC',
  ),
  mimeType: 'image/png',
  width: 24,
  height: 24,
);
final savedScan = ScanRecord(
  id: 'aa29ad82-93ec-433d-8948-2e8ca17c7428',
  imageUrl: Uri.parse(
    'https://res.cloudinary.com/test/image/authenticated/leaf.png',
  ),
  mimeType: 'image/png',
  bytes: leafImage.bytes.length,
  uploadedAt: DateTime.utc(2026, 10, 6),
  createdAt: DateTime.utc(2026, 10, 6),
);
Map<String, Object?> scanJson() => {
  'id': savedScan.id,
  'status': 'PENDING',
  'createdAt': savedScan.createdAt.toIso8601String(),
  'image': {
    'url': savedScan.imageUrl.toString(),
    'mimeType': savedScan.mimeType,
    'bytes': savedScan.bytes,
    'uploadedAt': savedScan.uploadedAt.toIso8601String(),
  },
};

class FakeScanRepository implements ScanRepository {
  @override
  bool cameraSupported = true;
  SelectedLeafImage? selection = leafImage;
  SelectedLeafImage? recovered;
  AppException? selectError;
  AppException? uploadError;
  Completer<ScanRecord>? pending;
  final keys = <String>[];
  final sources = <LeafImageSource>[];
  void Function(double)? reportProgress;
  @override
  Future<SelectedLeafImage?> select(LeafImageSource source) async {
    sources.add(source);
    if (selectError case final error?) throw error;
    return selection;
  }

  @override
  Future<SelectedLeafImage?> recoverSelection() async => recovered;
  @override
  Future<ScanRecord> upload(
    SelectedLeafImage image,
    String requestKey,
    void Function(double) onProgress,
  ) async {
    keys.add(requestKey);
    reportProgress = onProgress;
    if (uploadError case final error?) throw error;
    return pending?.future ?? Future.value(savedScan);
  }
}
