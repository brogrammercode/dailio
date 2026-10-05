import 'package:dailio/core/network/api_client.dart';
import 'package:dailio/core/network/interceptors/auth_interceptor.dart';
import 'package:dailio/core/network/interceptors/tenant_interceptor.dart';
import 'package:dailio/core/storage/preferences_storage.dart';
import 'package:dailio/core/storage/secure_storage.dart';
import 'package:dailio/features/meals/pages/meals_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/screenutil_test_app.dart';

Future<void> pumpMeals(
    WidgetTester tester, List<String> permissions, List<String> paths) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = PreferencesStorage(await SharedPreferences.getInstance());
  await prefs.setActiveContext(
    organizationId: 'org-1',
    branchId: 'branch-1',
    branchName: 'Mess A',
    permissions: permissions,
  );
  final client = ApiClient(
    baseUrl: 'https://test.invalid',
    authInterceptor: AuthInterceptor(
      SecureStorage(const FlutterSecureStorage()),
    ),
    tenantInterceptor: TenantInterceptor(prefs),
  );
  client.dio.interceptors.clear();
  client.dio.interceptors
      .add(InterceptorsWrapper(onRequest: (options, handler) {
    paths.add(options.path);
    dynamic data;
    if (options.path.endsWith('/meal-slots')) {
      data = {
        'data': [
          {
            'id': 'breakfast',
            'name': 'Breakfast',
            'code': 'breakfast',
            'starts_at_local': '07:00',
            'ends_at_local': '10:00',
            'is_active': true,
          }
        ]
      };
    } else if (options.path.endsWith('/meal-servings/summary')) {
      data = {
        'data': {
          'from': '2026-09-05',
          'to': '2026-10-04',
          'total': 2,
          'slots': [
            {
              'meal_slot_id': 'breakfast',
              'name': 'Breakfast',
              'code': 'breakfast',
              'count': 2
            }
          ],
        }
      };
    } else if (options.path.endsWith('/meal-servings')) {
      data = {
        'data': [],
        'meta': {'total': 0, 'page': 1, 'limit': 30}
      };
    } else if (options.path.endsWith('/meal-members')) {
      data = {'data': []};
    } else {
      return handler.reject(DioException(
        requestOptions: options,
        error: 'Unexpected request: ${options.path}',
      ));
    }
    handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: data));
  }));
  await tester.pumpWidget(screenUtilTestApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<PreferencesStorage>.value(value: prefs),
      Provider<ApiClient>.value(value: client),
    ],
    child: const MaterialApp(home: MealsPage()),
  )));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('self-only members do not get the operational meal screen',
      (tester) async {
    final paths = <String>[];
    await pumpMeals(tester, ['MEAL_READ_SELF'], paths);
    expect(tester.takeException(), isNull);
    expect(find.text('Meal operations are not enabled for this account.'),
        findsOneWidget);
    expect(find.text('Serve'), findsNothing);
    expect(find.text('Configure'), findsNothing);
    expect(paths.any((path) => path.endsWith('/meal-servings/summary')), isFalse);
  });

  testWidgets('serve-only role does not fetch branch history', (tester) async {
    final paths = <String>[];
    await pumpMeals(tester, ['MEAL_SERVE'], paths);
    expect(tester.takeException(), isNull);
    expect(find.text('Serve'), findsOneWidget);
    expect(find.text('History'), findsNothing);
    expect(paths.any((path) => path.endsWith('/meal-servings')), isFalse);
    expect(
        paths.any((path) => path.endsWith('/meal-servings/summary')), isFalse);
  });
}
