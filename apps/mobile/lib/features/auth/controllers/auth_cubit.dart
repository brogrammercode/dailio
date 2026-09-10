import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

import 'auth_repository.dart';
import 'auth_state.dart';

@injectable
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(const AuthInitial());

  Future<void> checkSession() async {
    emit(const AuthLoading());
    try {
      final user = await _repository.getMe();
      if (user != null && user.isActive) {
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
  }) async {
    try {
      final updated = await _repository.updateProfile(
        name: name,
        phone: phone,
        avatarBase64: avatarBase64,
      );
      emit(AuthAuthenticated(updated));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    emit(const AuthLoading());
    try {
      await _repository.signOut();
    } finally {
      emit(const AuthUnauthenticated());
    }
  }
}
