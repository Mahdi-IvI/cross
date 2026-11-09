class AppFailure implements Exception {
  const AppFailure(this.message, {this.isOffline = false, this.statusCode});

  final String message;
  final bool isOffline;
  final int? statusCode;

  @override
  String toString() => message;
}
