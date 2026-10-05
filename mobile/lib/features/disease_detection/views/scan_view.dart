import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/feature_intro.dart';

class ScanView extends StatelessWidget {
  const ScanView({super.key});
  @override
  Widget build(BuildContext context) => const FeatureIntro(
    title: 'Scan a maize leaf',
    subtitle: 'A simple starting point for understanding your crop.',
    icon: Icons.document_scanner_outlined,
    tone: AppColors.forest,
    tint: AppColors.sage,
    message:
        'Camera capture, image selection and disease analysis are not available yet. No diagnosis is produced here.',
  );
}
