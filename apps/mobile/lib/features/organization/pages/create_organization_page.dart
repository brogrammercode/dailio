import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../models/create_organization_models.dart';
import '../../../core/router/route_names.dart';

class CreateOrganizationPage extends StatefulWidget {
  const CreateOrganizationPage({super.key});

  @override
  State<CreateOrganizationPage> createState() => _CreateOrganizationPageState();
}

class _CreateOrganizationPageState extends State<CreateOrganizationPage> {
  final _formKey = GlobalKey<FormState>();

  // Organization Fields
  String? _logoBase64;
  String _orgName = '';
  String _orgEmail = '';
  String _orgPhone = '+91 ';
  String _orgIndustry = 'Fitness / Gym & Athletics';
  String _orgBio = '';
  String _orgCurrency = 'INR - Indian Rupee ₹';
  String _orgTimezone = 'Asia/Kolkata (IST +05:30)';

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
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
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Create Organization',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                const Text('STEP 1 OF 2',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                        letterSpacing: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      value: 0.5,
                      backgroundColor: Color(0xFFE5E7EB),
                      color: Color(0xFFB45309),
                      minHeight: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Organization Setup',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: _buildStep1(),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFB45309)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A))),
      ],
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*Required',
              style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
        ],
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Page title
        const Text('Create your organization',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A))),
        const SizedBox(height: 6),
        const Text(
          'Configure high-level workspace credentials, audit identifiers, and regional accounting defaults.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
        ),
        const SizedBox(height: 20),

        // Owner auth notice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Owner Tenant Authorization',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E40AF))),
                    SizedBox(height: 3),
                    Text(
                      'As the organization creator, you will automatically become the Organization Owner with protected full-tenant access.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF3B82F6), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── CORE IDENTITY ──────────────────────────────────────────
        _sectionHeader(Icons.credit_card_outlined, 'Core Identity'),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                image: _logoBase64 != null
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(_logoBase64!.split(',')[1])),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _logoBase64 == null
                  ? const Icon(Icons.add_a_photo, color: Color(0xFF9CA3AF))
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(child: Text('Upload Logo (Optional)', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
        const SizedBox(height: 20),

        _fieldLabel('Organization Legal / Brand Name', required: true),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _orgName,
          decoration:
              const InputDecoration(hintText: 'e.g. Apex Fitness & Health'),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          onChanged: (v) => setState(() => _orgName = v),
          onSaved: (v) => _orgName = v ?? '',
        ),
        const SizedBox(height: 20),

        _fieldLabel('Workspace Slug / Code'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'dailio.app/${_orgName.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-9-]'), '')}',
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ),
              const Icon(Icons.check_circle,
                  size: 18, color: Color(0xFF22C55E)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 5, left: 2),
          child: Text(
              'Auto-generated for deep-linking, API access, and employee clock-in portals.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ),
        const SizedBox(height: 20),

        _fieldLabel('Primary Category / Industry'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _orgIndustry, // ignore: deprecated_member_use
          decoration: const InputDecoration(),
          items: [
            'Fitness / Gym & Athletics',
            'Corporate',
            'Education',
            'Healthcare',
            'Other'
          ].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: (v) => setState(() => _orgIndustry = v!),
          onSaved: (v) => _orgIndustry = v ?? 'Fitness / Gym & Athletics',
        ),
        const SizedBox(height: 40),

        _fieldLabel('Short Organization Bio'),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _orgBio,
          decoration: const InputDecoration(
            hintText:
                'High-performance training club delivering functional training across regional branches...',
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          maxLength: 240,
          onSaved: (v) => _orgBio = v ?? '',
        ),
        const SizedBox(height: 40),

        // ── OFFICIAL POINTS OF CONTACT ─────────────────────────────
        _sectionHeader(Icons.alternate_email, 'Official Points of Contact'),
        const SizedBox(height: 14),

        _fieldLabel('Contact Email'),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _orgEmail,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.email_outlined, size: 18),
            hintText: 'operations@apxfitness.com',
          ),
          keyboardType: TextInputType.emailAddress,
          onSaved: (v) => _orgEmail = v ?? '',
        ),
        const SizedBox(height: 20),

        _fieldLabel('Official Phone Number'),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _orgPhone,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.phone_outlined, size: 18),
            hintText: '+91 98765 43210',
          ),
          keyboardType: TextInputType.phone,
          onSaved: (v) => _orgPhone = v ?? '',
        ),
        const SizedBox(height: 40),

        // ── REGIONAL & FISCAL DEFAULTS ─────────────────────────────
        _sectionHeader(Icons.language, 'Regional & Fiscal Defaults'),
        const SizedBox(height: 14),

        _fieldLabel('Default Currency'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _orgCurrency, // ignore: deprecated_member_use
          decoration: const InputDecoration(),
          items: [
            'INR - Indian Rupee ₹',
            'USD - US Dollar \$',
            'EUR - Euro €',
            'GBP - British Pound £'
          ].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: (v) => setState(() => _orgCurrency = v!),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 5, left: 2, bottom: 16),
          child: Text(
              'Used across membership payouts, fee structures, and attendance audits.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ),

        _fieldLabel('Default Timezone'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _orgTimezone, // ignore: deprecated_member_use
          decoration: const InputDecoration(),
          items: [
            'Asia/Kolkata (IST +05:30)',
            'Asia/Dubai (GST +04:00)',
            'America/New_York (EST -05:00)',
            'Europe/London (GMT +00:00)'
          ].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: (v) => setState(() => _orgTimezone = v!),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 5, left: 2),
          child: Text(
              'All shifts, geo-punches, and auto-clockouts baseline against this zone.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ),

        const SizedBox(height: 32),
        FilledButton(
          onPressed: _nextStep,
          child: const Text('Save & Proceed to Branch Setup →'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel and return to dashboard',
              style: TextStyle(color: Color(0xFF6B7280))),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}




