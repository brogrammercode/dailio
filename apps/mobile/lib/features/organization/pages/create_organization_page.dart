import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/route_names.dart';
import '../models/create_organization_models.dart';

class CreateOrganizationPage extends StatefulWidget {
  const CreateOrganizationPage({super.key});

  @override
  State<CreateOrganizationPage> createState() => _CreateOrganizationPageState();
}

class _CreateOrganizationPageState extends State<CreateOrganizationPage> {
  final _formKey = GlobalKey<FormState>();

  String? _logoBase64;
  String _orgName = '';
  String _orgEmail = '';
  String _orgPhone = '+91 ';
  String _orgType = 'GYM';
  String _orgAddress = '';
  String _orgCurrency = 'INR - Indian Rupee ₹';
  String _orgTimezone = 'Asia/Kolkata (IST +05:30)';

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _logoBase64 = 'data:image/jpeg;base64,$base64String';
      });
    }
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final input = CreateOrganizationInput(
        name: _orgName,
        type: _orgType,
        address: _orgAddress.isEmpty ? null : _orgAddress,
        email: _orgEmail.isEmpty ? null : _orgEmail,
        phone: _orgPhone.isEmpty ? null : _orgPhone,
        timezone: _orgTimezone,
        currency: _orgCurrency,
        logoBase64: _logoBase64,
      );
      context.push(AppRoutes.createBranch, extra: input);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildProgress(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildLogoPicker(),
                      const SizedBox(height: 24),
                      _buildBasicInfo(),
                      const SizedBox(height: 16),
                      _buildContactInfo(),
                      const SizedBox(height: 16),
                      _buildLocalization(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4))
          ],
        ),
        child: ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Continue to Branch Setup',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(Iconsax.arrow_right_3, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Iconsax.arrow_left, size: 20),
              onPressed: () => context.pop(),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Organization',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Set up your primary business entity.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          const Text('STEP 1 OF 2',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: 0.5,
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.orange,
                  minHeight: 4),
            ),
          ),
          const SizedBox(width: 12),
          Text('Organization Setup',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildLogoPicker() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200, width: 2)),
            child: _logoBase64 != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.memory(
                      base64Decode(_logoBase64!.split(',').last),
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Iconsax.building, size: 40, color: Colors.grey),
          ),
          InkWell(
            onTap: _pickLogo,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Iconsax.camera, size: 16, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return _buildSection(
      title: 'Basic Information',
      icon: Iconsax.info_circle,
      children: [
        _buildTextField('Organization Name*', 'e.g., Quest Gym',
            onSaved: (v) => _orgName = v!,
            validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 12),
        _buildDropdownField(
            'Business Type',
            ['GYM', 'YOGA_STUDIO', 'MARTIAL_ARTS', 'DANCE_STUDIO'],
            _orgType,
            (v) => setState(() => _orgType = v!)),
      ],
    );
  }

  Widget _buildContactInfo() {
    return _buildSection(
      title: 'Contact Information',
      icon: Iconsax.call,
      children: [
        _buildTextField('Official Email', 'contact@questgym.com',
            onSaved: (v) => _orgEmail = v!,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _buildTextField('Support Phone', '+91 9876543210',
            onSaved: (v) => _orgPhone = v!, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _buildTextField('Billing Address', '123 Main St, City',
            onSaved: (v) => _orgAddress = v!, maxLines: 2),
      ],
    );
  }

  Widget _buildLocalization() {
    return _buildSection(
      title: 'Localization',
      icon: Iconsax.global,
      children: [
        _buildDropdownField(
            'Default Currency',
            [
              'INR - Indian Rupee ₹',
              'USD - US Dollar \$',
              'AED - UAE Dirham د.إ'
            ],
            _orgCurrency,
            (v) => setState(() => _orgCurrency = v!)),
        const SizedBox(height: 12),
        _buildDropdownField(
            'Timezone',
            [
              'Asia/Kolkata (IST +05:30)',
              'Asia/Dubai (GST +04:00)',
              'America/New_York (EST -05:00)'
            ],
            _orgTimezone,
            (v) => setState(() => _orgTimezone = v!)),
      ],
    );
  }

  Widget _buildSection(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: Colors.orange, size: 18)),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint,
      {required FormFieldSetter<String> onSaved,
      FormFieldValidator<String>? validator,
      TextInputType? keyboardType,
      int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 6),
        TextFormField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
          style: const TextStyle(fontSize: 13),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          onSaved: onSaved,
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, List<String> options, String value,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: options
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
