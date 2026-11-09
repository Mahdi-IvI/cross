import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/session.dart';
import '../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.storage);
  final FlutterSecureStorage storage;
  static const _key = 'dms.session.v1';
  @override
  Future<Session?> restore() async {
    final value = await storage.read(key: _key);
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      // Ignore obsolete server preferences; never restore a token for another server.
      if (json['baseUrl'] != null && json['baseUrl'] != AppConfig.apiBaseUrl) {
        await storage.delete(key: _key);
        return null;
      }
      return _session(json['token'] as String, json);
    } on FormatException {
      await storage.delete(key: _key);
      return null;
    } on TypeError {
      await storage.delete(key: _key);
      return null;
    }
  }

  Session _session(String token, Map<String, dynamic> user) => Session(
    token: token,
    username: user['username'] as String,
    firstName: user['firstName'] as String,
    lastName: user['lastName'] as String,
    email: user['email'] as String,
  );

  Future<Session> _save(Session session) async {
    await storage.write(
      key: _key,
      value: jsonEncode({
        'token': session.token,
        'username': session.username,
        'firstName': session.firstName,
        'lastName': session.lastName,
        'email': session.email,
      }),
    );
    return session;
  }

  Future<Session> _authenticate(String path, Map<String, dynamic> body) async {
    final client = ApiClient();
    try {
      final result = await client.dio.post<Map<String, dynamic>>(
        'auth/$path',
        data: body,
      );
      final token = result.data!['token'] as String;
      client.dio.options.headers['Authorization'] = 'Bearer $token';
      final profile = await client.dio.get<Map<String, dynamic>>('auth/me');
      return await _save(_session(token, profile.data!));
    } catch (error) {
      final failure = ApiClient.failure(error);
      if (failure.statusCode == 401) {
        throw const FormatException('Incorrect username or password.');
      }
      if (failure.isOffline) {
        throw const FormatException(
          'Cannot connect to the server. Please check your connection.',
        );
      }
      throw failure;
    } finally {
      client.close();
    }
  }

  @override
  Future<Session> signIn({
    required String username,
    required String password,
  }) => _authenticate('login', {
    'username': username.trim(),
    'password': password,
  });

  @override
  Future<Session> register({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
  }) => _authenticate('register', {
    'username': username.trim(),
    'password': password,
    'firstName': firstName.trim(),
    'lastName': lastName.trim(),
    'email': email.trim(),
  });

  @override
  Future<Session> updateProfile(
    Session session,
    String firstName,
    String lastName,
  ) async {
    final client = ApiClient(token: session.token);
    try {
      final result = await client.dio.put<Map<String, dynamic>>(
        'auth/me',
        data: {'firstName': firstName.trim(), 'lastName': lastName.trim()},
      );
      return await _save(_session(session.token, result.data!));
    } catch (error) {
      throw ApiClient.failure(error);
    } finally {
      client.close();
    }
  }

  @override
  Future<void> signOut() => storage.delete(key: _key);
}
