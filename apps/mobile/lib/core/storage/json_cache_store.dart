import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef JsonCacheDecoder<T> = T Function(dynamic payload);
typedef JsonCacheFetcher = Future<dynamic> Function();

class JsonCacheRecord {
  final int version;
  final DateTime savedAt;
  final String scope;
  final dynamic payload;

  const JsonCacheRecord({
    required this.version,
    required this.savedAt,
    required this.scope,
    required this.payload,
  });

  factory JsonCacheRecord.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    if (payload == null) {
      throw const FormatException('Cache payload is missing');
    }
    final savedAt = DateTime.tryParse(json['saved_at']?.toString() ?? '');
    final scope = json['scope']?.toString();
    if (savedAt == null || scope == null || scope.isEmpty) {
      throw const FormatException('Cache metadata is invalid');
    }
    return JsonCacheRecord(
      version: (json['version'] as num?)?.toInt() ?? 1,
      savedAt: savedAt,
      scope: scope,
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'saved_at': savedAt.toUtc().toIso8601String(),
        'scope': scope,
        'payload': payload,
      };
}

/// Private JSON-file cache for server-confirmed read models.
///
/// This store intentionally has no token or authorization behavior. It only
/// persists JSON payloads supplied by repositories after successful GETs.
class JsonCacheStore extends ChangeNotifier {
  static const int currentVersion = 1;
  static const String _directoryName = 'dailio_json_cache';

  final Set<String> _refreshing = <String>{};
  final Future<Directory> Function()? _directoryProvider;
  Future<Directory>? _directoryFuture;
  String? _userId;

  JsonCacheStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider;

  void setUserId(String? userId) {
    _userId = userId;
  }

  String scopedKey(String key) => 'user:${_userId ?? 'anonymous'}|$key';

  Future<Directory> _directory() {
    return _directoryFuture ??=
        (_directoryProvider?.call() ?? getApplicationDocumentsDirectory()).then(
      (root) async {
        final directory = Directory('${root.path}/$_directoryName');
        if (!await directory.exists()) await directory.create(recursive: true);
        return directory;
      },
    );
  }

  String _fileName(String key) {
    final encoded = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    return encoded;
  }

  Future<File> _fileFor(String key) async {
    final directory = await _directory();
    return File('${directory.path}/${_fileName(key)}.json');
  }

  Future<JsonCacheRecord?> read(String key) async {
    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return JsonCacheRecord.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String key,
    dynamic payload, {
    required String scope,
  }) async {
    try {
      jsonEncode(payload);
      final file = await _fileFor(key);
      final temporary = File('${file.path}.tmp');
      final record = JsonCacheRecord(
        version: currentVersion,
        savedAt: DateTime.now().toUtc(),
        scope: scope,
        payload: payload,
      );
      await temporary.writeAsString(jsonEncode(record.toJson()), flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
      notifyListeners();
    } catch (_) {
      // Cache failure must never fail or delay a server-confirmed operation.
    }
  }

  /// Returns cached data immediately when available and refreshes it once in
  /// the background. The callback receives a fresh server response.
  Future<T> load<T>({
    required String key,
    required String scope,
    required JsonCacheDecoder<T> decode,
    required JsonCacheFetcher fetch,
    dynamic Function(dynamic payload)? cacheTransform,
    void Function(T freshValue)? onFresh,
  }) async {
    final cached = await read(key);
    if (cached != null && cached.version == currentVersion) {
      final value = decode(cached.payload);
      _refreshInBackground(
        key: key,
        scope: scope,
        decode: decode,
        fetch: fetch,
        cacheTransform: cacheTransform,
        onFresh: onFresh,
      );
      return value;
    }

    final payload = await fetch();
    await write(key, cacheTransform?.call(payload) ?? payload, scope: scope);
    return decode(payload);
  }

  void _refreshInBackground<T>({
    required String key,
    required String scope,
    required JsonCacheDecoder<T> decode,
    required JsonCacheFetcher fetch,
    dynamic Function(dynamic payload)? cacheTransform,
    void Function(T freshValue)? onFresh,
  }) {
    if (!_refreshing.add(key)) return;
    unawaited(() async {
      try {
        final payload = await fetch();
        await write(key, cacheTransform?.call(payload) ?? payload,
            scope: scope);
        onFresh?.call(decode(payload));
      } catch (_) {
        // Stale data remains useful when the network refresh is unavailable.
      } finally {
        _refreshing.remove(key);
      }
    }());
  }

  Future<void> clearScope(String scope) async {
    try {
      final directory = await _directory();
      if (!await directory.exists()) return;
      await for (final entity in directory.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final decoded = jsonDecode(await entity.readAsString());
          if (decoded is Map && decoded['scope']?.toString() == scope) {
            await entity.delete();
          }
        } catch (_) {
          // A corrupt cache file is safe to remove during scoped cleanup.
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearKey(String key) async {
    try {
      final file = await _fileFor(key);
      if (await file.exists()) await file.delete();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      final directory = await _directory();
      if (await directory.exists()) await directory.delete(recursive: true);
      _directoryFuture = null;
      _refreshing.clear();
      notifyListeners();
    } catch (_) {}
  }
}
