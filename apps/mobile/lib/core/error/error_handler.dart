import 'package:dio/dio.dart';

import 'app_exception.dart';

AppException handleDioException(DioException error) {
  final statusCode = error.response?.statusCode;
  final data = error.response?.data;
  final serverMessage = data is Map ? (data['message'] as String?) : null;
  final serverCode = data is Map ? (data['code'] as String?) : null;

  if (statusCode == null) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          'The server took too long to respond. Check your connection and try again.',
        );
      case DioExceptionType.connectionError:
        return const NetworkException(
          'Unable to reach Dailio. Check the API address and make sure your device is on the same network.',
        );
      case DioExceptionType.cancel:
        return const NetworkException('The request was cancelled.');
      default:
        return NetworkException(error.message ?? 'Network request failed.');
    }
  }

  switch (statusCode) {
    case 401:
      return UnauthorizedException(serverMessage ?? 'Authentication required');
    case 403:
      return ForbiddenException(serverMessage ?? 'Permission denied');
    case 404:
      return NotFoundException(serverMessage ?? 'Not found');
    case 409:
      return ConflictException(serverMessage ?? 'Conflict');
    case 408:
      return const NetworkException('The server timed out. Please try again.');
    case 429:
      return const AppException(
        code: 'RATE_LIMITED',
        message: 'Too many requests. Please wait and try again.',
      );
    case >= 500:
      return ServerException(
          serverMessage ?? 'Dailio is temporarily unavailable.');
    default:
      return AppException(
        code: serverCode ?? 'ERROR',
        message: serverMessage ?? 'An error occurred',
      );
  }
}
