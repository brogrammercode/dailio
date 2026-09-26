import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only HTTP logging for the mobile client.
///
/// Request and response lines intentionally use different ANSI colours. The
/// payload is sanitized because even debug output must not expose access
/// tokens, QR secrets, precise location, or private media references.
class LoggingInterceptor extends Interceptor {
  static const _requestColour = '\x1B[38;5;45m';
  static const _successColour = '\x1B[38;5;82m';
  static const _redirectColour = '\x1B[38;5;75m';
  static const _clientErrorColour = '\x1B[38;5;214m';
  static const _serverErrorColour = '\x1B[38;5;196m';
  static const _networkErrorColour = '\x1B[38;5;201m';
  static const _resetColour = '\x1B[0m';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra['_dailio_request_started_at'] =
          DateTime.now().microsecondsSinceEpoch;
      _write(
        '$_requestColour[${_timeNow()}] : [${options.method}] : '
        '[${safePath(options.uri.toString())}] : '
        '[${safePayload(options.data)}]$_resetColour',
        level: 500,
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final status = response.statusCode ?? 0;
      _write(
        '${_colourForStatus(status)}${_emojiForStatus(status)} : '
        '[${_timeNow()}] : [${_speed(response.requestOptions)}] : '
        '[${response.requestOptions.method}] : [$status] : '
        '[${safePath(response.requestOptions.uri.toString())}] : '
        '[${safePayload(response.data)}]$_resetColour',
        level: status >= 400 ? 900 : 300,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final status = err.response?.statusCode;
      final statusText = status?.toString() ?? _errorStatus(err);
      _write(
        '${_colourForStatus(status)}${_emojiForError(err)} : '
        '[${_timeNow()}] : [${_speed(err.requestOptions)}] : '
        '[${err.requestOptions.method}] : [$statusText] : '
        '[${safePath(err.requestOptions.uri.toString())}] : '
        '[${safePayload(err.response?.data ?? err.message)}]$_resetColour',
        level: 1000,
      );
    }
    handler.next(err);
  }

  static String _timeNow() {
    // Dailio operates in India for this environment. Use an explicit fixed
    // offset so logs remain consistent on emulators/devices configured for a
    // different timezone. India has no daylight-saving transition.
    final now =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)} IST';
  }

  static String _speed(RequestOptions options) {
    final started = options.extra['_dailio_request_started_at'];
    if (started is! int) return '-';
    final elapsed = DateTime.now().microsecondsSinceEpoch - started;
    return '${(elapsed / 1000).round()}ms';
  }

  static String _errorStatus(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'TIMEOUT';
      case DioExceptionType.connectionError:
        return 'NETWORK';
      case DioExceptionType.cancel:
        return 'CANCELLED';
      default:
        return 'ERROR';
    }
  }

  static String _emojiForStatus(int status) {
    if (status >= 200 && status < 300) return '✅';
    if (status >= 300 && status < 400) return '↪️';
    if (status >= 400 && status < 500) return '⚠️';
    if (status >= 500) return '❌';
    return '❔';
  }

  static String _emojiForError(DioException error) {
    if (error.response?.statusCode != null) {
      return _emojiForStatus(error.response!.statusCode!);
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '⏱️';
      case DioExceptionType.cancel:
        return '🛑';
      default:
        return '🌐';
    }
  }

  static String _colourForStatus(int? status) {
    if (status == null) return _networkErrorColour;
    if (status >= 200 && status < 300) return _successColour;
    if (status >= 300 && status < 400) return _redirectColour;
    if (status >= 400 && status < 500) return _clientErrorColour;
    return _serverErrorColour;
  }

  static void _write(String line, {required int level}) {
    developer.log(line, name: 'Dailio.HTTP', level: level);
  }

  /// Exposed for tests and for safe reuse by future client logging.
  static String safePath(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) return path;
    if (uri.queryParameters.isEmpty) return uri.path.isEmpty ? path : uri.path;
    final query = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      query[entry.key] =
          _isSensitiveKey(entry.key) ? '[REDACTED]' : entry.value;
    }
    final pathOnly = uri.path.isEmpty ? '/' : uri.path;
    return '$pathOnly?${Uri(queryParameters: query).query}';
  }

  /// Converts common Dio payload types into short, redacted debug text.
  static String safePayload(dynamic payload) {
    dynamic sanitized;
    if (payload is FormData) {
      sanitized = <String, dynamic>{
        'fields': <String, dynamic>{
          for (final field in payload.fields)
            field.key: _sanitize(field.value, key: field.key),
        },
        'files': [
          for (final file in payload.files)
            '${file.key}: <file ${file.value.filename ?? 'unnamed'}, ${file.value.length} bytes>',
        ],
      };
    } else {
      sanitized = _sanitize(payload);
    }
    try {
      final encoded = sanitized is String ? sanitized : jsonEncode(sanitized);
      if (encoded.length <= 2000) return encoded;
      return '${encoded.substring(0, 2000)}…';
    } catch (_) {
      return '<unserializable ${payload.runtimeType}>';
    }
  }

  static dynamic _sanitize(dynamic value, {String? key}) {
    if (key != null && _isSensitiveKey(key)) return '[REDACTED]';
    if (value == null || value is num || value is bool) return value;
    if (value is String) {
      if (value.length <= 500) return value;
      return '${value.substring(0, 500)}…';
    }
    if (value is List<int>) return '<binary ${value.length} bytes>';
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _sanitize(
            entry.value,
            key: entry.key.toString(),
          ),
      };
    }
    if (value is Iterable) return value.map(_sanitize).toList();
    return value.toString();
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    const fragments = <String>[
      'authorization',
      'password',
      'secret',
      'token',
      'apikey',
      'signature',
      'selfie',
      'latitude',
      'longitude',
      'preciselocation',
      'deviceinfo',
      'signedurl',
      'presigned',
      'rawqr',
    ];
    return fragments.any(normalized.contains);
  }
}
