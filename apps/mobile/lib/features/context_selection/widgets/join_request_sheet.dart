import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../models/branch_discovery_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/controllers/auth_repository.dart';

class JoinRequestSheet extends StatefulWidget {
  final BranchDiscoveryModel branch;
  final Function(String? message, String? emergencyName, String? emergencyPhone,
      String? dob) onSubmit;

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
  void initState() {
    super.initState();
    // Pre-fill existing user info if any (can be implemented later)
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final msg = _messageController.text.trim();
      final eName = _emergencyNameController.text.trim();
      final ePhone = _emergencyPhoneController.text.trim();
      final dob = _dobController.text.trim();

      // Update global profile first if any field is filled
      if (eName.isNotEmpty || ePhone.isNotEmpty || dob.isNotEmpty) {
        final authRepo = context.read<AuthRepository>();
        await authRepo.updateProfile(
          emergencyContactName: eName.isNotEmpty ? eName : null,
          emergencyContactPhone: ePhone.isNotEmpty ? ePhone : null,
          dateOfBirth: dob.isNotEmpty ? dob : null,
        );
      }

      await widget.onSubmit(
        msg.isNotEmpty ? msg : null,
        eName.isNotEmpty ? eName : null,
        ePhone.isNotEmpty ? ePhone : null,
        dob.isNotEmpty ? dob : null,
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request sent successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
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
      setState(() {
        _dobController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Join ${widget.branch.name}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete your profile to join this branch. Your emergency contact and DOB will be saved to your profile securely.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _messageController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Message (Optional)',
                  hintText: 'Introduce yourself to the manager',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.message),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyNameController,
                decoration: InputDecoration(
                  labelText: 'Emergency Contact Name (Optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.user),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Emergency Contact Phone (Optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.call),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Date of Birth (Optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.calendar),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF92400E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Request',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
