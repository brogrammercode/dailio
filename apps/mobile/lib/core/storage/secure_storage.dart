import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage(this._storage);

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<String?> getAccessToken() => _read(_accessTokenKey);
  Future<String?> getRefreshToken() => _read(_refreshTokenKey);

  /// Android Keystore data can become undecryptable after an app restore,
  /// device security change, or a release-build reinstall. In that case the
  /// only safe recovery is to discard the unusable session and start signed
  /// out. Never allow corrupted token storage to prevent the app from booting.
  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      await _resetAfterStorageError();
      return null;
    }
  }

  Future<void> saveTokens(
      {required String access, required String refresh}) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  Future<void> clearTokens() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      // The Android plugin may already have reset the corrupted store. A
      // failed cleanup must never block logout or application startup.
    }
  }

  Future<void> _resetAfterStorageError() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Best effort: AndroidOptions(resetOnError: true) also resets the store.
    }
  }
}
