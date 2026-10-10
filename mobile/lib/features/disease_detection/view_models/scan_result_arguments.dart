import '../../../data/models/scan_record.dart';
import '../../../data/models/selected_leaf_image.dart';

/// Local navigation data only. The retry/capability key never enters a URL.
class ScanResultArguments {
  const ScanResultArguments({
    required this.scan,
    this.selectedImage,
    this.requestKey,
  });
  final ScanRecord scan;
  final SelectedLeafImage? selectedImage;
  final String? requestKey;

  @override
  String toString() => 'ScanResultArguments(${scan.id})';
}
