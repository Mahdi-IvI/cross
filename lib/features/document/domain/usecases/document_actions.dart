import '../entities/item_details.dart';
import '../repositories/document_repository.dart';

// Application use cases depend only on the domain contract; API, ObjectBox and
// filesystem choices remain in the repository implementation.
class DocumentActions {
  const DocumentActions(this.repository);
  final DocumentRepository repository;

  Future<int> createFolder(String name, String description, int? parentId) {
    final details = ItemDetails(name, description);
    return repository.createFolder(details.name, details.description, parentId);
  }

  Future<int> upload(
    String path,
    String fileName,
    String name,
    String description,
    int? parentId,
  ) {
    final details = ItemDetails(name, description);
    return repository.upload(
      path,
      fileName,
      details.name,
      details.description,
      parentId,
    );
  }

  Future<void> update(int id, String name, String description, int? parentId) {
    final details = ItemDetails(name, description);
    return repository.update(id, details.name, details.description, parentId);
  }

  Future<void> delete(int id) => repository.delete(id);
  Future<void> toggleFavorite(int id) => repository.toggleFavorite(id);
  Future<String> download(int id, {void Function(double)? onProgress}) =>
      repository.download(id, onProgress: onProgress);
  Future<void> removeOfflineFiles() => repository.removeOfflineFiles();
}
