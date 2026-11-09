import 'package:dailio/features/auth/controllers/auth_cubit.dart';
import 'package:dailio/features/auth/controllers/auth_state.dart';
import 'package:dailio/features/auth/models/user_model.dart';
import 'package:dailio/features/branch/controllers/members_repository.dart';
import 'package:dailio/features/profile/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../support/screenutil_test_app.dart';

class _Members extends Mock implements MembersRepository {}

class _Auth extends Mock implements AuthCubit {}

void main() {
  late _Members members;
  late _Auth auth;
  const owner = UserModel(id: 'owner', name: 'Owner', status: 'ACTIVE');
  final target = {
    'id': 'target-user',
    'name': 'Target Member',
    'phone': '123',
    'status': 'ACTIVE'
  };
  setUp(() {
    members = _Members();
    auth = _Auth();
    when(() => auth.state).thenReturn(const AuthAuthenticated(owner));
    when(() => auth.stream).thenAnswer((_) => const Stream<AuthState>.empty());
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(screenUtilTestApp(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MembersRepository>.value(value: members),
        ],
        child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: const MaterialApp(
              home: ProfilePage(memberId: 'target', branchId: 'branch'),
            )))));
    await tester.pumpAndSettle();
  }

  testWidgets('loads and saves the selected member instead of the owner',
      (tester) async {
    when(() => members.loadProfile('branch', 'target'))
        .thenAnswer((_) async => {
              'data': {'user': target}
            });
    when(() => members.updateProfile('branch', 'target', any()))
        .thenAnswer((_) async => {
              'user': {...target, 'name': 'Updated Member'}
            });
    await open(tester);
    expect(find.text('Target Member'), findsOneWidget);
    expect(find.text('Notifications & Privacy'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Updated Member');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Profile Changes'));
    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();
    verify(() => members.updateProfile(
        'branch', 'target', {'name': 'Updated Member'})).called(1);
    expect((auth.state as AuthAuthenticated).user.id, 'owner');
    expect(find.text('Profile updated successfully!'), findsOneWidget);
  });
  testWidgets('a failed target load shows retry rather than owner fields',
      (tester) async {
    when(() => members.loadProfile('branch', 'target'))
        .thenThrow(Exception('private server detail'));
    await open(tester);
    expect(find.text('Could not load profile. Retry'), findsOneWidget);
    expect(find.text('Owner'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
