import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.register = false});
  final bool register;
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    for (final controller in [username, password, firstName, lastName, email]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (widget.register) {
      await controller.register(
        username.text,
        password.text,
        firstName.text,
        lastName.text,
        email.text,
      );
    } else {
      await controller.signIn(username.text, password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final error = auth.error;
    final message = error is FormatException
        ? error.message
        : error?.toString();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.folder_copy_outlined, size: 34),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      widget.register
                          ? 'Create your account'
                          : 'Your documents,\nwherever you work.',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.register
                          ? 'One place for all your files and folders.'
                          : 'Sign in to your document library. Saved files stay available offline.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          semanticsLabel: 'Sign in error: $message',
                        ),
                      ),
                    if (widget.register) ...[
                      _field(
                        firstName,
                        'First name',
                        maxLength: 50,
                        autofill: AutofillHints.givenName,
                      ),
                      _field(
                        lastName,
                        'Last name',
                        maxLength: 50,
                        autofill: AutofillHints.familyName,
                      ),
                      _field(
                        email,
                        'Email',
                        keyboard: TextInputType.emailAddress,
                        autofill: AutofillHints.email,
                        validate: (value) =>
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value)
                            ? 'Enter a valid email address.'
                            : null,
                      ),
                    ],
                    _field(
                      username,
                      'Username',
                      maxLength: 50,
                      autofill: AutofillHints.username,
                      validate: (value) => value.length < 3
                          ? 'Use at least 3 characters.'
                          : null,
                    ),
                    TextFormField(
                      controller: password,
                      obscureText: obscure,
                      enabled: !auth.isLoading,
                      autofillHints: [
                        widget.register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.length < 8 || value.length > 30
                          ? 'Use 8–30 characters.'
                          : null,
                      onFieldSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: auth.isLoading ? null : submit,
                      child: Text(
                        widget.register ? 'Create account' : 'Sign in',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => context.go(
                              widget.register ? '/login' : '/register',
                            ),
                      child: Text(
                        widget.register
                            ? 'Already have an account? Sign in'
                            : 'New here? Create an account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int? maxLength,
    String? autofill,
    TextInputType? keyboard,
    String? Function(String)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !ref.watch(authControllerProvider).isLoading,
      keyboardType: keyboard,
      autofillHints: autofill == null ? null : [autofill],
      maxLength: maxLength,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (value) => (value ?? '').trim().isEmpty
          ? '$label is required.'
          : validate?.call(value!.trim()),
    ),
  );
}
