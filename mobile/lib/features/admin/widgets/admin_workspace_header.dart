import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/brand_mark.dart';

class AdminWorkspaceHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const AdminWorkspaceHeader({
    required this.title,
    required this.textScale,
    required this.onBack,
    required this.onFarmer,
    this.onMenu,
    this.onSignOut,
    this.email,
    this.dense = false,
    super.key,
  });
  final String title;
  final String? email;
  final double textScale;
  final bool dense;
  final VoidCallback onBack, onFarmer;
  final VoidCallback? onMenu, onSignOut;
  @override
  Size get preferredSize => Size.fromHeight(
    dense
        ? kToolbarHeight + AppSpacing.md * textScale
        : (textScale > AppSizing.comfortableTextScale
                      ? AppSizing.navigationHeight
                      : kToolbarHeight) *
                  textScale +
              AppSpacing.lg,
  );
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: preferredSize.height,
    leading: IconButton(
      onPressed: onMenu ?? onBack,
      tooltip: onMenu == null
          ? 'Back from Admin workspace'
          : 'Open Admin navigation',
      icon: Icon(onMenu == null ? Icons.arrow_back : Icons.menu),
    ),
    title: Row(
      children: [
        if (MediaQuery.sizeOf(context).width >= AppSizing.twoColumnBreakpoint &&
            textScale < AppSizing.comfortableTextScale) ...[
          const BrandMark(size: AppSizing.stateIcon),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!dense)
                Text(
                  'MAIZEDOCTOR · ADMIN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              Text(
                title,
                maxLines: dense ? 1 : 3,
                overflow: dense ? TextOverflow.ellipsis : TextOverflow.visible,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      PopupMenuButton<String>(
        tooltip: 'Workspace actions',
        onSelected: (value) =>
            value == 'farmer' ? onFarmer() : onSignOut?.call(),
        itemBuilder: (_) => [
          if (email != null)
            PopupMenuItem(
              enabled: false,
              child: Text('Signed in as Admin\n$email'),
            ),
          const PopupMenuItem(
            value: 'farmer',
            child: Text('Return to Farmer App'),
          ),
          if (onSignOut != null)
            const PopupMenuItem(
              value: 'sign-out',
              child: Text('Admin Sign Out'),
            ),
        ],
      ),
    ],
  );
}
