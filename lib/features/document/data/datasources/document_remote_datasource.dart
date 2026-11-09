import 'package:dio/dio.dart';

import '../../../../core/database/entities/cached_item.dart';
import '../../../../core/network/api_client.dart';
import '../models/document_model.dart';

class DocumentRemoteDatasource {
  DocumentRemoteDatasource(this.client);
  final ApiClient client;

  Future<List<RemoteItem>> fetchAll() async {
    final result = await Future.wait([
      client.dio.get<List<dynamic>>('folders'),
      client.dio.get<List<dynamic>>('documents'),
    ]);
    return [
      for (final json in result[0].data!)
        RemoteItem.fromJson(
          Map<String, dynamic>.from(json as Map),
          isFolder: true,
        ),
      for (final json in result[1].data!)
        RemoteItem.fromJson(
          Map<String, dynamic>.from(json as Map),
          isFolder: false,
        ),
    ];
  }

  Future<RemoteItem> save(
    CachedItem item,
    int? parentServerId,
    String action, {
    void Function(double?)? onProgress,
  }) async {
    final endpoint = item.isFolder ? 'folders' : 'documents';
    final fields = <String, dynamic>{
      'name': item.name,
      'description': item.description,
      'containingFolder': parentServerId,
    };
    Response<Map<String, dynamic>> response;
    if (action == 'upload') {
      final form = FormData.fromMap({
        'name': item.name,
        'description': item.description,
        'containingFolder': ?parentServerId,
        'file': await MultipartFile.fromFile(
          item.localPath,
          filename: item.fileName,
        ),
      });
      response = await client.dio.post<Map<String, dynamic>>(
        'documents',
        data: form,
        onSendProgress: (sent, total) =>
            onProgress?.call(total > 0 ? sent / total : null),
      );
    } else if (action == 'createFolder') {
      response = await client.dio.post<Map<String, dynamic>>(
        endpoint,
        data: fields,
      );
    } else {
      response = await client.dio.put<Map<String, dynamic>>(
        '$endpoint/${item.serverId}',
        data: {
          ...fields,
          'id': item.serverId,
          if (!item.isFolder) 'fileName': item.fileName,
        },
      );
    }
    return RemoteItem.fromJson(response.data!, isFolder: item.isFolder);
  }

  Future<void> delete(CachedItem item) async {
    try {
      await client.dio.delete(
        '${item.isFolder ? 'folders' : 'documents'}/${item.serverId}',
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
    }
  }

  Future<void> download(
    CachedItem item,
    String path,
    void Function(double)? onProgress,
  ) async {
    await client.dio.download(
      'documents/${item.serverId}/download',
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
  }
}
