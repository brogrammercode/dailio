import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStorage {
  final SharedPreferences _prefs;

  PreferencesStorage(this._prefs);

  static const _organizationIdKey = 'active_organization_id';
  static const _branchIdKey = 'active_branch_id';
  static const _organizationNameKey = 'active_organization_name';
  static const _branchNameKey = 'active_branch_name';
  static const _roleSystemKey = 'active_role_system_key';
  static const _permissionsKey = 'active_permissions';

  String? get activeOrganizationId => _prefs.getString(_organizationIdKey);
  String? get activeBranchId => _prefs.getString(_branchIdKey);
  String? get activeOrganizationName => _prefs.getString(_organizationNameKey);
  String? get activeBranchName => _prefs.getString(_branchNameKey);
  String? get activeRoleSystemKey => _prefs.getString(_roleSystemKey);
  List<String> get activePermissions {
    try {
      final decoded = jsonDecode(_prefs.getString(_permissionsKey) ?? '[]');
      return decoded is List ? decoded.cast<String>() : const [];
    } catch (_) {
      return const [];
    }
  }
  bool get canReviewPayments => activePermissions.contains('ALL') || activePermissions.contains('PAYMENT_REQUEST_REVIEW');

  Future<void> setActiveContext({
    required String organizationId,
    required String branchId,
    String? organizationName,
    String? branchName,
    String? roleSystemKey,
    List<String>? permissions,
  }) async {
    await _prefs.setString(_organizationIdKey, organizationId);
    await _prefs.setString(_branchIdKey, branchId);
    if (organizationName != null) {
      await _prefs.setString(_organizationNameKey, organizationName);
    }
    if (branchName != null) await _prefs.setString(_branchNameKey, branchName);
    if (roleSystemKey != null) await _prefs.setString(_roleSystemKey, roleSystemKey);
    if (permissions != null) await _prefs.setString(_permissionsKey, jsonEncode(permissions));
  }

  Future<void> clearContext() async {
    await _prefs.remove(_organizationIdKey);
    await _prefs.remove(_branchIdKey);
    await _prefs.remove(_organizationNameKey);
    await _prefs.remove(_branchNameKey);
    await _prefs.remove(_roleSystemKey);
    await _prefs.remove(_permissionsKey);
  }

  // --- Hardware Settings ---
  static const _pushAlertsKey = 'push_alerts_enabled';
  static const _biometricKey = 'biometric_enabled';

  bool get pushAlertsEnabled => _prefs.getBool(_pushAlertsKey) ?? true;
  Future<void> setPushAlerts(bool value) =>
      _prefs.setBool(_pushAlertsKey, value);

  bool get biometricEnabled => _prefs.getBool(_biometricKey) ?? false;
  Future<void> setBiometric(bool value) => _prefs.setBool(_biometricKey, value);
}
