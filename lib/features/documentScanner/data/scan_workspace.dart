import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../domain/scanned_page.dart';
import 'scan_processing.dart';

/// Files for one open scanner screen. Nothing is stored in ObjectBox or restored.
class ScanWorkspace {
  ScanWorkspace({required this.createDirectory});
  final Future<Directory> Function() createDirectory;
  final _processing = ScanProcessing();
  Future<Directory>? _directory;
  Future<Directory> get directory => _directory ??= createDirectory();

  Future<List<ScannedPage>> importImages(List<String> paths) async {
    if (paths.isEmpty) return [];
    final folder = await directory;
    final added = <ScannedPage>[];
    final targets = <File>[];
    try {
      for (final source in paths) {
        final id =
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0xFFFFFFFF)}';
        final file = File(p.join(folder.path, '$id.jpg'));
        targets.add(file);
        await _processing.normalize(source, file.path);
        added.add(ScannedPage(id: id, originalPath: file.path));
      }
      return added;
    } catch (_) {
      for (final file in targets) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }

  Future<String> preview(ScannedPage page) async => _processing.preview(
    page,
    p.join(
      (await directory).path,
      '${page.id}-${page.filter.name}-${page.quarterTurns}.jpg',
    ),
  );

  Future<String> pdf(List<ScannedPage> pages) async =>
      _processing.pdf(pages, p.join((await directory).path, 'scan.pdf'));

  Future<void> remove(ScannedPage page) async {
    if (_directory == null) return;
    await for (final file in (await directory).list()) {
      final name = p.basename(file.path);
      if (name.startsWith('${page.id}.') || name.startsWith('${page.id}-')) {
        await file.delete();
      }
    }
  }

  Future<void> dispose() async {
    if (_directory == null) return;
    final folder = await _directory!;
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}
