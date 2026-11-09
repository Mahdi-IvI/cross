import '../entities/session.dart';

abstract interface class AuthRepository {
  Future<Session?> restore();
  Future<Session> signIn({required String username, required String password});
  Future<Session> register({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
  });
  Future<Session> updateProfile(
    Session session,
    String firstName,
    String lastName,
  );
  Future<void> signOut();
}
