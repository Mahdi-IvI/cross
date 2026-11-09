import 'package:objectbox/objectbox.dart';

@Entity()
class CachedItem {
  CachedItem({
    this.id = 0,
    required this.scope,
    this.serverId,
    required this.isFolder,
    required this.name,
    required this.description,
    this.parentId,
    this.fileName = '',
    this.sizeBytes,
    this.hasFile = false,
    this.localPath = '',
    this.isFavorite = false,
    this.isPending = false,
    this.isDeleted = false,
    this.syncError = '',
  });

  @Id()
  int id;
  @Index()
  String scope;
  int? serverId;
  bool isFolder;
  String name;
  String description;
  int? parentId;
  String fileName;
  int? sizeBytes;
  bool hasFile;
  String localPath;
  bool isFavorite;
  bool isPending;
  bool isDeleted;
  String syncError;
}
