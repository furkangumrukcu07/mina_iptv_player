/// Application-level failures with an optional [cause].
sealed class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message';
}

final class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);
}

final class ParseException extends AppException {
  const ParseException(super.message, [super.cause]);
}

final class StorageException extends AppException {
  const StorageException(super.message, [super.cause]);
}
