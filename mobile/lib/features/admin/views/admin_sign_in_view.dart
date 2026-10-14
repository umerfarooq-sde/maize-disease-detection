import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../view_models/admin_session_view_model.dart';

class AdminSignInView extends StatefulWidget {
  const AdminSignInView({super.key});
  @override
  State<AdminSignInView> createState() => _AdminSignInViewState();
}

class _AdminSignInViewState extends State<AdminSignInView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  Future<void> _submit() async {
    final session = context.read<AdminSessionViewModel>();
    await session.signIn(_email.text, _password.text);
    if (mounted) _password.clear();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSessionViewModel>();
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Administrator sign-in',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Use your operator-provisioned Admin account. Access is separate from farmer sign-in and lasts for this app session.',
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            key: const Key('admin-email'),
            controller: _email,
            enabled: !session.busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Admin email'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('admin-password'),
            controller: _password,
            enabled: !session.busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!session.busy) _submit();
            },
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (session.error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                session.error!.message,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: session.busy ? null : _submit,
            child: Text(session.busy ? 'Signing in…' : 'Sign in as Admin'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Public registration cannot create Admin accounts.'),
        ],
      ),
    );
  }
}
