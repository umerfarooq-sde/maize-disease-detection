import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/farmer_profile.dart';

class ProfileEditorForm extends StatefulWidget {
  const ProfileEditorForm({
    required this.profile,
    required this.busy,
    required this.onSave,
    super.key,
  });
  final FarmerProfile? profile;
  final bool busy;
  final Future<void> Function(ProfileDraft) onSave;
  @override
  State<ProfileEditorForm> createState() => _ProfileEditorFormState();
}

class _ProfileEditorFormState extends State<ProfileEditorForm> {
  final _form = GlobalKey<FormState>();
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
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('profile-display-name'),
          controller: _name,
          enabled: !widget.busy,
          decoration: const InputDecoration(
            labelText: 'Display name',
            errorMaxLines: 3,
          ),
          validator: ProfileDraft.nameError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          key: const Key('profile-region'),
          controller: _region,
          enabled: !widget.busy,
          decoration: const InputDecoration(
            labelText: 'Region (optional)',
            errorMaxLines: 3,
          ),
          validator: ProfileDraft.regionError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          key: const Key('profile-country'),
          controller: _country,
          enabled: !widget.busy,
          decoration: const InputDecoration(
            labelText: 'Country code (optional)',
            helperText: 'Two letters, such as PK.',
            errorMaxLines: 3,
          ),
          validator: ProfileDraft.countryError,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          key: const Key('profile-area'),
          controller: _area,
          enabled: !widget.busy,
          decoration: const InputDecoration(
            labelText: 'Field area in hectares (optional)',
            helperText:
                'Area metadata only; this does not calculate a recommendation.',
            helperMaxLines: 3,
            errorMaxLines: 3,
          ),
          validator: ProfileDraft.areaError,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onFieldSubmitted: (_) => _save(),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          key: const Key('profile-save'),
          onPressed: widget.busy ? null : _save,
          child: Text(widget.busy ? 'Please wait…' : 'Save profile'),
        ),
      ],
    ),
  );
}
