import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_feedback.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../document/presentation/providers/document_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold();
    return Scaffold(
      appBar: AppBar(title: const Text('Account & settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          session.username.substring(0, 1).toUpperCase(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        session.displayName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('@${session.username}'),
                      const SizedBox(height: 8),
                      SelectableText(session.email),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _editProfile(context, ref),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit profile'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'On this device',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: const Text('Remove offline files'),
                      subtitle: const Text(
                        'Server files and pending uploads are kept.',
                      ),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove downloaded copies?'),
                            content: const Text(
                              'You can download them again. Files waiting to upload will stay on this device.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Remove copies'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        try {
                          await ref
                              .read(documentActionsProvider)
                              .removeOfflineFiles();
                        } catch (error) {
                          if (context.mounted) showError(context, error);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign out?'),
                      content: const Text(
                        'Offline files and pending changes stay private to this account and will be available when you sign in again.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await ref.read(authControllerProvider.notifier).signOut();
                    } catch (error) {
                      if (context.mounted) showError(context, error);
                    }
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final session = ref.read(activeSessionProvider)!;
    final result = await showDialog<({String firstName, String lastName})>(
      context: context,
      builder: (_) =>
          _ProfileEditor(first: session.firstName, last: session.lastName),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(result.firstName, result.lastName);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.first, required this.last});
  final String first;
  final String last;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final firstName = TextEditingController(text: widget.first);
  late final lastName = TextEditingController(text: widget.last);
  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit profile'),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: firstName,
            maxLength: 50,
            decoration: const InputDecoration(labelText: 'First name'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: lastName,
            maxLength: 50,
            decoration: const InputDecoration(labelText: 'Last name'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Required' : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, (
              firstName: firstName.text.trim(),
              lastName: lastName.text.trim(),
            ));
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
