import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/feature_intro.dart';

class FertilizerView extends StatelessWidget {
  const FertilizerView({super.key});
  @override
  Widget build(BuildContext context) => const FeatureIntro(
    title: 'Fertilizer planning',
    subtitle: 'Clear inputs. Reliable quantities.',
    icon: Icons.grass_outlined,
    tone: AppColors.amber,
    tint: AppColors.wheat,
    message:
        'This calculator is being prepared. No fertilizer quantities or recommendations are calculated here.',
  );
}
