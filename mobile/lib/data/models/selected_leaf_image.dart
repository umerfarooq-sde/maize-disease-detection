import 'dart:typed_data';

class SelectedLeafImage {
  const SelectedLeafImage({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
  });
  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  String get filename => switch (mimeType) {
    'image/jpeg' => 'leaf.jpg',
    'image/png' => 'leaf.png',
    _ => 'leaf.webp',
  };
}
