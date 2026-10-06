import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/datasources/scan_datasource.dart';
import 'package:maizedoctor/data/models/selected_leaf_image.dart';
import 'package:maizedoctor/data/repositories/scan_repository.dart';
import 'package:maizedoctor/features/disease_detection/view_models/scan_view_model.dart';
import '../scans/helpers.dart';

class FixtureImageSource implements LeafImageDatasource {
  @override
  bool get cameraSupported => false;
  @override
  Future<SelectedLeafImage?> pick(LeafImageSource source) async => leafImage;
  @override
  Future<SelectedLeafImage?> recover() async => null;
}

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_SCAN_CHECK');
  test(
    'Flutter Scan ViewModel -> repository -> API -> Node -> Cloudinary -> PostgreSQL',
    () async {
      final api = ApiClient(config: AppConfig.fromEnvironment());
      final model = ScanViewModel(
        ApiScanRepository(FixtureImageSource(), ScanDatasource(api)),
      );
      try {
        await model.select(LeafImageSource.gallery);
        expect(model.image, isNotNull);
        await model.upload();
        expect(model.error, isNull);
        expect(model.scan, isNotNull);
        expect(model.uploading, false);
        expect(model.scan?.mimeType, 'image/png');
        expect(model.progress, 1);
      } finally {
        model.dispose();
        api.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: live
        ? false
        : 'Opt in against a fixture-cleaning development backend using RUN_LIVE_SCAN_CHECK.',
  );
}
