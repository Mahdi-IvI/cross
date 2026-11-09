import '../entities/library_item.dart';

abstract interface class DocumentRepository {
  Stream<LibrarySnapshot> watch();
  Future<void> synchronize({void Function(double?)? onProgress});
  Future<int> createFolder(String name, String description, int? parentId);
  Future<int> upload(
    String sourcePath,
    String fileName,
    String name,
    String description,
    int? parentId,
  );
  Future<void> update(int id, String name, String description, int? parentId);
  Future<void> delete(int id);
  Future<void> toggleFavorite(int id);
  Future<String> download(int id, {void Function(double)? onProgress});
  Future<void> removeOfflineFiles();
}
