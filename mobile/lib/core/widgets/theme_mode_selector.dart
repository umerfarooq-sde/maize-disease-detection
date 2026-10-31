import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_controller.dart';

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.contrast_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Follow your device or choose a theme for MAIZEDOCTOR.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final showIcons = constraints.maxWidth >= 420;
                return SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: showIcons
                          ? const Icon(Icons.brightness_auto_outlined)
                          : null,
                      label: const Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: showIcons
                          ? const Icon(Icons.light_mode_outlined)
                          : null,
                      label: const Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: showIcons
                          ? const Icon(Icons.dark_mode_outlined)
                          : null,
                      label: const Text('Dark'),
                    ),
                  ],
                  selected: {controller.mode},
                  onSelectionChanged: (selection) {
                    unawaited(controller.setMode(selection.single));
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
