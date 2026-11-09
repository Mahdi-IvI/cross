import '../../../../core/database/entities/cached_item.dart';
import '../../domain/entities/library_item.dart';

extension CachedItemMapper on CachedItem {
  LibraryItem toDomain() => LibraryItem(
    id: id,
    serverId: serverId,
    parentId: parentId,
    name: name,
    description: description,
    isFolder: isFolder,
    fileName: fileName,
    sizeBytes: sizeBytes,
    hasFile: hasFile,
    localPath: localPath,
    isFavorite: isFavorite,
    isPending: isPending,
    syncError: syncError,
  );
}

class RemoteItem {
  RemoteItem.fromJson(Map<String, dynamic> json, {required this.isFolder})
    : id = json['id'] as int,
      name = json['name'] as String,
      description = json['description'] as String,
      parentId = json['containingFolder'] as int?,
      fileName = json['fileName'] as String? ?? '',
      sizeBytes = json['sizeBytes'] as int?,
      hasFile = json['hasFile'] as bool? ?? false;
  final int id;
  final bool isFolder;
  final String name;
  final String description;
  final int? parentId;
  final String fileName;
  final int? sizeBytes;
  final bool hasFile;
  String get key => '$isFolder:$id';
}
