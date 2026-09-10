import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/controllers/auth_cubit.dart';
import '../../auth/controllers/auth_state.dart';
import '../../auth/models/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  File? _pickedImage;
  bool _isSubmitting = false;

  // Track original values so we can show/hide save buttons
  String _originalName = '';
  String _originalPhone = '';

  bool get _isDirty {
    final nameChanged = _nameCtrl.text.trim() != _originalName;
    final phoneChanged = _phoneCtrl.text.trim() != _originalPhone;
    final avatarChanged = _pickedImage != null;
    return nameChanged || phoneChanged || avatarChanged;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _nameCtrl.addListener(_onFieldChanged);
    _phoneCtrl.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AuthCubit>().state;
      if (state is AuthAuthenticated) {
        _initFromUser(state.user);
      }
    });
  }

  void _initFromUser(UserModel user) {
    _originalName = user.name;
    _originalPhone = user.phone ?? '';
    _nameCtrl.text = _originalName;
    _phoneCtrl.text = _originalPhone;
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.removeListener(_onFieldChanged);
    _phoneCtrl.removeListener(_onFieldChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  void _discardChanges(UserModel user) {
    setState(() {
      _pickedImage = null;
      _initFromUser(user);
    });
  }

  Future<void> _save(UserModel user) async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? avatarBase64;
    if (_pickedImage != null) {
      final bytes = await _pickedImage!.readAsBytes();
      final ext = _pickedImage!.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      avatarBase64 = 'data:$mime;base64,${base64Encode(bytes)}';
    }

    try {
      final cubit = context.read<AuthCubit>();
      await cubit.updateProfile(
            name: name != _originalName ? name : null,
            phone: phone != _originalPhone ? phone : null,
            avatarBase64: avatarBase64,
          );
      if (mounted) {
        // Re-sync originals so dirty detection resets
        _originalName = name;
        _originalPhone = phone;
        _pickedImage = null;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
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
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) => curr is AuthAuthenticated,
      listener: (context, state) {
        if (state is AuthAuthenticated && _originalName.isEmpty) {
          _initFromUser(state.user);
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final user = state is AuthAuthenticated ? state.user : null;

          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            body: SafeArea(
              child: Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.fromLTRB(
                      24, 16, 24,
                      _isDirty ? 140 : 40,
                    ),
                    children: [
                      // ── Header (consistent with Settings page) ─────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Iconsax.arrow_left, size: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Edit Profile',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                  'Update your identity & contact details',
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
                      const SizedBox(height: 28),

                      // ── Avatar ─────────────────────────────────────────
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _pickedImage != null
                                            ? Colors.orange.shade300
                                            : Colors.grey.shade200,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 44,
                                      backgroundColor:
                                          Colors.orange.shade50,
                                      backgroundImage: _pickedImage != null
                                          ? FileImage(_pickedImage!)
                                          : (user?.avatarUrl != null
                                              ? NetworkImage(user!.avatarUrl!)
                                                  as ImageProvider
                                              : null),
                                      child: (_pickedImage == null &&
                                              user?.avatarUrl == null)
                                          ? Text(
                                              user != null &&
                                                      user.name.isNotEmpty
                                                  ? user.name[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    Colors.orange.shade700,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle),
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor:
                                            Colors.orange.shade700,
                                        child: const Icon(Iconsax.camera,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _pickImage,
                              child: Text(
                                _pickedImage != null
                                    ? 'Photo selected — tap to change'
                                    : 'Change profile photo',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Text('JPG or PNG • Max 5 MB',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Google Account Badge ────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Iconsax.shield_tick,
                                  color: Colors.orange, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Text('Google Verified Account',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.bold)),
                                      SizedBox(width: 4),
                                      Icon(Iconsax.verify,
                                          size: 12,
                                          color: Colors.green),
                                    ],
                                  ),
                                  Text(
                                    user?.email ??
                                        'No email linked',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Iconsax.lock,
                                  size: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Identity Fields ─────────────────────────────────
                      _buildSectionHeader('Identity', 'REQUIRED'),
                      const SizedBox(height: 14),
                      _buildFieldLabel('Full Name'),
                      _buildTextField(
                        controller: _nameCtrl,
                        hint: 'Your full name',
                        icon: Iconsax.user,
                      ),
                      const SizedBox(height: 14),
                      _buildFieldLabel('Phone Number'),
                      _buildTextField(
                        controller: _phoneCtrl,
                        hint: 'e.g. +91 98765 43210',
                        icon: Iconsax.call,
                        keyboardType: TextInputType.phone,
                        suffixWidget: user?.phone != null
                            ? _buildBadge(
                                'Saved', Colors.green.shade50, Colors.green)
                            : null,
                      ),
                      const SizedBox(height: 28),

                      // ── Notification Preferences ────────────────────────
                      _buildSectionHeader(
                          'Notifications & Privacy', null),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose which operational updates are sent to your registered devices.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      _buildNotificationTile(
                        Iconsax.receipt,
                        'Punch confirmation alerts',
                        'Instant receipt on geotagged shifts',
                      ),
                      const SizedBox(height: 8),
                      _buildNotificationTile(
                        Iconsax.user_add,
                        'Join request alerts',
                        'Real-time alerts for new member requests',
                      ),
                      const SizedBox(height: 8),
                      _buildNotificationTile(
                        Iconsax.clock,
                        'Shift & schedule updates',
                        'Roster swaps and time-slot revisions',
                      ),
                    ],
                  ),

                  // ── Save / Discard bar (only when dirty) ────────────────
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
                              onPressed: _isSubmitting
                                  ? null
                                  : () => user != null ? _save(user) : null,
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
                                    : 'Save Profile Changes',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                minimumSize:
                                    const Size(double.infinity, 0),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => user != null
                                      ? _discardChanges(user)
                                      : null,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                minimumSize:
                                    const Size(double.infinity, 0),
                                side: BorderSide(
                                    color: Colors.grey.shade300),
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
        },
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String? badge) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.3)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(badge,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold)),
          ),
        ]
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixWidget,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: Icon(icon, size: 16, color: Colors.grey),
        suffixIcon: suffixWidget,
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
          borderSide:
              BorderSide(color: Colors.orange.shade400, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color bg, Color fg) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.verify, size: 10, color: fg),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: fg,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(
      IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.orange.shade700, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Iconsax.arrow_right_3,
              size: 14, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
