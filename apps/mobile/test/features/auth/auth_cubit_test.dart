import 'package:dailio/core/error/app_exception.dart';
import 'package:dailio/core/notifications/notification_runtime.dart';
import 'package:dailio/features/auth/controllers/auth_cubit.dart';
import 'package:dailio/features/auth/controllers/auth_repository.dart';
import 'package:dailio/features/auth/controllers/auth_state.dart';
import 'package:dailio/features/auth/models/auth_tokens_model.dart';
import 'package:dailio/features/auth/models/user_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

// ignore: avoid_implementing_value_types
class MockGoogleAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleAuthentication extends Mock
    implements GoogleSignInAuthentication {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userB = UserModel(
    id: 'user-b',
    name: 'Second Account',
    status: 'ACTIVE',
  );
  const tokens = AuthTokensModel(
    accessToken: 'test-access-b',
    refreshToken: 'test-refresh-b',
  );

  late MockAuthRepository repository;
  late MockGoogleSignIn google;
  late AuthCubit cubit;

  GoogleSignInAccount accountWithToken(String? idToken) {
    final account = MockGoogleAccount();
    final authentication = MockGoogleAuthentication();
    when(() => authentication.idToken).thenReturn(idToken);
    when(() => account.authentication).thenAnswer((_) async => authentication);
    return account;
  }

  setUp(() {
    repository = MockAuthRepository();
    google = MockGoogleSignIn();
    when(() => google.signOut()).thenAnswer((_) async => null);
    when(() => repository.signOut()).thenAnswer((_) async {});
    cubit = AuthCubit(repository, googleSignIn: google);
  });

  tearDown(() async {
    NotificationRuntime.clearTokenSync();
    await cubit.close();
  });

  test(
      'explicit login clears the cached account before authenticating account B',
      () async {
    final previousAccount = accountWithToken('previous-account-token');
    final selectedAccount = accountWithToken('selected-account-token');
    var cachedAccount = previousAccount;
    when(() => google.signOut()).thenAnswer((_) async {
      cachedAccount = selectedAccount;
      return null;
    });
    when(() => google.signIn()).thenAnswer((_) async => cachedAccount);
    when(() => repository.signInWithGoogle('selected-account-token'))
        .thenAnswer((_) async => (tokens: tokens, user: userB));

    await cubit.signInWithGoogle();

    expect(cubit.state, isA<AuthAuthenticated>());
    expect((cubit.state as AuthAuthenticated).user.id, 'user-b');
    verifyInOrder([
      () => google.signOut(),
      () => google.signIn(),
      () => repository.signInWithGoogle('selected-account-token'),
    ]);
    verifyNever(() => repository.signInWithGoogle('previous-account-token'));
    verifyNever(() => google.disconnect());
  });

  test('cancelling the chooser stays signed out without using the old account',
      () async {
    when(() => google.signIn()).thenAnswer((_) async => null);

    await cubit.signInWithGoogle();

    expect(cubit.state, isA<AuthUnauthenticated>());
    verifyInOrder([() => google.signOut(), () => google.signIn()]);
    verifyNever(() => repository.signInWithGoogle(any()));
  });

  test('a failed backend login can retry with a different Google account',
      () async {
    final accountA = accountWithToken('account-a-token');
    final accountB = accountWithToken('account-b-token');
    var attempt = 0;
    when(() => google.signIn())
        .thenAnswer((_) async => ++attempt == 1 ? accountA : accountB);
    when(() => repository.signInWithGoogle('account-a-token')).thenThrow(
      const AppException(code: 'UNAVAILABLE', message: 'Please try again.'),
    );
    when(() => repository.signInWithGoogle('account-b-token'))
        .thenAnswer((_) async => (tokens: tokens, user: userB));

    await cubit.signInWithGoogle();
    expect(cubit.state, isA<AuthError>());
    await cubit.signInWithGoogle();

    expect((cubit.state as AuthAuthenticated).user.id, 'user-b');
    verifyInOrder([
      () => google.signOut(),
      () => google.signIn(),
      () => repository.signInWithGoogle('account-a-token'),
      () => google.signOut(),
      () => google.signIn(),
      () => repository.signInWithGoogle('account-b-token'),
    ]);
  });

  test('a failed Google reset cannot authenticate the cached account',
      () async {
    when(() => google.signOut()).thenThrow(
      PlatformException(code: 'reset_failed', message: 'private diagnostic'),
    );

    await cubit.signInWithGoogle();

    expect(cubit.state, isA<AuthError>());
    expect((cubit.state as AuthError).message, isNot(contains('private')));
    verifyNever(() => google.signIn());
    verifyNever(() => repository.signInWithGoogle(any()));
  });

  test('missing Google ID token never reaches the backend login', () async {
    when(() => google.signIn()).thenAnswer((_) async => accountWithToken(null));

    await cubit.signInWithGoogle();

    expect(cubit.state, isA<AuthError>());
    verifyNever(() => repository.signInWithGoogle(any()));
  });

  test('logout clears both application and Google sessions', () async {
    await cubit.signOut();

    expect(cubit.state, isA<AuthUnauthenticated>());
    verify(() => repository.signOut()).called(1);
    verify(() => google.signOut()).called(1);
    verifyNever(() => google.disconnect());
  });

  test('Google cleanup failure does not prevent application logout', () async {
    when(() => google.signOut())
        .thenThrow(PlatformException(code: 'provider_unavailable'));

    await cubit.signOut();

    expect(cubit.state, isA<AuthUnauthenticated>());
    verify(() => repository.signOut()).called(1);
  });

  test('application logout failure still attempts Google cleanup', () async {
    when(() => repository.signOut()).thenThrow(StateError('storage failure'));

    await expectLater(cubit.signOut(), throwsStateError);

    expect(cubit.state, isA<AuthUnauthenticated>());
    verify(() => google.signOut()).called(1);
  });

  test('restoring a valid session does not reset Google or open its chooser',
      () async {
    when(() => repository.getMe()).thenAnswer((_) async => userB);

    await cubit.checkSession();

    expect((cubit.state as AuthAuthenticated).user.id, 'user-b');
    verifyNever(() => google.signOut());
    verifyNever(() => google.signIn());
  });

  test('account deletion clears the Google selection after backend cleanup',
      () async {
    when(() => repository.deleteAccount()).thenAnswer((_) async {});

    await cubit.deleteAccount();

    expect(cubit.state, isA<AuthUnauthenticated>());
    verifyInOrder([() => repository.deleteAccount(), () => google.signOut()]);
  });

  test('missing Google configuration reports a safe error', () async {
    dotenv.loadFromString(isOptional: true);
    final unconfigured = AuthCubit(repository);
    try {
      await unconfigured.signInWithGoogle();

      expect(unconfigured.state, isA<AuthError>());
      expect((unconfigured.state as AuthError).message,
          'Google sign-in is not configured for this build.');
      verifyNever(() => repository.signInWithGoogle(any()));
    } finally {
      await unconfigured.close();
    }
  });
}
