import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/core/network/api_client.dart';
import 'package:maizedoctor/core/network/app_config.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'package:maizedoctor/data/datasources/scan_datasource.dart';
import 'package:maizedoctor/data/models/scan_prediction.dart';
import 'package:maizedoctor/data/models/scan_record.dart';
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
  const liveInference = bool.fromEnvironment('RUN_LIVE_SCAN_INFERENCE');
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
        if (liveInference) {
          final scan = model.scan!;
          expect(scan.status, ScanStatus.completed);
          expect(scan.finishedAt, isNotNull);
          expect(scan.analysisErrorCode, isNull);
          final prediction = scan.prediction!;
          expect(prediction.modelVersion, 'mobilenet-v3-small-v2-20261009');
          expect(prediction.preprocessingVersion, '1.0.0');
          expect(prediction.predictedClass, isIn(ScanPrediction.classLabels));
          expect(prediction.confidence, inInclusiveRange(0, 1));
          expect(
            prediction.probabilities.keys,
            unorderedEquals(ScanPrediction.classLabels),
          );
          expect(
            prediction.probabilities.values.fold(
              0.0,
              (sum, value) => sum + value,
            ),
            closeTo(1, 1e-5),
          );
          expect(
            prediction.predictionStatus,
            ScanPredictionStatus.lowConfidence,
          );
          expect(
            prediction.uncertaintyReason,
            ScanUncertaintyReason.thresholdUnconfigured,
          );
          expect(prediction.confidenceThreshold, isNull);
          expect(prediction.inferenceDurationMs, inInclusiveRange(0, 20000));
          expect(prediction.inferredAt.isBefore(scan.createdAt), false);
          expect(prediction.inferredAt.isAfter(scan.finishedAt!), false);
        }
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
