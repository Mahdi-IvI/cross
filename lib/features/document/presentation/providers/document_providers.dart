import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/errors/app_failure.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/datasources/document_local_datasource.dart';
import '../../data/datasources/document_remote_datasource.dart';
import '../../data/repositories/document_repository_impl.dart';
import '../../domain/entities/library_item.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/usecases/document_actions.dart';

final documentRepositoryProvider = Provider.autoDispose<DocumentRepository>((
  ref,
) {
  final session = ref.watch(activeSessionProvider);
  if (session == null) throw const AppFailure('Please sign in.');
  final client = ApiClient(token: session.token);
  ref.onDispose(client.close);
  final scope = sha256
      .convert(utf8.encode('${AppConfig.apiBaseUrl}|${session.accountKey}'))
      .toString();
  return DocumentRepositoryImpl(
    local: DocumentLocalDatasource(ref.watch(databaseProvider), scope),
    remote: DocumentRemoteDatasource(client),
    filesDirectory: Directory(
      p.join(ref.watch(supportDirectoryProvider), 'files', scope),
    ),
  );
});

final libraryProvider = StreamProvider.autoDispose<LibrarySnapshot>(
  (ref) => ref.watch(documentRepositoryProvider).watch(),
);

final documentActionsProvider = Provider.autoDispose<DocumentActions>(
  (ref) => DocumentActions(ref.watch(documentRepositoryProvider)),
);
