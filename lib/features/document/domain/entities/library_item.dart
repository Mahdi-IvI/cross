class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.isFolder,
    this.serverId,
    this.parentId,
    this.fileName = '',
    this.sizeBytes,
    this.hasFile = false,
    this.localPath = '',
    this.isFavorite = false,
    this.isPending = false,
    this.syncError = '',
  });

  final int id;
  final int? serverId;
  final int? parentId;
  final String name;
  final String description;
  final bool isFolder;
  final String fileName;
  final int? sizeBytes;
  final bool hasFile;
  final String localPath;
  final bool isFavorite;
  final bool isPending;
  final String syncError;

  bool get availableOffline => localPath.isNotEmpty;
  String get extension =>
      fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'FILE';
}

class LibrarySnapshot {
  const LibrarySnapshot({required this.items, this.pendingCount = 0});
  final List<LibraryItem> items;
  final int pendingCount;
}
