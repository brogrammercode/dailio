import 'package:dio/dio.dart';

import 'app_exception.dart';

AppException handleDioException(DioException error) {
  final statusCode = error.response?.statusCode;
  final data = error.response?.data;
  final serverMessage = data is Map ? (data['message'] as String?) : null;
  final serverCode = data is Map ? (data['code'] as String?) : null;

  switch (statusCode) {
    case 401:
      return UnauthorizedException(serverMessage ?? 'Authentication required');
    case 403:
      return ForbiddenException(serverMessage ?? 'Permission denied');
    case 404:
      return NotFoundException(serverMessage ?? 'Not found');
    case 409:
      return ConflictException(serverMessage ?? 'Conflict');
    case null:
      return const NetworkException();
    default:
      return AppException(
        code: serverCode ?? 'ERROR',
        message: serverMessage ?? 'An error occurred',
      );
  }
}
