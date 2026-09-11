import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStorage {
  final SharedPreferences _prefs;

  PreferencesStorage(this._prefs);

  static const _organizationIdKey = 'active_organization_id';
  static const _branchIdKey = 'active_branch_id';
  static const _organizationNameKey = 'active_organization_name';
  static const _branchNameKey = 'active_branch_name';

  String? get activeOrganizationId => _prefs.getString(_organizationIdKey);
  String? get activeBranchId => _prefs.getString(_branchIdKey);
  String? get activeOrganizationName => _prefs.getString(_organizationNameKey);
  String? get activeBranchName => _prefs.getString(_branchNameKey);

  Future<void> setActiveContext({
    required String organizationId,
    required String branchId,
    String? organizationName,
    String? branchName,
  }) async {
    await _prefs.setString(_organizationIdKey, organizationId);
    await _prefs.setString(_branchIdKey, branchId);
    if (organizationName != null)
      await _prefs.setString(_organizationNameKey, organizationName);
    if (branchName != null) await _prefs.setString(_branchNameKey, branchName);
  }

  Future<void> clearContext() async {
    await _prefs.remove(_organizationIdKey);
    await _prefs.remove(_branchIdKey);
    await _prefs.remove(_organizationNameKey);
    await _prefs.remove(_branchNameKey);
  }
}
