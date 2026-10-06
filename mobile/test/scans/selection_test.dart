import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maizedoctor/core/constants/app_constants.dart';
import 'package:maizedoctor/core/exceptions/app_exception.dart';
import 'package:maizedoctor/data/datasources/leaf_image_datasource.dart';
import 'helpers.dart';

class FakePicker extends ImagePicker {
  XFile? file;
  PlatformException? failure;
  ImageSource? source;
  bool? fullMetadata;
  @override
  bool supportsImageSource(ImageSource source) => true;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    fullMetadata = requestFullMetadata;
    if (failure case final error?) throw error;
    return file;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'picker routes gallery/camera, respects cancellation and sanitizes permission failures',
    () async {
      final picker = FakePicker()
        ..file = XFile.fromData(leafImage.bytes, path: 'leaf.png');
      final source = PickerLeafImageDatasource(picker: picker);
      expect(
        (await source.pick(LeafImageSource.gallery))?.mimeType,
        'image/png',
      );
      expect(picker.source, ImageSource.gallery);
      expect(picker.fullMetadata, false);
      expect(
        (await source.pick(LeafImageSource.camera))?.mimeType,
        'image/png',
      );
      expect(picker.source, ImageSource.camera);
      picker.file = null;
      expect(await source.pick(LeafImageSource.gallery), isNull);
      picker.failure = PlatformException(
        code: 'camera_access_denied',
        message: 'private native details',
      );
      await expectLater(
        source.pick(LeafImageSource.camera),
        throwsA(
          isA<AppException>()
              .having((e) => e.kind, 'kind', AppErrorKind.imageAccess)
              .having(
                (e) => e.message.contains('private'),
                'private details',
                false,
              ),
        ),
      );
    },
  );
  test(
    'client validates original image bytes and dimensions for preview',
    () async {
      final image = await validatePickedImage(
        XFile.fromData(leafImage.bytes, name: 'leaf.png', path: 'leaf.png'),
      );
      expect(image.mimeType, 'image/png');
      expect(image.width, 24);
      expect(image.height, 24);
      expect(image.bytes, leafImage.bytes);
    },
  );
  test(
    'client rejects oversized, empty, disguised and malformed files before upload',
    () async {
      for (final file in [
        XFile.fromData(
          Uint8List(AppConstants.maxImageBytes + 1),
          name: 'leaf.png',
          path: 'leaf.png',
        ),
        XFile.fromData(Uint8List(0), name: 'leaf.png', path: 'leaf.png'),
        XFile.fromData(leafImage.bytes, name: 'leaf.exe', path: 'leaf.exe'),
        XFile.fromData(
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
          name: 'leaf.png',
          path: 'leaf.png',
        ),
        XFile.fromData(
          Uint8List.fromList('<svg></svg>'.codeUnits),
          name: 'leaf.png',
          path: 'leaf.png',
        ),
      ]) {
        await expectLater(
          validatePickedImage(file),
          throwsA(isA<AppException>()),
        );
      }
    },
  );
}
