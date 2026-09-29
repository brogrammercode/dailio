import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

import 'auth_repository.dart';
import 'auth_state.dart';
import '../../../core/notifications/notification_runtime.dart';

@injectable
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(const AuthInitial()) {
    NotificationRuntime.setTokenSync(_syncFcmToken);
  }

  Future<void> _syncFcmToken(String token) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _repository.updateProfile(fcmToken: token);
        debugPrint('[Dailio.NOTIFICATIONS] FCM token synced');
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    debugPrint('[Dailio.NOTIFICATIONS] FCM token sync failed: $lastError');
    throw lastError ?? StateError('FCM token sync failed');
  }

  Future<void> checkSession() async {
    emit(const AuthLoading());
    try {
      final user = await _repository.getMe();
      if (user != null && user.isActive) {
        // A restored session does not go through Google sign-in. Re-register
        // the current device token here so push delivery works after app
        // restart, token rotation, or a reinstall with a restored session.
        try {
          final fcmToken = await NotificationRuntime.getToken();
          if (fcmToken != null) await _syncFcmToken(fcmToken);
        } catch (_) {
          // Push registration is best effort and must not block app startup.
        }
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> signInWithGoogle() async {
    emit(const AuthLoading());
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
      );

      // Google Sign-In otherwise restores the last selected account without
      // showing the account chooser. Sign out only from the Google picker so
      // every login attempt can intentionally choose a different account.
      // This does not sign the user out of Dailio or revoke Google access.
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        emit(const AuthUnauthenticated()); // User canceled
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        emit(const AuthError('Failed to get Google ID token.'));
        return;
      }

      final result = await _repository.signInWithGoogle(idToken);

      // Attempt to register FCM token silently
      try {
        final fcmToken = await NotificationRuntime.getToken();
        if (fcmToken != null) {
          await _syncFcmToken(fcmToken);
        }
      } catch (_) {
        // FCM might not be configured, ignore error
      }

      if (result.user.isActive) {
        emit(AuthAuthenticated(result.user));
      } else {
        emit(const AuthError('Account is not active.'));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Update profile fields. Re-emits AuthAuthenticated with the updated user on success.
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? avatarBase64,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? dateOfBirth,
  }) async {
    try {
      final updated = await _repository.updateProfile(
        name: name,
        phone: phone,
        avatarBase64: avatarBase64,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        dateOfBirth: dateOfBirth,
      );
      emit(AuthAuthenticated(updated));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> deleteAccount() async {
    emit(const AuthLoading());
    try {
      await _repository.deleteAccount();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    emit(const AuthLoading());
    try {
      final token = await NotificationRuntime.getToken();
      if (token != null) await _repository.unregisterFcmToken(token);
      NotificationRuntime.clearTokenSync();
      await _repository.signOut();
    } finally {
      emit(const AuthUnauthenticated());
    }
  }
}
