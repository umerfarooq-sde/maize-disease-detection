import 'package:flutter/material.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';

/// Ephemeral editor state only. No draft content or credentials are stored here.
class AdminDraftGuard extends ChangeNotifier {
  Object? _owner;
  bool Function()? _dirty, _busy;
  bool _asking = false, _disposed = false, _scheduled = false;
  bool get dirty => _dirty?.call() ?? false;
  bool get blocked => dirty || (_busy?.call() ?? false);
  void bind(Object owner, bool Function() dirty, bool Function() busy) {
    _owner = owner;
    _dirty = dirty;
    _busy = busy;
    changed();
  }

  void unbind(Object owner) {
    if (_owner != owner) return;
    _owner = null;
    _dirty = _busy = null;
    changed();
  }

  void changed() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  Future<bool> leave(BuildContext context) async {
    if (_asking) return false;
    if (_busy?.call() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for the current operation to finish.'),
        ),
      );
      return false;
    }
    if (!dirty) return true;
    _asking = true;
    final owner = _owner;
    try {
      final result = await confirmDiscardDraft(context);
      return !_disposed && owner == _owner && result;
    } finally {
      _asking = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    _dirty = _busy = null;
    super.dispose();
  }
}

Future<bool> confirmDiscardDraft(BuildContext context) => showAppConfirmation(
  context,
  title: 'Leave unsaved changes?',
  message:
      'Your unsaved edits will be discarded. Cancel to keep editing this draft.',
  destructive: true,
);
