import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../providers/document_providers.dart';

class SyncState {
  const SyncState({
    this.isRunning = false,
    this.isOffline = false,
    this.error,
    this.progress,
    this.lastSynced,
  });
  final bool isRunning;
  final bool isOffline;
  final String? error;
  final double? progress;
  final DateTime? lastSynced;
}

final syncControllerProvider =
    NotifierProvider.autoDispose<SyncController, SyncState>(SyncController.new);
final connectivityChangesProvider = Provider<Stream<List<ConnectivityResult>>>(
  (ref) => Connectivity().onConnectivityChanged,
);

class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() {
    if (ref.watch(activeSessionProvider) == null) return const SyncState();
    ref.watch(documentRepositoryProvider);
    final timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => synchronize(),
    );
    final subscription = ref.watch(connectivityChangesProvider).listen((
      results,
    ) {
      if (!results.contains(ConnectivityResult.none)) synchronize();
    });
    ref.onDispose(timer.cancel);
    ref.onDispose(subscription.cancel);
    Future.microtask(synchronize);
    return const SyncState();
  }

  Future<void> synchronize() async {
    if (!ref.mounted ||
        ref.read(activeSessionProvider) == null ||
        state.isRunning) {
      return;
    }
    final account = ref.read(activeSessionProvider)!.accountKey;
    bool active() =>
        ref.mounted && ref.read(activeSessionProvider)?.accountKey == account;
    final previous = state.lastSynced;
    state = SyncState(isRunning: true, lastSynced: previous);
    try {
      await ref
          .read(documentRepositoryProvider)
          .synchronize(
            onProgress: (progress) {
              if (active()) {
                state = SyncState(
                  isRunning: true,
                  progress: progress,
                  lastSynced: previous,
                );
              }
            },
          );
      if (active()) state = SyncState(lastSynced: DateTime.now());
    } catch (error) {
      final failure = ApiClient.failure(error);
      if (active() && failure.statusCode == 401) {
        await ref.read(authControllerProvider.notifier).signOut();
        return;
      }
      if (active()) {
        state = SyncState(
          isOffline: failure.isOffline,
          error: failure.message,
          lastSynced: previous,
        );
      }
    }
  }
}
