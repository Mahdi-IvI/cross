import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/entities/session.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
final activeSessionProvider = Provider<Session?>(
  (ref) => ref.watch(authControllerProvider).asData?.value,
);

class AuthController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() => ref.watch(authRepositoryProvider).restore();

  Future<void> signIn(String username, String password) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signIn(username: username, password: password),
    );
    if (ref.mounted) state = result;
  }

  Future<void> register(
    String username,
    String password,
    String firstName,
    String lastName,
    String email,
  ) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .register(
            username: username,
            password: password,
            firstName: firstName,
            lastName: lastName,
            email: email,
          ),
    );
    if (ref.mounted) state = result;
  }

  Future<void> updateProfile(String firstName, String lastName) async {
    final session = state.asData?.value;
    if (session == null) return;
    final saved = await ref
        .read(authRepositoryProvider)
        .updateProfile(session, firstName, lastName);
    if (ref.mounted) state = AsyncData(saved);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (ref.mounted) state = const AsyncData(null);
  }
}
