import 'package:flutter/material.dart';
import '../../../core/widgets/feature_intro.dart';

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});
  @override
  Widget build(BuildContext context) => const FeatureIntro(
    title: 'Field insights',
    subtitle: 'Your activity, made easier to understand.',
    icon: Icons.insights_outlined,
    message:
        'Insights will be available when real field activity is recorded. No charts, counts or trends are simulated.',
  );
}
