import 'package:flutter/material.dart';

import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/library_item.dart';

enum ItemAction { edit, delete, favorite, offline }

class DocCard extends StatelessWidget {
  const DocCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAction,
    this.grid = false,
  });
  final LibraryItem item;
  final VoidCallback onTap;
  final void Function(ItemAction) onAction;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final iconColor = item.isFolder
        ? const Color(0xFFB17A17)
        : const Color(0xFF216C60);
    final icon = Icon(
      item.isFolder
          ? Icons.folder_rounded
          : item.extension == 'PDF'
          ? Icons.picture_as_pdf_outlined
          : Icons.description_outlined,
      size: grid ? 42 : 28,
      color: iconColor,
    );
    final menu = PopupMenuButton<ItemAction>(
      tooltip: 'Actions for ${item.name}',
      onSelected: onAction,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: ItemAction.favorite,
          child: Text(
            item.isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
        ),
        if (!item.isFolder && item.hasFile)
          PopupMenuItem(
            value: ItemAction.offline,
            child: Text(
              item.availableOffline ? 'Open saved file' : 'Save for offline',
            ),
          ),
        const PopupMenuItem(value: ItemAction.edit, child: Text('Edit / move')),
        const PopupMenuItem(value: ItemAction.delete, child: Text('Delete')),
      ],
    );
    final indicators = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.isFavorite)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.star_rounded, size: 16, color: Color(0xFFB17A17)),
          ),
        if (item.availableOffline && !item.isFolder)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.offline_pin_outlined, size: 16),
          ),
        if (item.isPending)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: item.syncError.isEmpty
                  ? 'Waiting to synchronize'
                  : item.syncError,
              child: Icon(
                item.syncError.isEmpty
                    ? Icons.cloud_upload_outlined
                    : Icons.error_outline,
                size: 17,
                color: item.syncError.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
    if (!grid) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: icon,
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            item.isFolder
                ? item.description
                : '${item.extension} · ${formatSize(item.sizeBytes)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [indicators, menu],
          ),
          onTap: onTap,
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [icon, const Spacer(), menu]),
              const Spacer(),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.isFolder
                          ? 'Folder'
                          : '${item.extension} · ${formatSize(item.sizeBytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  indicators,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
