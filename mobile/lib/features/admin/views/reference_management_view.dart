import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/app_field.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/repositories/reference_media_repository.dart';
import '../../../data/repositories/admin_management_repository.dart';
import '../../../data/repositories/private_image_repository.dart';
import '../../../data/models/admin_management.dart';
import '../../../data/models/reference_media.dart';
import '../../disease_knowledge/view_models/reference_gallery_view_model.dart';
import '../view_models/admin_management_view_model.dart';
import '../widgets/reference_editor.dart';
import '../widgets/management_editor_form.dart';
import '../widgets/admin_draft_guard.dart';
import '../widgets/admin_reference_card.dart';

class ReferenceManagementView extends StatelessWidget {
  const ReferenceManagementView({super.key});
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => ReferenceGalleryViewModel(
          context.read<AdminReferenceMediaRepository>(),
          'common-rust',
        )..load(),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            AdminManagementViewModel(context.read<AdminManagementRepository>())
              ..select(ManagementArea.diseases),
      ),
      Provider(
        create: (_) => PrivateImageRepository(
          context.read<AdminReferenceMediaRepository>().api,
        ),
      ),
    ],
    child: const _ReferenceManagementBody(),
  );
}

class _ReferenceManagementBody extends StatefulWidget {
  const _ReferenceManagementBody();
  @override
  State<_ReferenceManagementBody> createState() =>
      _ReferenceManagementBodyState();
}

class _ReferenceManagementBodyState extends State<_ReferenceManagementBody> {
  bool _editing = false;
  int _editorEpoch = 0, _page = 0, _selectionEpoch = 0;
  static const _pageSize = 4;
  Future<bool> _leave() async =>
      await context.read<AdminDraftGuard?>()?.leave(context) ?? true;
  Future<void> _edit(ReferenceMedia? media) async {
    if (!await _leave() || !mounted) return;
    context.read<ReferenceGalleryViewModel>().edit(media);
    setState(() {
      _editing = true;
      _editorEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReferenceGalleryViewModel>();
    final catalogue = context.watch<AdminManagementViewModel>();
    final choices = {
      for (final item in catalogue.items)
        if (item.values['slug'] case final String slug) slug: item,
    };
    final pages = (vm.items.length + _pageSize - 1) ~/ _pageSize;
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    return AppPage(
      storageKey: _editing
          ? 'admin-reference-editor-$_editorEpoch'
          : 'admin-reference-media',
      maxWidth: _editing ? AppSizing.formMaxWidth : AppSizing.contentMaxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Disease reference images',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Review provenance, hosting rights and attribution before publication. Uploading creates a draft; publication remains a separate action.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppField(
            label: 'Disease / catalogue context',
            child: DropdownButtonFormField<String>(
              key: ValueKey('reference-context-${vm.slug}-$_selectionEpoch'),
              initialValue: choices.containsKey(vm.slug) ? vm.slug : null,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Choose a catalogue entry',
              ),
              items: [
                for (final item in choices.entries)
                  DropdownMenuItem(
                    value: item.key,
                    child: Text(
                      item.value.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: vm.busy || catalogue.busy
                  ? null
                  : (value) async {
                      if (value == null || value == vm.slug) return;
                      if (!await _leave() || !context.mounted) {
                        if (mounted) setState(() => _selectionEpoch++);
                        return;
                      }
                      vm.edit(null);
                      vm.slug = value;
                      setState(() {
                        _editing = false;
                        _page = 0;
                      });
                      await vm.load();
                    },
            ),
          ),
          if (catalogue.busy)
            const AppLoadingState(
              message: 'Loading catalogue choices…',
              inline: true,
            ),
          if (catalogue.error case final error?)
            AppErrorState(error: error, onRetry: () => catalogue.load()),
          if (!catalogue.busy && catalogue.error == null && choices.isEmpty)
            const Text(
              'Catalogue choices are unavailable. Review the catalogue before uploading.',
            ),
          if (catalogue.nextCursor != null)
            TextButton(
              onPressed: catalogue.busy
                  ? null
                  : () => catalogue.load(more: true),
              child: const Text('Load more catalogue choices'),
            ),
          const SizedBox(height: AppSpacing.md),
          if (choices[vm.slug] case final current?)
            Text(
              '${current.title} · ${vm.slug} · ${current.status}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          if (vm.error case final error?) ...[
            AppErrorState(
              error: error,
              onRetry: () async {
                if (await _leave() && context.mounted) {
                  setState(() => _editing = false);
                  await vm.load();
                }
              },
            ),
            if (_editing)
              const Text(
                'Your input is retained. A timeout can have an ambiguous outcome: refresh and review stored media before repeating an upload.',
              ),
          ],
          if (vm.busy)
            const AppLoadingState(
              message: 'Updating reference media…',
              inline: true,
            ),
          if (_editing) ...[
            const SizedBox(height: AppSpacing.lg),
            ReferenceEditor(
              key: ValueKey(
                'reference-editor-${vm.editing?.id}-${vm.editing?.revision}-$_editorEpoch',
              ),
              media: vm.editing,
              image: vm.selected,
              busy: vm.busy,
              onChoose: vm.choose,
              onSave: (metadata) async {
                await vm.save(metadata);
                if (context.mounted && vm.error == null) {
                  setState(() => _editing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Reviewed metadata saved. Publication requires a separate review action.',
                      ),
                    ),
                  );
                }
              },
              onCancel: () {
                vm.edit(null);
                setState(() => _editing = false);
              },
            ),
          ] else ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: vm.busy || !choices.containsKey(vm.slug)
                      ? null
                      : () => _edit(null),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('New draft image'),
                ),
                OutlinedButton.icon(
                  onPressed: vm.busy ? null : vm.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load / refresh catalogue media'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!vm.busy && vm.error == null && vm.items.isEmpty)
              const AppEmptyState(
                title: 'No reference images',
                message:
                    'Upload a draft only when source and display rights are available. An empty gallery is not evidence of absent disease.',
                icon: Icons.photo_library_outlined,
              ),
            for (final media in vm.items.skip(page * _pageSize).take(_pageSize))
              AdminReferenceCard(
                media: media,
                busy: vm.busy,
                onEdit: () => _edit(media),
                onStatus: (status) async {
                  final confirmed = await confirmManagement(
                    context,
                    status == 'ACTIVE'
                        ? 'Publish rights-reviewed image?'
                        : status == 'DELETED'
                        ? 'Retire image and queue asset cleanup?'
                        : 'Hide reference image?',
                    'Confirm source, license, attribution and applicability. Publication does not validate a diagnosis; retirement preserves the audit and durable cleanup journal. Replacement uploads remain drafts until explicitly published.',
                  );
                  if (confirmed && context.mounted) {
                    await vm.status(
                      media,
                      status,
                      'Admin explicitly reviewed source, hosting/display rights and the requested lifecycle transition.',
                    );
                  }
                },
              ),
            if (pages > 1) ...[
              Text(
                'Media page ${page + 1} of $pages · ${vm.items.length} loaded images',
              ),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed: page > 0
                        ? () => setState(() => _page = page - 1)
                        : null,
                    child: const Text('Previous images'),
                  ),
                  OutlinedButton(
                    onPressed: page + 1 < pages
                        ? () => setState(() => _page = page + 1)
                        : null,
                    child: const Text('Next images'),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
