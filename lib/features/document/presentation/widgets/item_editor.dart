import 'package:flutter/material.dart';

import '../../domain/entities/library_item.dart';

class ItemEdit {
  const ItemEdit(this.name, this.description, this.parentId);
  final String name;
  final String description;
  final int? parentId;
}

Future<ItemEdit?> showItemEditor(
  BuildContext context, {
  LibraryItem? item,
  required List<LibraryItem> folders,
  int? parentId,
}) => showDialog<ItemEdit>(
  context: context,
  builder: (_) => _ItemEditor(item: item, folders: folders, parentId: parentId),
);

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({this.item, required this.folders, this.parentId});
  final LibraryItem? item;
  final List<LibraryItem> folders;
  final int? parentId;
  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.item?.name);
  late final description = TextEditingController(
    text: widget.item?.description,
  );
  late int? parentId = widget.item?.parentId ?? widget.parentId;

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final excluded = <int>{if (widget.item?.isFolder == true) widget.item!.id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final folder in widget.folders) {
        if (excluded.contains(folder.parentId) && excluded.add(folder.id)) {
          changed = true;
        }
      }
    }
    final available =
        widget.folders.where((folder) => !excluded.contains(folder.id)).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (parentId != null && !available.any((folder) => folder.id == parentId)) {
      parentId = null;
    }
    return AlertDialog(
      title: Text(
        widget.item == null
            ? 'New folder'
            : 'Edit ${widget.item!.isFolder ? 'folder' : 'document'}',
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Name is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Description is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: parentId ?? 0,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Location'),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('All files')),
                    for (final folder in available)
                      DropdownMenuItem(
                        value: folder.id,
                        child: Text(
                          folder.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => parentId = value == 0 ? null : value,
                ),
              ],
            ),
          ),
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
              Navigator.pop(
                context,
                ItemEdit(name.text.trim(), description.text.trim(), parentId),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<bool> confirmDelete(BuildContext context, LibraryItem item) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${item.isFolder ? 'folder' : 'document'}?'),
        content: Text(
          item.isFolder
              ? '“${item.name}” and all its contents will be deleted.'
              : '“${item.name}” will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;
