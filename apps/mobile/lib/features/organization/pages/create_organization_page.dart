import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/route_names.dart';
import '../../../core/widgets/dailio_onboarding_widgets.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
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
  String _orgCurrency = 'INR - Indian Rupee';
  String _orgTimezone = 'Asia/Kolkata (IST +05:30)';

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(
        () => _logoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    context.push(
      AppRoutes.createBranch,
      extra: CreateOrganizationInput(
        name: _orgName.trim(),
        type: _orgType,
        address: _orgAddress.trim().isEmpty ? null : _orgAddress.trim(),
        email: _orgEmail.trim().isEmpty ? null : _orgEmail.trim(),
        phone: _orgPhone.trim().isEmpty ? null : _orgPhone.trim(),
        timezone: _orgTimezone,
        currency: _orgCurrency,
        logoBase64: _logoBase64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(onBack: () => context.pop()),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            children: [
              const Text('Create organization',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Step 1 of 2 · Set up the organization profile.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF858585))),
              const SizedBox(height: 20),
              const LinearProgressIndicator(
                  value: .5,
                  minHeight: 3,
                  backgroundColor: Color(0xFFF0E6DC),
                  color: Color(0xFFCC5A00)),
              const SizedBox(height: 22),
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: const Color(0xFFFFF1E6),
                      backgroundImage: _logoBase64 == null
                          ? null
                          : MemoryImage(
                              base64Decode(_logoBase64!.split(',').last)),
                      child: _logoBase64 == null
                          ? const Icon(Iconsax.building_4,
                              size: 32, color: Color(0xFFCC5A00))
                          : null,
                    ),
                    InkWell(
                      onTap: _pickLogo,
                      borderRadius: BorderRadius.circular(99),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFCC5A00),
                        child:
                            Icon(Iconsax.camera, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const DailioOnboardingSectionLabel('ORGANIZATION DETAILS'),
              TextFormField(
                decoration: dailioOnboardingInput(
                    'Organization name', Iconsax.building_4),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Organization name is required'
                    : null,
                onSaved: (value) => _orgName = value ?? '',
              ),
              const SizedBox(height: 10),
              DailioPickerField<String>(
                initialValue: _orgType,
                decoration:
                    dailioOnboardingInput('Business type', Iconsax.category_2),
                items: const [
                  DropdownMenuItem(value: 'GYM', child: Text('Gym')),
                  DropdownMenuItem(
                      value: 'YOGA_STUDIO', child: Text('Yoga studio')),
                  DropdownMenuItem(
                      value: 'MARTIAL_ARTS', child: Text('Martial arts')),
                  DropdownMenuItem(
                      value: 'DANCE_STUDIO', child: Text('Dance studio')),
                ],
                onChanged: (value) => setState(() => _orgType = value ?? 'GYM'),
              ),
              const SizedBox(height: 18),
              const DailioOnboardingSectionLabel('CONTACT'),
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: dailioOnboardingInput(
                    'Official email (optional)', Iconsax.sms),
                onSaved: (value) => _orgEmail = value ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                keyboardType: TextInputType.phone,
                decoration: dailioOnboardingInput(
                    'Support phone (optional)', Iconsax.call),
                onSaved: (value) => _orgPhone = value ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                maxLines: 2,
                decoration: dailioOnboardingInput(
                    'Billing address (optional)', Iconsax.location),
                onSaved: (value) => _orgAddress = value ?? '',
              ),
              const SizedBox(height: 18),
              const DailioOnboardingSectionLabel('DEFAULTS'),
              DailioPickerField<String>(
                initialValue: _orgCurrency,
                decoration: dailioOnboardingInput('Currency', Iconsax.money_2),
                items: const [
                  DropdownMenuItem(
                      value: 'INR - Indian Rupee',
                      child: Text('INR · Indian Rupee')),
                  DropdownMenuItem(
                      value: 'USD - US Dollar', child: Text('USD · US Dollar')),
                  DropdownMenuItem(
                      value: 'AED - UAE Dirham',
                      child: Text('AED · UAE Dirham')),
                ],
                onChanged: (value) =>
                    setState(() => _orgCurrency = value ?? _orgCurrency),
              ),
              const SizedBox(height: 10),
              DailioPickerField<String>(
                initialValue: _orgTimezone,
                decoration: dailioOnboardingInput('Timezone', Iconsax.global),
                items: const [
                  DropdownMenuItem(
                      value: 'Asia/Kolkata (IST +05:30)',
                      child: Text('Asia/Kolkata · IST +05:30')),
                  DropdownMenuItem(
                      value: 'Asia/Dubai (GST +04:00)',
                      child: Text('Asia/Dubai · GST +04:00')),
                  DropdownMenuItem(
                      value: 'America/New_York (EST -05:00)',
                      child: Text('America/New_York · EST -05:00')),
                ],
                onChanged: (value) =>
                    setState(() => _orgTimezone = value ?? _orgTimezone),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: DailioOnboardingButton(
          label: 'Continue to branch setup',
          icon: Iconsax.arrow_right_3,
          onPressed: _nextStep,
        ),
      ),
    );
  }
}
