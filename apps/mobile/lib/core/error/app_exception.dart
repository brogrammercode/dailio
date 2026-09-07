class AppException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  const AppException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'AppException($code): $message';
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Authentication required'])
      : super(code: 'UNAUTHORIZED', message: message);
}

class ForbiddenException extends AppException {
  const ForbiddenException([String message = 'You do not have permission'])
      : super(code: 'FORBIDDEN', message: message);
}

class NotFoundException extends AppException {
  const NotFoundException([String message = 'Resource not found'])
      : super(code: 'NOT_FOUND', message: message);
}

class ConflictException extends AppException {
  const ConflictException(String message)
      : super(code: 'CONFLICT', message: message);
}

class NetworkException extends AppException {
  const NetworkException([String message = 'Network error. Please check your connection.'])
      : super(code: 'NETWORK_ERROR', message: message);
}

class ServerException extends AppException {
  const ServerException([String message = 'An unexpected server error occurred'])
      : super(code: 'SERVER_ERROR', message: message);
}
