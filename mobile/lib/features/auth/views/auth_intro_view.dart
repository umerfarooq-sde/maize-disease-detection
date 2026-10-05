import 'package:flutter/material.dart';
import '../../../core/widgets/feature_intro.dart';

class AuthIntroView extends StatelessWidget {
  const AuthIntroView({super.key});
  @override
  Widget build(BuildContext context) => const FeatureIntro(
    title: 'Secure sign-in',
    subtitle: 'A future home for your farmer account.',
    icon: Icons.lock_outline,
    message:
        'Mobile sign-in and registration are not available yet. No credentials are collected on this screen.',
  );
}
