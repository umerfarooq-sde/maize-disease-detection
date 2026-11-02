import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_field.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../data/models/farmer_profile.dart';

class ProfileEditorForm extends StatefulWidget {
  const ProfileEditorForm({
    required this.profile,
    required this.busy,
    required this.onSave,
    this.pendingPhoto = false,
    this.onDiscardPhoto,
    super.key,
  });
  final FarmerProfile? profile;
  final bool busy;
  final Future<void> Function(ProfileDraft) onSave;
  final bool pendingPhoto;
  final VoidCallback? onDiscardPhoto;
  @override
  State<ProfileEditorForm> createState() => _ProfileEditorFormState();
}

class _ProfileEditorFormState extends State<ProfileEditorForm> {
  bool _allowExit = false;
  bool _confirmingExit = false;
  bool get _dirty =>
      widget.pendingPhoto ||
      _name.text.trim() != (widget.profile?.displayName ?? '') ||
      _region.text.trim() != (widget.profile?.region ?? '') ||
      _country.text.trim().toUpperCase() !=
          (widget.profile?.countryCode ?? '') ||
      _area.text.trim() != (widget.profile?.fieldAreaHectares ?? '');
  Future<void> _confirmExit() async {
    if (_confirmingExit) return;
    _confirmingExit = true;
    final confirmed = await showAppConfirmation(
      context,
      title: 'Discard unsaved profile changes?',
      message:
          'Your edited details or selected photo have not been saved. Leave this form without saving them?',
      confirmLabel: 'Discard changes',
    );
    _confirmingExit = false;
    if (!mounted || !confirmed) return;
    widget.onDiscardPhoto?.call();
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  final _form = GlobalKey<FormState>();
  @override
  void didUpdateWidget(covariant ProfileEditorForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingPhoto && !oldWidget.pendingPhoto) _allowExit = false;
  }

  late final _name = TextEditingController(
    text: widget.profile?.displayName ?? '',
  );
  late final _region = TextEditingController(
    text: widget.profile?.region ?? '',
  );
  late final _country = TextEditingController(
    text: widget.profile?.countryCode ?? '',
  );
  late final _area = TextEditingController(
    text: widget.profile?.fieldAreaHectares ?? '',
  );
  @override
  void dispose() {
    for (final controller in [_name, _region, _country, _area]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!widget.busy && (_form.currentState?.validate() ?? false)) {
      await widget.onSave(
        ProfileDraft(_name.text, _region.text, _country.text, _area.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit || !_dirty || widget.busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !widget.busy) _confirmExit();
    },
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _form,
          onChanged: () {
            if (mounted) setState(() => _allowExit = false);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Personal details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppField(
                label: 'Display name',
                child: TextFormField(
                  key: const Key('profile-display-name'),
                  controller: _name,
                  enabled: !widget.busy,
                  decoration: const InputDecoration(errorMaxLines: 3),
                  validator: ProfileDraft.nameError,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppField(
                label: 'Region',
                optional: true,
                child: TextFormField(
                  key: const Key('profile-region'),
                  controller: _region,
                  enabled: !widget.busy,
                  decoration: const InputDecoration(errorMaxLines: 3),
                  validator: ProfileDraft.regionError,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppField(
                label: 'Country code',
                optional: true,
                child: TextFormField(
                  key: const Key('profile-country'),
                  controller: _country,
                  enabled: !widget.busy,
                  decoration: const InputDecoration(
                    helperText: 'Two letters, such as PK.',
                    errorMaxLines: 3,
                  ),
                  validator: ProfileDraft.countryError,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppField(
                label: 'Field area in hectares',
                optional: true,
                child: TextFormField(
                  key: const Key('profile-area'),
                  controller: _area,
                  enabled: !widget.busy,
                  decoration: const InputDecoration(
                    helperText:
                        'Area metadata only; this does not calculate a recommendation.',
                    helperMaxLines: 3,
                    errorMaxLines: 3,
                  ),
                  validator: ProfileDraft.areaError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onFieldSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                key: const Key('profile-save'),
                onPressed: widget.busy ? null : _save,
                child: Text(widget.busy ? 'Please wait…' : 'Save profile'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
