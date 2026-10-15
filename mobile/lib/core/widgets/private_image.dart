import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/private_image_repository.dart';
import '../../features/auth/view_models/farmer_session_view_model.dart';
import '../constants/app_constants.dart';
import 'private_image_view_model.dart';

/// In-memory owner/capability-bound image state, scoped to this rendered image.
class PrivateImage extends StatelessWidget {
  const PrivateImage({
    required this.path,
    required this.semanticLabel,
    this.anonymousKey,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    super.key,
  });
  final String path, semanticLabel;
  final String? anonymousKey;
  final double? width, height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final repository = context.read<PrivateImageRepository?>();
    final revision = context.watch<FarmerSessionViewModel?>()?.revision;
    if (repository == null) {
      return SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(Object.hash(path, anonymousKey, revision)),
      create: (_) =>
          PrivateImageViewModel(repository, path, anonymousKey)..load(),
      child: Consumer<PrivateImageViewModel>(
        builder: (context, model, _) {
          Widget retry() => Center(
            child: IconButton(
              onPressed: model.load,
              tooltip: 'Retry photo',
              icon: const Icon(Icons.broken_image_outlined),
            ),
          );
          return SizedBox(
            width: width,
            height: height,
            child: model.loading
                ? const Center(child: CircularProgressIndicator())
                : model.bytes == null
                ? retry()
                : Image.memory(
                    model.bytes!,
                    fit: fit,
                    cacheWidth: AppConstants.previewPixels,
                    semanticLabel: semanticLabel,
                    errorBuilder: (_, _, _) => retry(),
                  ),
          );
        },
      ),
    );
  }
}
