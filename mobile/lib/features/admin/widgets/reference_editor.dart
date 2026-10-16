import 'package:flutter/material.dart';
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
    super.key,
  });
  final ReferenceMedia? media;
  final SelectedLeafImage? image;
  final bool busy;
  final Future<void> Function(Map<String, Object?>) onSave;
  final VoidCallback onChoose;
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
    if (!(_form.currentState?.validate() ?? false)) return;
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
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Draft reference image · publication requires a separate rights review. Never use training dataset images without verified redistribution rights.',
        ),
        if (widget.image case final image?)
          Image.memory(
            image.bytes,
            height: 200,
            semanticLabel: 'Selected draft image preview',
          ),
        OutlinedButton(
          onPressed: widget.busy ? null : widget.onChoose,
          child: Text(
            widget.media == null
                ? 'Choose draft image'
                : 'Choose replacement image (new draft)',
          ),
        ),
        for (final entry in fields.entries)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: TextFormField(
              key: ValueKey('reference-${entry.key}'),
              controller: controllers[entry.key],
              enabled: !widget.busy,
              maxLength: entry.value.$2,
              decoration: InputDecoration(labelText: entry.value.$1),
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
          ),
        CheckboxListTile(
          value: confirmed,
          onChanged: widget.busy
              ? null
              : (value) => setState(() => confirmed = value ?? false),
          title: const Text(
            'I have reviewed permission/license for project hosting and display. This is not automatic legal approval.',
          ),
        ),
        FilledButton(
          onPressed: widget.busy ? null : _save,
          child: const Text('Save reviewed draft metadata'),
        ),
      ],
    ),
  );
}
