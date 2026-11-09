class Session {
  const Session({
    required this.token,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String token;
  final String username;
  final String firstName;
  final String lastName;
  final String email;

  String get accountKey => username;
  String get displayName => '$firstName $lastName'.trim();
}
