import 'package:dio/dio.dart';
import '../../storage/secure_storage.dart';

class AuthInterceptor extends QueuedInterceptor {
  final SecureStorage _secureStorage;
  late final Dio dio;

  AuthInterceptor(this._secureStorage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final currentToken = await _secureStorage.getAccessToken();
      final requestToken = err.requestOptions.headers['Authorization']
          ?.replaceAll('Bearer ', '');

      // If the token in storage is already different from the one that caused the 401,
      // it means a concurrent request already refreshed it. Just retry!
      if (currentToken != null &&
          requestToken != null &&
          currentToken != requestToken) {
        err.requestOptions.headers['Authorization'] = 'Bearer $currentToken';
        try {
          final retryResponse = await dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (e) {
          // Fall through to regular error handling
        }
      }

      final refreshToken = await _secureStorage.getRefreshToken();

      if (refreshToken != null) {
        try {
          // Use a completely separate Dio instance to avoid interceptor infinite loops
          final tokenDio =
              Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));

          final response = await tokenDio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          if (response.statusCode == 200) {
            final newAccess = response.data['accessToken'];
            final newRefresh = response.data['refreshToken'];

            if (newAccess != null && newRefresh != null) {
              await _secureStorage.saveTokens(
                access: newAccess,
                refresh: newRefresh,
              );

              // Retry the original request with the new access token
              final opts = err.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccess';

              final retryResponse = await dio.fetch(opts);
              return handler.resolve(retryResponse);
            }
          }
        } catch (e) {
          // If refresh token fails (e.g. 401 on refresh, or network error), clear tokens
          await _secureStorage.clearTokens();
        }
      } else {
        // No refresh token available, just clear access token just in case
        await _secureStorage.clearTokens();
      }
    }

    // Pass the error to the next interceptor if not resolved
    handler.next(err);
  }
}
