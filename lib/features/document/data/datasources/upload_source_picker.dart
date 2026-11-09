import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/upload_source.dart';

class PreparedUpload {
  const PreparedUpload(this.path, this.cleanup);
  final String path;
  final Future<void> Function() cleanup;
  Future<void> dispose() => cleanup();
}

class UploadSourcePicker {
  UploadSourcePicker({
    ImagePicker? camera,
    Future<Directory> Function()? createDirectory,
  }) : camera = camera ?? ImagePicker(),
       createDirectory =
           createDirectory ??
           (() async =>
               (await getTemporaryDirectory()).createTemp('dms-upload-'));

  final ImagePicker camera;
  final Future<Directory> Function() createDirectory;

  Future<UploadSource?> pick(UploadKind kind) async {
    try {
      if (kind == UploadKind.file) {
        final file = await FilePicker.pickFile();
        if (file == null) return null;
        return await _nonEmpty(
          UploadSource(
            name: file.name,
            size: await file.length(),
            openRead: file.readAsByteStream,
          ),
        );
      }
      final file = await switch (kind) {
        UploadKind.photo => camera.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: false,
        ),
        UploadKind.video => camera.pickVideo(source: ImageSource.camera),
        UploadKind.gallery => camera.pickMedia(requestFullMetadata: false),
        UploadKind.file => throw StateError('Handled above'),
      };
      if (file == null) return null;
      return await _fromMedia(file);
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  Future<UploadSource?> recover() async {
    if (!Platform.isAndroid) return null;
    try {
      final response = await camera.retrieveLostData();
      if (response.exception != null) throw response.exception!;
      final file = response.files?.firstOrNull ?? response.file;
      if (file == null) return null;
      return await _fromMedia(file);
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  Future<UploadSource> _nonEmpty(UploadSource source) async {
    if (source.size == 0) {
      await source.dispose();
      throw const AppFailure('Choose a non-empty file.');
    }
    return source;
  }

  Future<UploadSource> _fromMedia(XFile file) async {
    return _nonEmpty(
      UploadSource(
        name: file.name,
        size: await file.length(),
        openRead: file.openRead,
        onDispose: () async {
          // image_picker returns app-private copies; never delete file_picker originals.
          try {
            final temporary = File(file.path);
            if (await temporary.exists()) await temporary.delete();
          } on FileSystemException {
            /* The OS can reclaim temporary media. */
          }
        },
      ),
    );
  }

  Future<PreparedUpload> prepare(UploadSource source) async {
    final directory = await createDirectory();
    try {
      final target = File(p.join(directory.path, 'upload'));
      await source.openRead().cast<List<int>>().pipe(target.openWrite());
      return PreparedUpload(target.path, () async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  AppFailure _failure(PlatformException error) {
    final code = error.code.toLowerCase();
    if (code.contains('access') || code.contains('permission')) {
      return const AppFailure(
        'Camera, microphone or photo access was denied. Allow access in your phone Settings and try again.',
      );
    }
    if (code.contains('already_active')) {
      return const AppFailure('The camera or picker is already open.');
    }
    return const AppFailure(
      'Could not open the camera or photo library. Please try again.',
    );
  }
}
