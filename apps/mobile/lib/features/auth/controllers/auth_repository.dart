import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  AuthRepository(this._apiClient, this._secureStorage);

  Future<({AuthTokensModel tokens, UserModel user})> signInWithGoogle(
    String idToken,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/google',
        data: {'idToken': idToken},
      );
      final tokens = AuthTokensModel(
        accessToken: response.data['accessToken'] as String,
        refreshToken: response.data['refreshToken'] as String,
      );
      final user = UserModel.fromJson(
        response.data['user'] as Map<String, dynamic>,
      );
      await _secureStorage.saveTokens(
        access: tokens.accessToken,
        refresh: tokens.refreshToken,
      );
      return (tokens: tokens, user: user);
    } on DioException catch (e) {
      throw handleDioException(e);
    }
  }

  Future<UserModel?> getMe() async {
    try {
      final response = await _apiClient.dio.get('/auth/me');
      return UserModel.fromJson(
        response.data['user'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final ex = handleDioException(e);
      if (ex is UnauthorizedException) return null;
      throw ex;
    }
  }

  Future<void> signOut() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (_) {
      // Best-effort
    } finally {
      await _secureStorage.clearTokens();
    }
  }
}
