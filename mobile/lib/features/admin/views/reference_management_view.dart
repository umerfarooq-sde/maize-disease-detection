import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/repositories/reference_media_repository.dart';
import '../../disease_knowledge/view_models/reference_gallery_view_model.dart';
import '../widgets/reference_editor.dart';
import '../widgets/management_editor_form.dart';

class ReferenceManagementView extends StatelessWidget {
  const ReferenceManagementView({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => ReferenceGalleryViewModel(
      context.read<AdminReferenceMediaRepository>(),
      'common-rust',
    )..load(),
    child: const _ReferenceManagementBody(),
  );
}

class _ReferenceManagementBody extends StatelessWidget {
  const _ReferenceManagementBody();
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReferenceGalleryViewModel>();
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Disease reference images',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text(
            'Sources, licenses and review are mandatory for publication. No real reference photos are supplied by this phase.',
          ),
          TextFormField(
            initialValue: vm.slug,
            enabled: !vm.busy,
            decoration: const InputDecoration(labelText: 'Catalogue slug'),
            onFieldSubmitted: (value) {
              vm.slug = value.trim();
              vm.edit(null);
              vm.load();
            },
          ),
          TextButton(
            onPressed: vm.busy ? null : vm.load,
            child: const Text('Load / refresh catalogue media'),
          ),
          if (vm.error case final error?)
            AppErrorState(error: error, onRetry: vm.load),
          if (vm.busy)
            const AppLoadingState(message: 'Updating reference media…'),
          for (final media in vm.items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${media.altText} · ${media.status} · order ${media.order}',
                    ),
                    Text('${media.attribution} · ${media.license}'),
                    TextButton(
                      onPressed: vm.busy ? null : () => vm.edit(media),
                      child: const Text('Edit metadata / reorder / replace'),
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final status in ['ACTIVE', 'INACTIVE', 'DELETED'])
                          TextButton(
                            onPressed: vm.busy
                                ? null
                                : () async {
                                    final confirmed = await confirmManagement(
                                      context,
                                      status == 'ACTIVE'
                                          ? 'Publish rights-reviewed image?'
                                          : status == 'DELETED'
                                          ? 'Retire image and queue asset cleanup?'
                                          : 'Hide reference image?',
                                      'Confirm source, license, attribution and applicability. Publication does not validate a diagnosis; retirement preserves the audit and durable cleanup journal.',
                                    );
                                    if (confirmed) {
                                      await vm.status(
                                        media,
                                        status,
                                        'Admin explicitly reviewed source, hosting/display rights and the requested lifecycle transition.',
                                      );
                                    }
                                  },
                            child: Text(switch (status) {
                              'ACTIVE' => 'Publish',
                              'INACTIVE' => 'Hide',
                              _ => 'Retire and clean',
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (!vm.busy && vm.items.isEmpty)
            const Text(
              'No reference images. Upload a draft only when source and rights are available.',
            ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: vm.busy ? null : () => vm.edit(null),
            child: const Text('New draft image'),
          ),
          ReferenceEditor(
            key: ValueKey(vm.editing?.revision ?? 'new'),
            media: vm.editing,
            image: vm.selected,
            busy: vm.busy,
            onSave: vm.save,
            onChoose: vm.choose,
          ),
        ],
      ),
    );
  }
}
