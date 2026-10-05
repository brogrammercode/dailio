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
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
        maxWidth: 512.r,
        maxHeight: 512.r,
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
            padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 96.r),
            children: [
              Text('Create organization',
                  style:
                      TextStyle(fontSize: 22.r, fontWeight: FontWeight.w800)),
              SizedBox(height: 5.r),
              Text('Step 1 of 2 · Set up the organization profile.',
                  style: TextStyle(fontSize: 13.r, color: Color(0xFF858585))),
              SizedBox(height: 20.r),
              LinearProgressIndicator(
                  value: .5,
                  minHeight: 3.r,
                  backgroundColor: Color(0xFFF0E6DC),
                  color: Color(0xFFCC5A00)),
              SizedBox(height: 22.r),
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 42.r,
                      backgroundColor: const Color(0xFFFFF1E6),
                      backgroundImage: _logoBase64 == null
                          ? null
                          : MemoryImage(
                              base64Decode(_logoBase64!.split(',').last)),
                      child: _logoBase64 == null
                          ? Icon(Iconsax.building_4,
                              size: 32.r, color: Color(0xFFCC5A00))
                          : null,
                    ),
                    InkWell(
                      onTap: _pickLogo,
                      borderRadius: BorderRadius.circular(99.r),
                      child: CircleAvatar(
                        radius: 14.r,
                        backgroundColor: Color(0xFFCC5A00),
                        child: Icon(Iconsax.camera,
                            size: 14.r, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22.r),
              const DailioOnboardingSectionLabel('ORGANIZATION DETAILS'),
              TextFormField(
                decoration: dailioOnboardingInput(
                    'Organization name', Iconsax.building_4),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Organization name is required'
                    : null,
                onSaved: (value) => _orgName = value ?? '',
              ),
              SizedBox(height: 10.r),
              DailioPickerField<String>(
                initialValue: _orgType,
                decoration:
                    dailioOnboardingInput('Business type', Iconsax.category_2),
                items: const [
                  DropdownMenuItem(value: 'GYM', child: Text('Gym')),
                  DropdownMenuItem(
                      value: 'FOOD_SERVICE', child: Text('Mess / cafeteria')),
                  DropdownMenuItem(value: 'COACHING', child: Text('Coaching')),
                  DropdownMenuItem(value: 'CLINIC', child: Text('Clinic')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => _orgType = value ?? 'GYM'),
              ),
              SizedBox(height: 18.r),
              const DailioOnboardingSectionLabel('CONTACT'),
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: dailioOnboardingInput(
                    'Official email (optional)', Iconsax.sms),
                onSaved: (value) => _orgEmail = value ?? '',
              ),
              SizedBox(height: 10.r),
              TextFormField(
                keyboardType: TextInputType.phone,
                decoration: dailioOnboardingInput(
                    'Support phone (optional)', Iconsax.call),
                onSaved: (value) => _orgPhone = value ?? '',
              ),
              SizedBox(height: 10.r),
              TextFormField(
                maxLines: 2,
                decoration: dailioOnboardingInput(
                    'Billing address (optional)', Iconsax.location),
                onSaved: (value) => _orgAddress = value ?? '',
              ),
              SizedBox(height: 18.r),
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
              SizedBox(height: 10.r),
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
        minimum: EdgeInsets.fromLTRB(16.r, 8.r, 16.r, 12.r),
        child: DailioOnboardingButton(
          label: 'Continue to branch setup',
          icon: Iconsax.arrow_right_3,
          onPressed: _nextStep,
        ),
      ),
    );
  }
}
