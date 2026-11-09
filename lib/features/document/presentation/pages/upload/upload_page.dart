import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/app_feedback.dart';
import '../../../../auth/presentation/auth_controller.dart';
import '../../../data/datasources/upload_source_picker.dart';
import '../../../domain/entities/upload_source.dart';
import '../../controllers/sync_controller.dart';
import '../../providers/document_providers.dart';
import '../../providers/upload_providers.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key, this.parentId, required this.source});

  final int? parentId;
  final UploadSource source;

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final description = TextEditingController();
  bool busy = false;
  Future<void> pending = Future.value();

  @override
  void initState() {
    super.initState();
    name.text = widget.source.name;
  }

  @override
  void dispose() {
    final source = widget.source;
    unawaited(
      pending.catchError((Object _) {}).then((_) async => source.dispose()),
    );
    name.dispose();
    description.dispose();
    super.dispose();
  }

  void save() {
    if (!busy) pending = saveFile();
  }

  Future<void> saveFile() async {
    if (!form.currentState!.validate()) return;
    final source = widget.source;
    final picker = ref.read(uploadSourcePickerProvider);
    final actions = ref.read(documentActionsProvider);
    setState(() {
      busy = true;
    });
    PreparedUpload? prepared;
    try {
      prepared = await picker.prepare(source);
      if (!mounted) return;
      await actions.upload(
        prepared.path,
        source.name,
        name.text,
        description.text,
        widget.parentId,
      );
      if (!mounted) return;
      unawaited(ref.read(syncControllerProvider.notifier).synchronize());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File saved on this device. Upload will synchronize automatically.',
          ),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(
          widget.parentId == null
              ? '/library'
              : '/library?folder=${widget.parentId}',
        );
      }
    } catch (failure) {
      if (mounted) showError(context, failure);
    } finally {
      await prepared?.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(activeSessionProvider) == null) return const Scaffold();
    ref.watch(syncControllerProvider);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Upload document')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Form(
                    key: form,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: name,
                          enabled: !busy,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            labelText: 'Document name',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'A name is required.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: description,
                          enabled: !busy,
                          maxLines: 4,
                          maxLength: 4000,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'A description is required.'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: busy ? null : save,
                    icon: const Icon(Icons.upload),
                    label: Text(busy ? 'Preparing file…' : 'Save & upload'),
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
