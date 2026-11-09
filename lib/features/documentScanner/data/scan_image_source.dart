import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_failure.dart';

class AcquiredImages {
  const AcquiredImages(
    this.paths, {
    this.temporaryDirectory,
    this.deleteFilesOnDispose = false,
  });
  final List<String> paths;
  final Directory? temporaryDirectory;
  // Native camera outputs belong to us; picked originals belong to the user.
  final bool deleteFilesOnDispose;
  Future<void> dispose() async {
    if (deleteFilesOnDispose) {
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
    if (temporaryDirectory != null && await temporaryDirectory!.exists()) {
      await temporaryDirectory!.delete(recursive: true);
    }
  }
}

abstract interface class ScanImageSource {
  Future<AcquiredImages> capture();
  Future<AcquiredImages> pick();
}

class NativeScanImageSource implements ScanImageSource {
  static const maxImageBytes = 30 * 1024 * 1024;
  static const _channel = MethodChannel('dms/scan_images');

  @override
  Future<AcquiredImages> capture() async {
    Directory? temporary;
    final paths = <String>[];
    AcquiredImages acquired() => AcquiredImages(
      paths,
      temporaryDirectory: temporary,
      deleteFilesOnDispose: true,
    );
    try {
      final result = await FlutterDocScanner().getScannedDocumentAsImages(
        // The plugin requires a positive Android int; avoid its four-page default.
        page: 0x7fffffff,
        imageFormat: ImageFormat.jpeg,
        quality: .9,
      );
      if (result == null) return const AcquiredImages([]);
      temporary = await (await getTemporaryDirectory()).createTemp(
        'dms-capture-',
      );
      for (final reference in result.images) {
        final uri = Uri.tryParse(reference);
        if (uri?.scheme == 'content' && Platform.isAndroid) {
          final target = p.join(temporary.path, '${paths.length}.jpg');
          await _channel.invokeMethod<void>('copyImage', {
            'uri': reference,
            'target': target,
            'maxBytes': maxImageBytes,
          });
          paths.add(target);
        } else if (uri?.scheme == 'file') {
          paths.add(uri!.toFilePath());
        } else if (uri == null || !uri.hasScheme) {
          paths.add(reference);
        } else {
          throw const AppFailure(
            'The scanner returned an unsupported image. Try importing images instead.',
          );
        }
      }
      return acquired();
    } on DocScanException catch (error) {
      await acquired().dispose();
      if (error.code == DocScanException.codeCancelled) {
        return const AcquiredImages([]);
      }
      throw const AppFailure(
        'The scanner could not open. Check camera access in Settings, or use Import images. Android may need Google Play services to finish downloading the scanner.',
      );
    } catch (_) {
      await acquired().dispose();
      rethrow;
    }
  }

  @override
  Future<AcquiredImages> pick() async {
    final selected = await FilePicker.pickFiles(type: FileType.image);
    if (selected.isEmpty) return const AcquiredImages([]);
    final directory = await (await getTemporaryDirectory()).createTemp(
      'dms-scan-pick-',
    );
    try {
      final paths = <String>[];
      for (final image in selected) {
        final path = p.join(directory.path, '${paths.length}.image');
        final output = File(path).openWrite();
        try {
          var bytes = 0;
          await for (final chunk in image.readAsByteStream()) {
            bytes += chunk.length;
            if (bytes > maxImageBytes) {
              throw const AppFailure('Choose images smaller than 30 MiB each.');
            }
            output.add(chunk);
          }
          await output.flush();
        } finally {
          await output.close();
        }
        paths.add(path);
      }
      return AcquiredImages(paths, temporaryDirectory: directory);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }
}
