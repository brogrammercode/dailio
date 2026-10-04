import 'package:dailio/core/error/app_exception.dart';
import 'package:dailio/features/auth/controllers/auth_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Google sign-in gives a specific message for Android configuration error',
      () {
    expect(
      googleSignInErrorMessage(
        PlatformException(code: 'sign_in_failed', message: '10'),
      ),
      contains('signing SHA-1'),
    );
  });

  test('Google sign-in does not expose unexpected platform details', () {
    const privateDetail = 'private device diagnostic';
    final message = googleSignInErrorMessage(
      PlatformException(code: 'unexpected', message: privateDetail),
    );
    expect(message, isNot(contains(privateDetail)));
    expect(message, contains('Google sign-in failed'));
  });

  test('profile and account errors retain safe API messages and action context',
      () {
    expect(
      accountErrorMessage(
        const AppException(code: 'FORBIDDEN', message: 'Profile not editable.'),
        'Could not update your profile.',
      ),
      'Profile not editable.',
    );
    expect(
      accountErrorMessage(
        PlatformException(code: 'internal', message: 'private trace'),
        'Could not delete your account.',
      ),
      'Could not delete your account.',
    );
  });
}
