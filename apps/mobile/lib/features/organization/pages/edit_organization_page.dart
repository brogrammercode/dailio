import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/organization_repository.dart';

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

  File? _pickedLogo;
  bool _isSubmitting = false;

  // Originals for dirty tracking
  String _originalName = '';
  String _originalEmail = '';
  String _originalPhone = '';
  String _originalCurrency = 'INR';
  String _originalTimezone = 'Asia/Kolkata';

  bool get _isDirty {
    return _nameCtrl.text.trim() != _originalName ||
        _emailCtrl.text.trim() != _originalEmail ||
        _phoneCtrl.text.trim() != _originalPhone ||
        _currency != _originalCurrency ||
        _timezone != _originalTimezone ||
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

    _nameCtrl.text = _originalName;
    _emailCtrl.text = _originalEmail;
    _phoneCtrl.text = _originalPhone;
    _currency = _originalCurrency;
    _timezone = _originalTimezone;
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
      maxWidth: 800,
      maxHeight: 800,
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

      if (_pickedLogo != null) {
        final bytes = await _pickedLogo!.readAsBytes();
        final ext = _pickedLogo!.path.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        data['logo_base64'] = 'data:$mime;base64,${base64Encode(bytes)}';
      }

      final updatedOrg = await repo.updateOrganization(orgId, data);

      // Update the prefs if name changed
      if (name != _originalName) {
        await prefs.setActiveContext(
          organizationId: orgId,
          branchId: prefs.activeBranchId ?? '',
          organizationName: name,
          branchName: prefs.activeBranchName,
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
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: _isLoading
            ? ShimmerLoader.profile()
            : _errorMessage != null
                ? _buildErrorState()
                : Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          16,
                          24,
                          _isDirty ? 140 : 40,
                        ),
                        children: [
                          //  Header 
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child:
                                      const Icon(Iconsax.arrow_left, size: 18),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Edit Organization',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                      'Update organization legal identity & settings',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isDirty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.orange.shade200),
                                  ),
                                  child: Text(
                                    'Unsaved',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          //  Logo Section 
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
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
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Organization Logo',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold)),
                                      const Text('JPG/PNG up to 2MB',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Iconsax.verify,
                                              size: 12, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text('512 x 512 Recommended',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickLogo,
                                  icon:
                                      const Icon(Iconsax.cloud_plus, size: 14),
                                  label: Text(
                                      _organization?['logo_url'] != null ||
                                              _pickedLogo != null
                                          ? 'Replace'
                                          : 'Upload',
                                      style: const TextStyle(
                                          color: Colors.black, fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8))),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('dailio.app/',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13)),
                                      Expanded(
                                        child: Text(
                                          _organization?['slug'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                    'Used for member invites & public references.',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
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
                            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, -4),
                                )
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _isSubmitting ? null : _save,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Icon(Iconsax.save_2, size: 16),
                                  label: Text(
                                    _isSubmitting
                                        ? 'Saving...'
                                        : 'Save Organization Changes',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    minimumSize: const Size(double.infinity, 0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed:
                                      _isSubmitting ? null : _discardChanges,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    minimumSize: const Size(double.infinity, 0),
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text(
                                    'Discard Changes',
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.warning_2, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Could not load organization',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      if (badgeIcon != null) ...[
                        Icon(badgeIcon, size: 10, color: badgeTextColor),
                        const SizedBox(width: 4)
                      ],
                      Text(badge,
                          style: TextStyle(
                              fontSize: 9,
                              color: badgeTextColor,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
            ],
          ),
          const SizedBox(height: 10),
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
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: Icon(icon, size: 16, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.orange.shade400, width: 1.5),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items.contains(value) ? value : items.first,
                isExpanded: true,
                icon: const Icon(Iconsax.arrow_down_1,
                    size: 16, color: Colors.grey),
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                    fontFamily: 'Inter'), // Use your default font family
                onChanged: onChanged,
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

