import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import 'admin_navigation.dart';
import 'admin_draft_guard.dart';
import 'admin_workspace_header.dart';

/// Only presentation and navigation live here; the access view owns gating.
class AdminWorkspaceShell extends StatefulWidget {
  const AdminWorkspaceShell({
    required this.child,
    required this.destination,
    required this.signedIn,
    required this.onSignOut,
    this.email,
    super.key,
  });
  final Widget child;
  final AdminDestination destination;
  final bool signedIn;
  final String? email;
  final VoidCallback? onSignOut;
  @override
  State<AdminWorkspaceShell> createState() => _AdminWorkspaceShellState();
}

class _AdminWorkspaceShellState extends State<AdminWorkspaceShell> {
  static const _sidebarWidth = 264.0;
  final _scaffold = GlobalKey<ScaffoldState>();
  Future<bool> _leave() async =>
      await context.read<AdminDraftGuard?>()?.leave(context) ?? true;
  Future<void> _farmer() async {
    if (await _leave() && mounted) context.go(AppRoutes.home);
  }

  Future<void> _signOut() async {
    if (await _leave() && mounted) widget.onSignOut?.call();
  }

  Future<void> _back() async {
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      _scaffold.currentState?.closeDrawer();
      return;
    }
    if (!await _leave() || !mounted) return;
    // The protected child Navigator is deliberately unmounted when signed out.
    // Handle this surface at the parent instead of asking GoRouter to walk it.
    if (!widget.signedIn) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        context.go(
          widget.destination == AdminDestination.overview
              ? AppRoutes.home
              : AppRoutes.admin,
        );
      }
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        widget.destination == AdminDestination.overview
            ? AppRoutes.home
            : AppRoutes.admin,
      );
    }
  }

  Future<void> _select(AdminDestination destination) async {
    _scaffold.currentState?.closeDrawer();
    if (widget.destination != destination && await _leave() && mounted) {
      context.go(destination.location);
    }
  }

  @override
  Widget build(BuildContext context) => BackButtonListener(
    onBackButtonPressed: () async {
      if (widget.signedIn) return false;
      await _back();
      return true;
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        final expanded =
            widget.signedIn &&
            constraints.maxWidth >= AppSizing.tabletBreakpoint;
        Widget navigation() => AdminNavigation(
          selected: widget.destination,
          email: widget.email,
          onSelect: _select,
          onFarmer: _farmer,
          onSignOut: widget.onSignOut == null ? null : _signOut,
        );
        return PopScope(
          canPop:
              context.canPop() &&
              !(context.watch<AdminDraftGuard?>()?.blocked ?? false),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Scaffold(
            key: _scaffold,
            appBar: AdminWorkspaceHeader(
              title: widget.signedIn
                  ? widget.destination.label
                  : 'Admin workspace',
              email: widget.signedIn ? widget.email : null,
              textScale: MediaQuery.textScalerOf(context).scale(1),
              dense:
                  MediaQuery.viewInsetsOf(context).bottom > 0 &&
                  constraints.maxHeight -
                          MediaQuery.viewInsetsOf(context).bottom <
                      AppSizing.navigationHeight * 4,
              onBack: _back,
              onFarmer: _farmer,
              onMenu: widget.signedIn && !expanded
                  ? () => _scaffold.currentState?.openDrawer()
                  : null,
              onSignOut: widget.signedIn && widget.onSignOut != null
                  ? _signOut
                  : null,
            ),
            drawer: widget.signedIn && !expanded
                ? Drawer(child: navigation())
                : null,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (expanded) ...[
                  SizedBox(
                    width: _sidebarWidth,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: navigation(),
                    ),
                  ),
                  VerticalDivider(
                    width: AppSizing.divider,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ],
                // Keep the nested route's BlockSemantics inside its content pane;
                // otherwise its active ModalRoute hides the sibling sidebar.
                Expanded(
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
