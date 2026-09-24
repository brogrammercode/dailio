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

  /// Update the current user's profile (name, phone, and/or avatar_base64).
  Future<UserModel> updateProfile({
    String? name,
    String? phone,
    String? avatarBase64,
    String? fcmToken,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? dateOfBirth,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (avatarBase64 != null) data['avatar_base64'] = avatarBase64;
    if (fcmToken != null) data['fcm_token'] = fcmToken;
    if (emergencyContactName != null) {
      data['emergency_contact_name'] = emergencyContactName;
    }
    if (emergencyContactPhone != null) {
      data['emergency_contact_phone'] = emergencyContactPhone;
    }
    if (dateOfBirth != null) {
      data['date_of_birth'] = dateOfBirth;
    }

    final response = await _apiClient.dio.patch('/users/me', data: data);
    return UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<void> deleteAccount() async {
    try {
      await _apiClient.dio.delete('/users/me');
    } catch (_) {
      // Best-effort or handle error if needed
    } finally {
      await _secureStorage.clearTokens();
    }
  }

  Future<void> signOut() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      await _apiClient.dio.post(
        '/auth/logout',
        data: refreshToken != null ? {'refreshToken': refreshToken} : null,
      );
    } catch (_) {
      // Best-effort
    } finally {
      await _secureStorage.clearTokens();
    }
  }
}
