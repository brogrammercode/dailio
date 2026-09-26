import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../core/error/error_handler.dart';

String attendanceErrorMessage(Object error) {
  if (error is AppException) return error.message;
  if (error is DioException) return handleDioException(error).message;
  return 'We could not complete that attendance action. Please try again.';
}
