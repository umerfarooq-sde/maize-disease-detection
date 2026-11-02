import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_field.dart';
import 'admin_draft_guard.dart';
import 'admin_editor_section.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/models/reference_media.dart';
import '../../../data/models/selected_leaf_image.dart';

class ReferenceEditor extends StatefulWidget {
  const ReferenceEditor({
    required this.media,
    required this.image,
    required this.busy,
    required this.onSave,
    required this.onChoose,
    this.onCancel,
    super.key,
  });
  final ReferenceMedia? media;
  final SelectedLeafImage? image;
  final bool busy;
  final Future<void> Function(Map<String, Object?>) onSave;
  final VoidCallback onChoose;
  final VoidCallback? onCancel;
  @override
  State<ReferenceEditor> createState() => _ReferenceEditorState();
}

class _ReferenceEditorState extends State<ReferenceEditor> {
  final _form = GlobalKey<FormState>();
  static const fields = {
    'altText': ('Accessible image description', 255),
    'sortOrder': ('Display order (0–10000)', 5),
    'title': ('Source title', 255),
    'url': ('HTTPS source identity', 2048),
    'publisher': ('Source publisher', 255),
    'rights': ('Source rights statement', 1000),
    'license': ('License / permission reference', 1000),
    'contributor': ('Contributor / credit', 255),
    'attribution': ('Required attribution', 1000),
    'retrievedAt': ('Source reviewed date (YYYY-MM-DD)', 10),
  };
  late final Map<String, TextEditingController> controllers = {
    for (final key in fields.keys)
      key: TextEditingController(text: _initial(key)),
  };
  bool confirmed = false;
  bool _showErrors = false;
  AdminDraftGuard? _guard;
  bool get _dirty =>
      confirmed ||
      widget.image != null ||
      fields.keys.any((key) => controllers[key]!.text != _initial(key));
  @override
  void initState() {
    super.initState();
    for (final controller in controllers.values) {
      controller.addListener(() => _guard?.changed());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final guard = context.read<AdminDraftGuard?>();
    if (_guard != guard) {
      _guard?.unbind(this);
      _guard = guard;
      guard?.bind(this, () => _dirty, () => widget.busy);
    }
  }

  @override
  void didUpdateWidget(covariant ReferenceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image || oldWidget.busy != widget.busy) {
      _guard?.changed();
    }
  }

  String _initial(String key) {
    final m = widget.media;
    if (m == null) return key == 'sortOrder' ? '0' : '';
    return switch (key) {
      'altText' => m.altText,
      'sortOrder' => '${m.order}',
      'title' => m.source.title,
      'url' => m.source.url.toString(),
      'publisher' => m.source.publisher,
      'rights' => m.source.rights,
      'license' => m.license,
      'contributor' => m.credit,
      'attribution' => m.attribution,
      'retrievedAt' => m.source.retrievedAt.toIso8601String().split('T').first,
      _ => '',
    };
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      setState(() => _showErrors = true);
      return;
    }
    String v(String key) => controllers[key]!.text.trim();
    await widget.onSave({
      'altText': v('altText'),
      'sortOrder': int.parse(v('sortOrder')),
      'provenance': {
        'source': {
          for (final key in [
            'title',
            'url',
            'publisher',
            'rights',
            'retrievedAt',
          ])
            key: v(key),
          'authors': widget.media?.source.authors ?? <String>[],
          'publishedAt': widget.media?.source.publishedAt
              ?.toIso8601String()
              .split('T')
              .first,
        },
        'license': v('license'),
        'contributor': v('contributor'),
        'attribution': v('attribution'),
        'rightsConfirmed': confirmed,
        'contentKind': widget.media?.synthetic == true
            ? 'SYNTHETIC_TEST'
            : 'REFERENCE',
      },
    });
  }

  @override
  void dispose() {
    _guard?.unbind(this);
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(MapEntry<String, (String, int)> entry) => AppField(
    label: entry.value.$1,
    child: TextFormField(
      key: ValueKey('reference-${entry.key}'),
      controller: controllers[entry.key],
      enabled: !widget.busy,
      maxLength: entry.value.$2,
      decoration: const InputDecoration(),
      keyboardType: entry.key == 'sortOrder'
          ? TextInputType.number
          : entry.key == 'url'
          ? TextInputType.url
          : TextInputType.multiline,
      minLines: ['rights', 'license', 'attribution'].contains(entry.key)
          ? 2
          : 1,
      maxLines: ['rights', 'license', 'attribution'].contains(entry.key)
          ? 4
          : 2,
      validator: (raw) {
        final value = (raw ?? '').trim();
        if (value.isEmpty) {
          return 'Required source or image information.';
        }
        if (entry.key == 'sortOrder' &&
            (int.tryParse(value) == null ||
                int.parse(value) < 0 ||
                int.parse(value) > 10000)) {
          return 'Enter an integer from 0 to 10000.';
        }
        if (entry.key == 'url' &&
            (Uri.tryParse(value)?.scheme != 'https' ||
                Uri.tryParse(value)?.host.isEmpty != false)) {
          return 'Use an HTTPS source reference.';
        }
        if (entry.key == 'retrievedAt' &&
            (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
                DateTime.tryParse(value) == null)) {
          return 'Use YYYY-MM-DD.';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showErrors)
          Semantics(
            liveRegion: true,
            child: const Text(
              'Review the highlighted source and image fields before saving.',
            ),
          ),
        const Text(
          'Draft reference image · publication requires a separate rights review. Never use training dataset images without verified redistribution rights.',
        ),
        if (widget.image case final image?)
          Image.memory(
            image.bytes,
            height: 200,
            semanticLabel: 'Selected draft image preview',
            fit: BoxFit.contain,
            cacheWidth: 1024,
          ),
        OutlinedButton(
          onPressed: widget.busy ? null : widget.onChoose,
          child: Text(
            widget.media == null
                ? 'Choose draft image'
                : 'Choose replacement image (new draft)',
          ),
        ),
        for (final group in {
          'Image identity': ['altText', 'sortOrder'],
          'Source details': ['title', 'publisher', 'url', 'retrievedAt'],
          'Usage rights': ['rights', 'license', 'contributor', 'attribution'],
        }.entries)
          AdminEditorSection(
            title: group.key,
            description: group.key == 'Usage rights'
                ? 'Verify permission for project hosting and display. A source URL alone is not a license.'
                : 'Retain exact source identity and accessible image context.',
            children: [
              for (final key in group.value)
                _field(MapEntry(key, fields[key]!)),
            ],
          ),
        CheckboxListTile(
          value: confirmed,
          onChanged: widget.busy
              ? null
              : (value) {
                  setState(() => confirmed = value ?? false);
                  _guard?.changed();
                },
          title: const Text(
            'I have reviewed permission/license for project hosting and display. This is not automatic legal approval.',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: widget.busy ? null : _save,
          child: Text(
            widget.busy ? 'Working…' : 'Save reviewed draft metadata',
          ),
        ),
        if (widget.onCancel != null)
          TextButton(
            onPressed: widget.busy
                ? null
                : () async {
                    if (!_dirty || await confirmDiscardDraft(context)) {
                      if (mounted) widget.onCancel?.call();
                    }
                  },
            child: const Text('Cancel editing'),
          ),
      ],
    ),
  );
}
