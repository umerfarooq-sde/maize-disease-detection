import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/responsive.dart';

/// A bounded-width header with genuinely lazy, cursor-backed record children.
class AdminRecordPage extends StatelessWidget {
  const AdminRecordPage({
    required this.storageKey,
    required this.header,
    required this.count,
    required this.itemBuilder,
    required this.footer,
    super.key,
  });
  final String storageKey;
  final Widget header, footer;
  final int count;
  final IndexedWidgetBuilder itemBuilder;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final padding = Responsive.paddingForWidth(constraints.maxWidth);
        final horizontal =
            padding +
            ((constraints.maxWidth - padding * 2 - AppSizing.contentMaxWidth)
                    .clamp(0.0, double.infinity) /
                2);
        return CustomScrollView(
          key: PageStorageKey(storageKey),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                padding,
                horizontal,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(child: header),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              sliver: SliverList.builder(
                itemCount: count,
                itemBuilder: itemBuilder,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.md,
                horizontal,
                padding,
              ),
              sliver: SliverToBoxAdapter(child: footer),
            ),
          ],
        );
      },
    ),
  );
}
