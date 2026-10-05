import 'package:flutter/material.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(
    child: AppEmptyState(
      title: 'Your scan history starts here',
      icon: Icons.history,
      message:
          'Scan history will become available with secure sign-in and leaf scanning. No scans have been loaded.',
    ),
  );
}
