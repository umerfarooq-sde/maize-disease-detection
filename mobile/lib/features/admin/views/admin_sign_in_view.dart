import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/auth_header.dart';
import '../../../core/widgets/app_field.dart';
import '../view_models/admin_session_view_model.dart';

class AdminSignInView extends StatefulWidget {
  const AdminSignInView({super.key});
  @override
  State<AdminSignInView> createState() => _AdminSignInViewState();
}

class _AdminSignInViewState extends State<AdminSignInView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  Future<void> _submit() async {
    final session = context.read<AdminSessionViewModel>();
    if (session.busy || !(_form.currentState?.validate() ?? false)) return;
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
      maxWidth: AppSizing.authenticationMaxWidth,
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeader(
                title: 'Admin sign-in',
                description:
                    'Use your provisioned Admin account. Separate from Farmer sign-in; access lasts for this app session.',
                admin: true,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppField(
                label: 'Admin email',
                child: TextFormField(
                  key: const Key('admin-email'),
                  controller: _email,
                  enabled: !session.busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (value) =>
                      value != null &&
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(value.trim())
                      ? null
                      : 'Enter your Admin email address.',
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.alternate_email),
                    hintText: 'Admin account email',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppField(
                label: 'Password',
                child: TextFormField(
                  key: const Key('admin-password'),
                  controller: _password,
                  enabled: !session.busy,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  validator: (value) => value != null && value.isNotEmpty
                      ? null
                      : 'Enter your password.',
                  onFieldSubmitted: (_) {
                    if (!session.busy) _submit();
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: session.busy
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (session.error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    session.error!.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
        ),
      ),
    );
  }
}
