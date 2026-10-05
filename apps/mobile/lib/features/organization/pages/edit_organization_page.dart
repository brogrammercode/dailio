import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../controllers/organization_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class EditOrganizationPage extends StatefulWidget {
  const EditOrganizationPage({super.key});

  @override
  State<EditOrganizationPage> createState() => _EditOrganizationPageState();
}

class _EditOrganizationPageState extends State<EditOrganizationPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _organization;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  String _currency = 'INR';
  String _timezone = 'Asia/Kolkata';
  String _organizationType = 'OTHER';

  File? _pickedLogo;
  bool _isSubmitting = false;

  // Originals for dirty tracking
  String _originalName = '';
  String _originalEmail = '';
  String _originalPhone = '';
  String _originalCurrency = 'INR';
  String _originalTimezone = 'Asia/Kolkata';
  String _originalOrganizationType = 'OTHER';

  bool get _isDirty {
    return _nameCtrl.text.trim() != _originalName ||
        _emailCtrl.text.trim() != _originalEmail ||
        _phoneCtrl.text.trim() != _originalPhone ||
        _currency != _originalCurrency ||
        _timezone != _originalTimezone ||
        _organizationType != _originalOrganizationType ||
        _pickedLogo != null;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();

    _nameCtrl.addListener(_onFieldChanged);
    _emailCtrl.addListener(_onFieldChanged);
    _phoneCtrl.addListener(_onFieldChanged);

    _fetchOrganization();
  }

  Future<void> _fetchOrganization() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = context.read<PreferencesStorage>();
      final orgId = prefs.activeOrganizationId;

      if (orgId == null) {
        throw Exception('No active organization selected.');
      }

      final repo = context.read<OrganizationRepository>();
      final org = await repo.getOrganizationById(orgId);

      _initData(org);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initData(Map<String, dynamic> org) {
    _organization = org;
    _originalName = org['name'] ?? '';
    _originalEmail = org['email'] ?? '';
    _originalPhone = org['phone'] ?? '';
    _originalCurrency = org['currency'] ?? 'INR';
    _originalTimezone = org['timezone'] ?? 'Asia/Kolkata';
    _originalOrganizationType = org['type']?.toString() ?? 'OTHER';

    _nameCtrl.text = _originalName;
    _emailCtrl.text = _originalEmail;
    _phoneCtrl.text = _originalPhone;
    _currency = _originalCurrency;
    _timezone = _originalTimezone;
    _organizationType = _originalOrganizationType;
    _pickedLogo = null;
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.removeListener(_onFieldChanged);
    _emailCtrl.removeListener(_onFieldChanged);
    _phoneCtrl.removeListener(_onFieldChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800.r,
      maxHeight: 800.r,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedLogo = File(picked.path));
    }
  }

  void _discardChanges() {
    setState(() {
      if (_organization != null) {
        _initData(_organization!);
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization name cannot be empty.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = context.read<OrganizationRepository>();
      final prefs = context.read<PreferencesStorage>();
      final orgId = prefs.activeOrganizationId!;

      final data = <String, dynamic>{};
      if (name != _originalName) data['name'] = name;
      if (_emailCtrl.text.trim() != _originalEmail) {
        data['email'] = _emailCtrl.text.trim();
      }
      if (_phoneCtrl.text.trim() != _originalPhone) {
        data['phone'] = _phoneCtrl.text.trim();
      }
      if (_currency != _originalCurrency) data['currency'] = _currency;
      if (_timezone != _originalTimezone) data['timezone'] = _timezone;
      if (_organizationType != _originalOrganizationType) {
        data['type'] = _organizationType;
      }

      if (_pickedLogo != null) {
        final bytes = await _pickedLogo!.readAsBytes();
        final ext = _pickedLogo!.path.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        data['logo_base64'] = 'data:$mime;base64,${base64Encode(bytes)}';
      }

      final updatedOrg = await repo.updateOrganization(orgId, data);

      // Keep the active context in sync so feature-gated modules (for example
      // Meals for food-service organizations) appear immediately after save.
      final branchId = prefs.activeBranchId;
      if (branchId != null) {
        String? roleSystemKey = prefs.activeRoleSystemKey;
        List<String> permissions = prefs.activePermissions;
        String? branchName = prefs.activeBranchName;
        String? branchTimezone = prefs.activeBranchTimezone;
        try {
          final organizations = await repo.getMyOrganizations();
          final entry = organizations
              .where((item) => item['organization']?['id'] == orgId)
              .firstOrNull;
          final memberships = entry?['location_memberships'];
          if (memberships is List) {
            for (final rawMembership in memberships) {
              if (rawMembership is! Map) continue;
              final location = rawMembership['location'];
              if (location is! Map || location['id']?.toString() != branchId) {
                continue;
              }
              final role = rawMembership['role'];
              final roleMap = role is Map
                  ? Map<String, dynamic>.from(role)
                  : <String, dynamic>{};
              final rawPermissions = roleMap['permissions'];
              if (rawPermissions is List) {
                permissions = rawPermissions
                    .map((permission) => permission.toString())
                    .toList();
              }
              roleSystemKey = roleMap['system_key']?.toString();
              branchName = location['name']?.toString();
              branchTimezone = location['timezone']?.toString();
              break;
            }
          }
        } catch (_) {
          // The organization update is already complete; retain the current
          // context if the optional membership refresh is unavailable.
        }
        await prefs.setActiveContext(
          organizationId: orgId,
          branchId: branchId,
          organizationName: name,
          organizationType: updatedOrg['type']?.toString(),
          branchName: branchName,
          branchTimezone: branchTimezone,
          roleSystemKey: roleSystemKey,
          permissions: permissions,
        );
      }

      if (mounted) {
        _initData(updatedOrg);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Organization updated successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Reload organization',
          ),
        ],
        onMenuSelected: (_) => _fetchOrganization(),
      ),
      body: SafeArea(
        child: _isLoading
            ? ShimmerLoader.settingsForm()
            : _errorMessage != null
                ? _buildErrorState()
                : Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.fromLTRB(
                          24.r,
                          16.r,
                          24.r,
                          _isDirty ? 140.r : 40.r,
                        ),
                        children: [
                          //  Logo Section
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60.r,
                                  height: 60.r,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                    image: _pickedLogo != null
                                        ? DecorationImage(
                                            image: FileImage(_pickedLogo!),
                                            fit: BoxFit.cover,
                                          )
                                        : (_organization?['logo_url'] != null
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                    _organization!['logo_url']),
                                                fit: BoxFit.cover,
                                              )
                                            : null),
                                  ),
                                  child: (_pickedLogo == null &&
                                          _organization?['logo_url'] == null)
                                      ? const Icon(Iconsax.image,
                                          color: Colors.grey)
                                      : null,
                                ),
                                SizedBox(width: 16.r),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Organization Logo',
                                          style: TextStyle(
                                              fontSize: 14.r,
                                              fontWeight: FontWeight.bold)),
                                      Text('JPG/PNG up to 2MB',
                                          style: TextStyle(
                                              fontSize: 11.r,
                                              color: Colors.grey)),
                                      SizedBox(height: 4.r),
                                      Row(
                                        children: [
                                          Icon(Iconsax.verify,
                                              size: 12.r, color: Colors.green),
                                          SizedBox(width: 4.r),
                                          Text('512 x 512 Recommended',
                                              style: TextStyle(
                                                  fontSize: 10.r,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickLogo,
                                  icon: Icon(Iconsax.cloud_plus, size: 14.r),
                                  label: Text(
                                      _organization?['logo_url'] != null ||
                                              _pickedLogo != null
                                          ? 'Replace'
                                          : 'Upload',
                                      style: TextStyle(
                                          color: Colors.black, fontSize: 12.r)),
                                  style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12.r),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.r))),
                                )
                              ],
                            ),
                          ),
                          SizedBox(height: 28.r),

                          //  Form Fields
                          _buildFormSection(
                            title: 'Organization Legal / Brand Name',
                            badge: 'REQUIRED',
                            badgeColor: Colors.orange.shade50,
                            badgeTextColor: Colors.orange.shade800,
                            child: _buildTextField(
                              controller: _nameCtrl,
                              hint: 'E.g. Resolution Fitness',
                              icon: Iconsax.building_4,
                            ),
                          ),
                          _buildFormSection(
                            title: 'Public Workspace URL',
                            badge: 'Auto-generated',
                            badgeIcon: Iconsax.link,
                            badgeColor: Colors.grey.shade100,
                            badgeTextColor: Colors.grey.shade600,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14.r, vertical: 12.r),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10.r),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Text('dailio.app/',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13.r)),
                                      Expanded(
                                        child: Text(
                                          _organization?['slug'] ?? '',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.r),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8.r),
                                Text(
                                    'Used for member invites & public references.',
                                    style: TextStyle(
                                        fontSize: 11.r, color: Colors.grey)),
                              ],
                            ),
                          ),
                          _buildFormSection(
                            title: 'Organization Type',
                            badge: 'FEATURES',
                            badgeColor: Colors.orange.shade50,
                            badgeTextColor: Colors.orange.shade800,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DailioPickerField<String>(
                                  key: ValueKey(_organizationType),
                                  initialValue: _organizationType,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Iconsax.category_2,
                                        size: 16.r, color: Colors.grey),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14.r, vertical: 13.r),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                      borderSide: BorderSide(
                                          color: Colors.orange.shade400,
                                          width: 1.5.r),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'GYM', child: Text('Gym')),
                                    DropdownMenuItem(
                                        value: 'FOOD_SERVICE',
                                        child: Text('Mess / cafeteria')),
                                    DropdownMenuItem(
                                        value: 'COACHING',
                                        child: Text('Coaching')),
                                    DropdownMenuItem(
                                        value: 'CLINIC', child: Text('Clinic')),
                                    DropdownMenuItem(
                                        value: 'OTHER', child: Text('Other')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _organizationType = value);
                                    }
                                  },
                                ),
                                SizedBox(height: 7.r),
                                Text(
                                  'Food-service organizations unlock meal slots, serving records, and meal frequency tools.',
                                  style: TextStyle(
                                      fontSize: 11.r, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          _buildFormSection(
                            title: 'Official Contact Email',
                            child: _buildTextField(
                              controller: _emailCtrl,
                              hint: 'admin@yourgym.com',
                              icon: Iconsax.sms,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          _buildFormSection(
                            title: 'Official Contact Phone',
                            child: _buildTextField(
                              controller: _phoneCtrl,
                              hint: '+1 234 567 890',
                              icon: Iconsax.call,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          _buildFormSection(
                            title: 'Default Currency',
                            child: _buildDropdownField(
                              value: _currency,
                              icon: Iconsax.money_2,
                              items: const [
                                'INR',
                                'USD',
                                'EUR',
                                'GBP',
                                'AUD',
                                'CAD'
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _currency = val);
                                }
                              },
                            ),
                          ),
                          _buildFormSection(
                            title: 'Default Timezone',
                            child: _buildDropdownField(
                              value: _timezone,
                              icon: Iconsax.clock,
                              items: const [
                                'Asia/Kolkata',
                                'America/New_York',
                                'Europe/London',
                                'Australia/Sydney',
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _timezone = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      //  Save / Discard bar (only when dirty)
                      if (_isDirty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding:
                                EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 28.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 16.r,
                                  offset: Offset(0, (-4).r),
                                )
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _isSubmitting ? null : _save,
                                  icon: _isSubmitting
                                      ? SizedBox(
                                          width: 16.r,
                                          height: 16.r,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.r,
                                              color: Colors.white),
                                        )
                                      : Icon(Iconsax.save_2, size: 16.r),
                                  label: Text(
                                    _isSubmitting
                                        ? 'Saving...'
                                        : 'Save Organization Changes',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.r),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                    padding:
                                        EdgeInsets.symmetric(vertical: 14.r),
                                    minimumSize: const Size(double.infinity, 0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.r)),
                                  ),
                                ),
                                SizedBox(height: 8.r),
                                OutlinedButton(
                                  onPressed:
                                      _isSubmitting ? null : _discardChanges,
                                  style: OutlinedButton.styleFrom(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 14.r),
                                    minimumSize: const Size(double.infinity, 0),
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.r)),
                                  ),
                                  child: Text(
                                    'Discard Changes',
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.r),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  //  Helpers

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.warning_2, size: 48.r, color: Colors.orange),
            SizedBox(height: 16.r),
            Text(
              'Could not load organization',
              style: TextStyle(fontSize: 16.r, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.r),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(fontSize: 13.r, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.r),
            ElevatedButton(
              onPressed: _fetchOrganization,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade800,
                elevation: 0,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
    IconData? badgeIcon,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style:
                      TextStyle(fontSize: 12.r, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.r, vertical: 2.r),
                  decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4.r)),
                  child: Row(
                    children: [
                      if (badgeIcon != null) ...[
                        Icon(badgeIcon, size: 10.r, color: badgeTextColor),
                        SizedBox(width: 4.r)
                      ],
                      Text(badge,
                          style: TextStyle(
                              fontSize: 9.r,
                              color: badgeTextColor,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
            ],
          ),
          SizedBox(height: 10.r),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 13.r),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13.r, color: Colors.grey),
        prefixIcon: Icon(icon, size: 16.r, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 13.r, horizontal: 14.r),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.orange.shade400, width: 1.5.r),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DailioPickerField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 16.r, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 13.r),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFE7E7E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Color(0xFFFF8A00), width: 1.4.r),
        ),
      ),
      onChanged: onChanged,
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: TextStyle(fontSize: 13.r)),
              ))
          .toList(),
    );
  }
}
