import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/admin_management.dart';
import '../view_models/admin_management_view_model.dart';
import '../widgets/management_editor_form.dart';
import '../widgets/admin_content_management.dart';

class AdminManagementView extends StatelessWidget {
  const AdminManagementView({this.onAreaChanged, super.key});
  final ValueChanged<ManagementArea>? onAreaChanged;
  Future<void> _status(
    BuildContext context,
    AdminManagementViewModel model,
    ManagementEntry item,
    String status,
  ) async {
    final confirmed = await confirmManagement(
      context,
      status == 'ACTIVE'
          ? 'Activate reviewed version?'
          : 'Deactivate this version?',
      status == 'ACTIVE'
          ? 'This publishes the selected version and may retire the previous active version/configuration. Source review is required; the classifier model is unchanged.'
          : 'This removes the selected version from current use. Historical content, results and version references remain.',
    );
    if (context.mounted && confirmed) await model.status(item, status);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AdminManagementViewModel>();
    return AdminContentManagement(
      key: ValueKey(model.area),
      onAreaChanged: onAreaChanged,
      onStatus: (item, status) => _status(context, model, item, status),
    );
  }
}
