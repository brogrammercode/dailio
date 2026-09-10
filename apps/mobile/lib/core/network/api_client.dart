import 'package:dio/dio.dart';

import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/tenant_interceptor.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({
    required String baseUrl,
    required AuthInterceptor authInterceptor,
    required TenantInterceptor tenantInterceptor,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    authInterceptor.dio = _dio;

    _dio.interceptors.addAll([
      authInterceptor,
      tenantInterceptor,
      LoggingInterceptor(),
    ]);
  }

  Dio get dio => _dio;
}
