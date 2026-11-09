import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_failure.dart';
import '../../document/domain/entities/item_details.dart';
import '../../document/presentation/providers/document_providers.dart';
import '../data/scan_image_source.dart';
import '../data/scan_workspace.dart';
import '../domain/scanned_page.dart';

final scanImageSourceProvider = Provider<ScanImageSource>(
  (ref) => NativeScanImageSource(),
);
final scanWorkspaceFactoryProvider = Provider<ScanWorkspace Function()>(
  (ref) =>
      () => ScanWorkspace(
        createDirectory: () async =>
            (await getTemporaryDirectory()).createTemp('dms-scan-'),
      ),
);

final scannerControllerProvider = NotifierProvider.autoDispose
    .family<ScannerController, List<ScannedPage>, int?>(ScannerController.new);

class ScannerController extends Notifier<List<ScannedPage>> {
  ScannerController(this.parentId);
  final int? parentId;
  late ScanWorkspace _workspace;
  Future<void> _pending = Future.value();

  @override
  List<ScannedPage> build() {
    final workspace = ref.read(scanWorkspaceFactoryProvider)();
    _workspace = workspace;
    ref.onDispose(
      () => unawaited(
        _pending.then((_) async {
          try {
            await workspace.dispose();
          } on FileSystemException {
            /* OS temporary storage will reclaim it. */
          }
        }),
      ),
    );
    return const [];
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> capture() => _import(true);
  Future<void> importImages() => _import(false);
  Future<void> _import(bool camera) => _run(() async {
    final source = ref.read(scanImageSourceProvider);
    final acquired = await (camera ? source.capture() : source.pick());
    try {
      if (!ref.mounted) return;
      final pages = await _workspace.importImages(acquired.paths);
      if (ref.mounted) state = List.unmodifiable([...state, ...pages]);
    } finally {
      await acquired.dispose();
    }
  });

  void updatePage(ScannedPage updated) {
    state = [
      for (final page in state)
        page.id == updated.id
            ? page.copyWith(
                filter: updated.filter,
                quarterTurns: updated.quarterTurns,
              )
            : page,
    ];
  }

  void reorder(int from, int to) {
    final pages = state.toList();
    pages.insert(to, pages.removeAt(from));
    state = List.unmodifiable(pages);
  }

  Future<void> remove(String id) => _run(() async {
    final page = state.firstWhere((page) => page.id == id);
    state = state.where((page) => page.id != id).toList();
    await _workspace.remove(page);
  });

  Future<String> preview(ScannedPage page) =>
      _run(() => _workspace.preview(page));

  Future<int> savePdf(String name, String description) => _run(() async {
    final details = ItemDetails(name, description);
    final path = await _workspace.pdf(state);
    if (!ref.mounted) throw const AppFailure('The scanner was closed.');
    var fileName = details.name.replaceAll(RegExp(r'[\\/\x00-\x1f]'), '_');
    if (!fileName.toLowerCase().endsWith('.pdf')) fileName += '.pdf';
    return ref
        .read(documentActionsProvider)
        .upload(path, fileName, details.name, details.description, parentId);
  });
}
