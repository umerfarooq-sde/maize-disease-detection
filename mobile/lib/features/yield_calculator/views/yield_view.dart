import 'package:flutter/material.dart';
import '../../../core/widgets/feature_intro.dart';

class YieldView extends StatelessWidget {
  const YieldView({super.key});
  @override
  Widget build(BuildContext context) => const FeatureIntro(
    title: 'Yield planning',
    subtitle: 'A clearer picture of your field.',
    icon: Icons.bar_chart_outlined,
    message:
        'Yield estimation is being prepared. No forecasts or yield quantities are generated here.',
  );
}
