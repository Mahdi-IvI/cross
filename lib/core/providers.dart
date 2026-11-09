import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import 'database/app_database.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('Database must be initialized at startup.'),
);
final supportDirectoryProvider = Provider<String>(
  (ref) => throw StateError('App directory is not initialized.'),
);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    Platform.isMacOS
        ? const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          )
        : const FlutterSecureStorage(),
  ),
);
