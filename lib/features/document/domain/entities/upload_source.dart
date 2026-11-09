enum UploadKind { file, photo, video, gallery }

/// A selected file that can be streamed without loading it into memory.
class UploadSource {
  const UploadSource({
    required this.name,
    required this.size,
    required this.openRead,
    this.onDispose,
  });

  final String name;
  final int? size;
  final Stream<List<int>> Function() openRead;
  final Future<void> Function()? onDispose;

  Future<void> dispose() async => onDispose?.call();
}
