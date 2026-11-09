import 'package:dio/dio.dart';

import '../errors/app_failure.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient({String? token, HttpClientAdapter? adapter}) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 2),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
  }

  late final Dio dio;
  void close() => dio.close(force: true);

  static AppFailure failure(Object error) {
    if (error is AppFailure) return error;
    if (error is! DioException) {
      return const AppFailure('Something went wrong. Please try again.');
    }
    final status = error.response?.statusCode;
    if (status == null) {
      return const AppFailure(
        'Server unavailable. Your changes are saved on this device.',
        isOffline: true,
      );
    }
    if (status == 401) {
      return const AppFailure(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    final data = error.response?.data;
    String? message;
    if (data is String && data.isNotEmpty && !data.trimLeft().startsWith('<')) {
      message = data;
    }
    if (data is Map) {
      if (data['errors'] is Map) {
        message = (data['errors'] as Map).values
            .expand((v) => v is List ? v : [v])
            .join('\n');
      } else {
        message = (data['detail'] ?? data['title'])?.toString();
      }
    }
    return AppFailure(
      message ??
          (status >= 500
              ? 'The server could not complete this request. Please retry.'
              : 'The request could not be completed.'),
      statusCode: status,
      isOffline: status == 502 || status == 503 || status == 504,
    );
  }
}
