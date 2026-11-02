import 'package:flutter/material.dart';
import '../widgets/admin_report_page.dart';
import '../widgets/ai_operations_panel.dart';

class AiOperationsView extends StatelessWidget {
  const AiOperationsView({super.key});
  @override
  Widget build(BuildContext context) => AdminReportPage(
    title: 'AI Operations',
    description:
        'Recorded operation attempts and outcomes across Node, the AI service and providers. Several events can belong to one Farmer action.',
    storageKey: 'admin-ai-operations',
    builder: (_, model) => AiOperationsPanel(data: model.data!.operations),
  );
}
