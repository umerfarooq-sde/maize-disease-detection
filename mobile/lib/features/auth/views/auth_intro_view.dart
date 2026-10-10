import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/exceptions/app_exception.dart';
import '../view_models/farmer_session_view_model.dart';

class AuthIntroView extends StatefulWidget {
  const AuthIntroView({super.key});
  @override
  State<AuthIntroView> createState() => _AuthIntroViewState();
}

class _AuthIntroViewState extends State<AuthIntroView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final model = context.read<FarmerSessionViewModel>();
    await model.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (model.signedIn) {
      _password.clear();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.profile);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FarmerSessionViewModel>();
    return AppPage(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your farmer scans, together',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Sign in with your farmer account to save new scans to your personal history.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('Sign-in lasts for this app session.'),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _email,
              enabled: !model.busy,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value != null &&
                      RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value.trim())
                  ? null
                  : 'Enter your email address.',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _password,
              enabled: !model.busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Password'),
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!model.busy) _submit();
              },
              validator: (value) => value != null && value.isNotEmpty
                  ? null
                  : 'Enter your password.',
            ),
            const SizedBox(height: AppSpacing.xl),
            if (model.error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  model.error!.kind == AppErrorKind.authentication
                      ? 'We could not sign you in. Check your email and password.'
                      : model.error!.message,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            FilledButton(
              onPressed: model.busy ? null : _submit,
              child: Text(model.busy ? 'Signing in…' : 'Sign in'),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: model.busy ? null : () => context.go(AppRoutes.scan),
              child: const Text('Continue scanning as a guest'),
            ),
          ],
        ),
      ),
    );
  }
}
