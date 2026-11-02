import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

class ScanPhotoGuide extends StatelessWidget {
  const ScanPhotoGuide({super.key});
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'A good photo starts here',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Make the leaf easy to see. A photo supports a model prediction, not a certain diagnosis.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _GuideTip(
            icon: Icons.center_focus_strong,
            text: 'Keep one maize leaf clearly in focus.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _GuideTip(
            icon: Icons.wb_sunny_outlined,
            text: 'Use good light without harsh shadows.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _GuideTip(
            icon: Icons.visibility_outlined,
            text: 'Avoid hands or objects covering the leaf.',
          ),
        ],
      ),
    ),
  );
}

class _GuideTip extends StatelessWidget {
  const _GuideTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: AppSizing.icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(text)),
    ],
  );
}
