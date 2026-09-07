import 'package:dio/dio.dart';

import '../../storage/preferences_storage.dart';

class TenantInterceptor extends Interceptor {
  final PreferencesStorage _preferencesStorage;

  TenantInterceptor(this._preferencesStorage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final organizationId = _preferencesStorage.activeOrganizationId;
    final branchId = _preferencesStorage.activeBranchId;
    if (organizationId != null) {
      options.headers['X-Organization-Id'] = organizationId;
    }
    if (branchId != null) options.headers['X-Location-Id'] = branchId;
    handler.next(options);
  }
}
