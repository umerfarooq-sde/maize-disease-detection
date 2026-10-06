import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exception.dart';
import '../models/selected_leaf_image.dart';

enum LeafImageSource { gallery, camera }

abstract interface class LeafImageDatasource {
  bool get cameraSupported;
  Future<SelectedLeafImage?> pick(LeafImageSource source);
  Future<SelectedLeafImage?> recover();
}

class PickerLeafImageDatasource implements LeafImageDatasource {
  PickerLeafImageDatasource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  @override
  bool get cameraSupported => _picker.supportsImageSource(ImageSource.camera);
  @override
  Future<SelectedLeafImage?> pick(LeafImageSource source) async {
    try {
      if (source == LeafImageSource.camera && !cameraSupported) {
        throw const AppException(AppErrorKind.imageAccess);
      }
      final file = await _picker.pickImage(
        source: source == LeafImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        requestFullMetadata: false,
      );
      return file == null ? null : await validatePickedImage(file);
    } on AppException {
      rethrow;
    } on PlatformException {
      throw const AppException(AppErrorKind.imageAccess);
    } catch (_) {
      throw const AppException(AppErrorKind.imageAccess);
    }
  }

  @override
  Future<SelectedLeafImage?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final response = await _picker.retrieveLostData();
      if (response.exception != null) {
        throw const AppException(AppErrorKind.imageAccess);
      }
      final files = response.files;
      return files == null || files.isEmpty
          ? null
          : await validatePickedImage(files.first);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(AppErrorKind.imageAccess);
    }
  }
}

Future<SelectedLeafImage> validatePickedImage(XFile file) async {
  final length = await file.length();
  if (length > AppConstants.maxImageBytes) {
    throw const AppException(AppErrorKind.imageTooLarge);
  }
  if (length == 0) throw const AppException(AppErrorKind.invalidImage);
  // Bounded stream even if a platform reports an inaccurate length.
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (builder.length + chunk.length > AppConstants.maxImageBytes) {
      throw const AppException(AppErrorKind.imageTooLarge);
    }
    builder.add(chunk);
  }
  final bytes = builder.takeBytes();
  bool starts(List<int> signature) =>
      bytes.length >= signature.length &&
      listEquals(bytes.sublist(0, signature.length), signature);
  final mime = starts([255, 216, 255])
      ? 'image/jpeg'
      : starts([137, 80, 78, 71, 13, 10, 26, 10])
      ? 'image/png'
      : bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP'
      ? 'image/webp'
      : null;
  final extension = file.name.split('.').last.toLowerCase();
  final allowed = {
    'image/jpeg': ['jpg', 'jpeg'],
    'image/png': ['png'],
    'image/webp': ['webp'],
  };
  if (mime == null || !(allowed[mime]?.contains(extension) ?? false)) {
    throw const AppException(AppErrorKind.invalidImage);
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width <= 0 ||
        descriptor.height <= 0 ||
        descriptor.width * descriptor.height > AppConstants.maxImagePixels) {
      throw const AppException(AppErrorKind.imageTooLarge);
    }
    codec = await descriptor.instantiateCodec(
      targetWidth: descriptor.width > AppConstants.previewPixels
          ? AppConstants.previewPixels
          : descriptor.width,
    );
    if (codec.frameCount != 1) {
      throw const AppException(AppErrorKind.invalidImage);
    }
    final frame = await codec.getNextFrame();
    frame.image.dispose();
    return SelectedLeafImage(
      bytes: bytes,
      mimeType: mime,
      width: descriptor.width,
      height: descriptor.height,
    );
  } on AppException {
    rethrow;
  } catch (_) {
    throw const AppException(AppErrorKind.invalidImage);
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
