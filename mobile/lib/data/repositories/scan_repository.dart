import '../datasources/leaf_image_datasource.dart';
import '../datasources/scan_datasource.dart';
import '../models/scan_record.dart';
import '../models/selected_leaf_image.dart';

abstract interface class ScanRepository {
  bool get cameraSupported;
  Future<SelectedLeafImage?> select(LeafImageSource source);
  Future<SelectedLeafImage?> recoverSelection();
  Future<ScanRecord> upload(
    SelectedLeafImage image,
    String requestKey,
    void Function(double) onProgress,
  );
}

class ApiScanRepository implements ScanRepository {
  ApiScanRepository(this._images, this._scans);
  final LeafImageDatasource _images;
  final ScanDatasource _scans;
  @override
  bool get cameraSupported => _images.cameraSupported;
  @override
  Future<SelectedLeafImage?> select(LeafImageSource source) =>
      _images.pick(source);
  @override
  Future<SelectedLeafImage?> recoverSelection() => _images.recover();
  @override
  Future<ScanRecord> upload(
    SelectedLeafImage image,
    String requestKey,
    void Function(double) onProgress,
  ) => _scans.upload(image, requestKey, onProgress);
}
