import 'package:flutter_test/flutter_test.dart';

import 'package:dailio/core/network/interceptors/logging_interceptor.dart';

void main() {
  test('logs only the API path and redacts sensitive query values', () {
    expect(
      LoggingInterceptor.safePath(
        'http://192.168.1.5:3000/api/v1/invites/resolve?token=private&mode=join',
      ),
      '/api/v1/invites/resolve?token=%5BREDACTED%5D&mode=join',
    );
  });

  test('redacts credentials, QR secrets, and precise location from payloads',
      () {
    final payload = LoggingInterceptor.safePayload({
      'email': 'harsh@example.com',
      'accessToken': 'do-not-print',
      'qrToken': 'do-not-print',
      'latitude': 19.123,
      'longitude': 72.456,
    });

    expect(payload, contains('harsh@example.com'));
    expect(payload, isNot(contains('do-not-print')));
    expect(payload, isNot(contains('19.123')));
    expect(payload, isNot(contains('72.456')));
    expect(payload, contains('[REDACTED]'));
  });
}
