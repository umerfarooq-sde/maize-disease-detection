import '../../../data/models/scan_record.dart';

String diseaseLabel(String literal) => switch (literal) {
  'Common_Rust' => 'Common Rust',
  'Gray_Leaf_Spot' => 'Gray Leaf Spot',
  'Healthy' => 'Healthy',
  'Northern_Corn_Leaf_Blight' => 'Northern Corn Leaf Blight',
  _ => 'Unknown label',
};

String scanStatusLabel(ScanStatus status) => switch (status) {
  ScanStatus.pending => 'Waiting for analysis',
  ScanStatus.processing => 'Analyzing',
  ScanStatus.completed => 'Analysis complete',
  ScanStatus.failed => 'Analysis failed',
};

String modelScore(double score) => '${(score * 100).toStringAsFixed(1)}%';

String scanDate(DateTime value) {
  final local = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String scanFailureMessage(String? code) => switch (code) {
  'INFERENCE_TIMEOUT' =>
    'Analysis took too long. Your photo is saved; try again.',
  'INVALID_IMAGE' =>
    'This photo could not be analyzed. Choose another clear leaf photo.',
  'INFERENCE_UNAVAILABLE' =>
    'Analysis is temporarily unavailable. Your photo is saved; try again later.',
  'INFERENCE_INTERRUPTED' =>
    'Analysis was interrupted. Your photo is saved; try again.',
  'INFERENCE_PERSISTENCE_FAILED' =>
    'The result could not be saved. Your photo is safe; try again.',
  _ => 'Analysis could not be completed. Your photo is saved; try again.',
};
