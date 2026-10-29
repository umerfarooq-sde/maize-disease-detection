import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../data/models/registration_credentials.dart';
import '../view_models/registration_view_model.dart';

class RegistrationView extends StatefulWidget {
  const RegistrationView({super.key});
  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final model = context.read<RegistrationViewModel>();
    if (model.busy || !(_form.currentState?.validate() ?? false)) return;
    await model.register(_email.text, _password.text);
    if (mounted && model.registeredEmail != null) _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<RegistrationViewModel>();
    return AppPage(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizing.twoColumnBreakpoint,
          ),
          child: model.registeredEmail != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: AppSizing.emblem,
                      color: AppColors.forest,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Your farmer account is ready',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Sign in with your new account to save future scans. Guest scans stay anonymous.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      key: const Key('registration-sign-in'),
                      onPressed: () => context.go(AppRoutes.auth),
                      child: const Text('Continue to sign in'),
                    ),
                  ],
                )
              : AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Grow your field record',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Create a farmer account to keep future scans and explore your personal field insights.',
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        TextFormField(
                          key: const Key('registration-email'),
                          controller: _email,
                          enabled: !model.busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.newUsername],
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: RegistrationCredentials.emailError,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          key: const Key('registration-password'),
                          controller: _password,
                          enabled: !model.busy,
                          obscureText: _obscure,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText:
                                'Password must be at least 6 characters.',
                            helperMaxLines: 3,
                            errorMaxLines: 3,
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: model.busy
                                  ? null
                                  : () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: RegistrationCredentials.passwordError,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (model.errorMessage != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              model.errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        FilledButton(
                          key: const Key('register-submit'),
                          onPressed: model.busy ? null : _submit,
                          child: Text(
                            model.busy
                                ? 'Creating account…'
                                : model.error == null
                                ? 'Create farmer account'
                                : 'Try creating account again',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextButton(
                          onPressed: model.busy
                              ? null
                              : () => context.go(AppRoutes.auth),
                          child: const Text('Already have an account? Sign in'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Sign-in lasts for this app session. You can also scan without an account.',
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
