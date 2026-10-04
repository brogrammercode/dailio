import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/dailio_onboarding_widgets.dart';
import '../../auth/controllers/auth_repository.dart';
import '../models/branch_discovery_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class JoinRequestSheet extends StatefulWidget {
  final BranchDiscoveryModel branch;
  final Future<void> Function(String? message, String? emergencyName,
      String? emergencyPhone, String? dob) onSubmit;

  const JoinRequestSheet({
    super.key,
    required this.branch,
    required this.onSubmit,
  });

  @override
  State<JoinRequestSheet> createState() => _JoinRequestSheetState();
}

class _JoinRequestSheetState extends State<JoinRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final message = _messageController.text.trim();
      final emergencyName = _emergencyNameController.text.trim();
      final emergencyPhone = _emergencyPhoneController.text.trim();
      final dob = _dobController.text.trim();
      if (emergencyName.isNotEmpty ||
          emergencyPhone.isNotEmpty ||
          dob.isNotEmpty) {
        await context.read<AuthRepository>().updateProfile(
              emergencyContactName:
                  emergencyName.isEmpty ? null : emergencyName,
              emergencyContactPhone:
                  emergencyPhone.isEmpty ? null : emergencyPhone,
              dateOfBirth: dob.isEmpty ? null : dob,
            );
      }
      await widget.onSubmit(
        message.isEmpty ? null : message,
        emergencyName.isEmpty ? null : emergencyName,
        emergencyPhone.isEmpty ? null : emergencyPhone,
        dob.isEmpty ? null : dob,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request sent successfully.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send your join request.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() =>
          _dobController.text = picked.toIso8601String().split('T').first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.r, 10.r, 16.r, 16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 34.r,
                    height: 4.r,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD5D5D5),
                        borderRadius: BorderRadius.circular(99.r)),
                  ),
                ),
                SizedBox(height: 16.r),
                Text('Join ${widget.branch.name}',
                    style:
                        TextStyle(fontSize: 18.r, fontWeight: FontWeight.w800)),
                SizedBox(height: 4.r),
                Text('Add only the information needed for admission.',
                    style: TextStyle(fontSize: 12.r, color: Color(0xFF858585))),
                SizedBox(height: 18.r),
                TextFormField(
                  controller: _messageController,
                  maxLines: 2,
                  decoration: dailioOnboardingInput(
                      'Message (optional)', Iconsax.message_text),
                ),
                SizedBox(height: 10.r),
                TextFormField(
                  controller: _emergencyNameController,
                  decoration: dailioOnboardingInput(
                      'Emergency contact name', Iconsax.user),
                ),
                SizedBox(height: 10.r),
                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: dailioOnboardingInput(
                      'Emergency contact phone', Iconsax.call),
                ),
                SizedBox(height: 10.r),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: dailioOnboardingInput(
                    'Date of birth',
                    Iconsax.calendar_1,
                    suffixIcon: Icon(Iconsax.arrow_down_1, size: 17.r),
                  ),
                ),
                SizedBox(height: 16.r),
                DailioOnboardingButton(
                  label: 'Send join request',
                  icon: Iconsax.send_1,
                  loading: _isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
