import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/demo_credentials.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brand_mark.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: kDemoEmail);
  final _password = TextEditingController(text: kDemoPassword);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pageWide),
              child: BlocConsumer<AuthCubit, AuthState>(
                listener: (context, state) {
                  if (state.status == AuthStatus.authenticated) {
                    context.go('/events');
                  }
                },
                builder: (context, state) {
                  if (state.status == AuthStatus.unknown) {
                    return const Column(
                      children: [
                        SizedBox(height: AppSpacing.xxl),
                        BrandMark(
                          subtitle: 'Starting ops console…',
                        ),
                        SizedBox(height: AppSpacing.xl),
                        Center(child: CircularProgressIndicator()),
                      ],
                    );
                  }
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.xxl),
                        const BrandMark(
                          subtitle: 'Simulated wallet ops console',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Sign in, then run the guided demo on Events to watch '
                          'webhooks move through the queue — HMAC ingest, worker '
                          'claim, rule match — against your local API.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                border: Border.all(
                                  color:
                                      scheme.outline.withValues(alpha: 0.7),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DEMO ACCOUNT',
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    'Prefilled credentials',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    '$kDemoEmail\npassword: $kDemoPassword\n'
                                    'webhook user_ref: $kDemoUserRef',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Prefer in-app “Run live demo” on Events '
                                    'after sign-in.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () {
                                        _email.text = kDemoEmail;
                                        _password.text = kDemoPassword;
                                      },
                                      child: const Text(
                                        'Reset to demo credentials',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 3,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: const BorderRadius.only(
                                    topLeft:
                                        Radius.circular(AppSpacing.radiusSm),
                                    bottomLeft:
                                        Radius.circular(AppSpacing.radiusSm),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter email'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(state.busy),
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                          validator: (v) => (v == null || v.length < 8)
                              ? 'Min 8 characters'
                              : null,
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            state.errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                          onPressed: state.busy ? null : () => _submit(false),
                          child: state.busy
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextButton(
                          onPressed: () => context.go('/register'),
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(bool busy) {
    if (busy) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<AuthCubit>().login(
          email: _email.text.trim(),
          password: _password.text,
        );
  }
}
