sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

class FileAccessException extends AppException {
  const FileAccessException(super.message, {super.cause, super.stackTrace});
}

class UnsupportedFormatException extends AppException {
  const UnsupportedFormatException(super.message,
      {super.cause, super.stackTrace});
}

class ParseException extends AppException {
  const ParseException(super.message, {super.cause, super.stackTrace});
}

class CancelledException extends AppException {
  const CancelledException([super.message = 'Operação cancelada']);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause, super.stackTrace});
}

class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause, super.stackTrace});
}
