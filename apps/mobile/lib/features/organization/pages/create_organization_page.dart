import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../controllers/organization_repository.dart';
import '../models/create_organization_models.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';

class CreateOrganizationPage extends StatefulWidget {
  const CreateOrganizationPage({super.key});

  @override
  State<CreateOrganizationPage> createState() => _CreateOrganizationPageState();
}

class _CreateOrganizationPageState extends State<CreateOrganizationPage> {
  final _formKey = GlobalKey<FormState>();

  int _step = 1;

  // Organization Fields
  String _orgName = '';
  String _orgEmail = '';
  String _orgPhone = '';
  String _orgIndustry = 'Fitness / Gym & Athletics';
  String _orgBio = '';
  String _orgCurrency = 'INR - Indian Rupee ₹';
  String _orgTimezone = 'Asia/Kolkata (IST +05:30)';
  // Location Fields
  String _locName = '';
  String _locAddress = '';
  String _locCode = '';
  String _locTimezone = 'IST';
  String _locLat = '';
  String _locLng = '';
  double _geofenceRadius = 150;
  bool _reqPunch = true;
  bool _reqGeofence = true;
  bool _reqSelfie = false;
  bool _assignOwner = true;

  bool _isLoading = false;

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _step = 2);
    }
  }

  void _prevStep() {
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final repository = context.read<OrganizationRepository>();
      final result = await repository.createOrganization(
        CreateOrganizationInput(
            name: _orgName, email: _orgEmail.isEmpty ? null : _orgEmail),
        CreateLocationInput(
            name: _locName, address: _locAddress, city: ''),
      );

      if (mounted) {
        final prefs = context.read<PreferencesStorage>();
        await prefs.setActiveContext(
          organizationId: result['organization']['id'],
          branchId: result['location']['id'],
          organizationName: result['organization']['name'],
          branchName: result['location']['name'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Organization Created!')));
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF3D1F00), borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Text('D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 2) {
              _prevStep();
            } else {
              context.pop();
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text('STEP $_step OF 2',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309), letterSpacing: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _step / 2,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: const Color(0xFFB45309),
                      minHeight: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_step == 1 ? 'Organization Setup' : 'Final Touch',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: _step == 1 ? _buildStep1() : _buildStep2(),
              ),
            ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFB45309)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
      ],
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*Required', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
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
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                    SizedBox(height: 3),
                    Text(
                      'As the organization creator, you will automatically become the Organization Owner with protected full-tenant access.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), height: 1.4),
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
        const SizedBox(height: 14),

        _fieldLabel('Organization Legal / Brand Name', required: true),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _orgName,
          decoration: const InputDecoration(hintText: 'e.g. Apex Fitness & Health'),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          onChanged: (v) => setState(() => _orgName = v),
          onSaved: (v) => _orgName = v ?? '',
        ),
        const SizedBox(height: 16),

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
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ),
              const Icon(Icons.check_circle, size: 18, color: Color(0xFF22C55E)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 5, left: 2),
          child: Text('Auto-generated for deep-linking, API access, and employee clock-in portals.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ),
        const SizedBox(height: 16),

        _fieldLabel('Primary Category / Industry'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _orgIndustry, // ignore: deprecated_member_use
          decoration: const InputDecoration(),
          items: ['Fitness / Gym & Athletics', 'Corporate', 'Education', 'Healthcare', 'Other']
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: (v) => setState(() => _orgIndustry = v!),
          onSaved: (v) => _orgIndustry = v ?? 'Fitness / Gym & Athletics',
        ),
        const SizedBox(height: 28),

        // ── BRAND IMAGERY ──────────────────────────────────────────
        _sectionHeader(Icons.image_outlined, 'Brand Imagery'),
        const SizedBox(height: 14),

        _fieldLabel('Brand Logo Upload'),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              const Text('Tap to choose or drag brand logo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
              const SizedBox(height: 4),
              const Text('PNG, JPG or SVG • High resolution 512×512 recommended (Max 5MB)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _fieldLabel('Short Organization Bio'),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _orgBio,
          decoration: const InputDecoration(
            hintText: 'High-performance training club delivering functional training across regional branches...',
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          maxLength: 240,
          onSaved: (v) => _orgBio = v ?? '',
        ),
        const SizedBox(height: 28),

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
        const SizedBox(height: 16),

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
        const SizedBox(height: 28),

        // ── REGIONAL & FISCAL DEFAULTS ─────────────────────────────
        _sectionHeader(Icons.language, 'Regional & Fiscal Defaults'),
        const SizedBox(height: 14),

        _fieldLabel('Default Currency'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _orgCurrency, // ignore: deprecated_member_use
          decoration: const InputDecoration(),
          items: ['INR - Indian Rupee ₹', 'USD - US Dollar \$', 'EUR - Euro €', 'GBP - British Pound £']
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: (v) => setState(() => _orgCurrency = v!),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 5, left: 2, bottom: 16),
          child: Text('Used across membership payouts, fee structures, and attendance audits.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ),

        _fieldLabel('Default Timezone'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _orgTimezone, // ignore: deprecated_member_use
          decoration: const InputDecoration(),
          items: ['Asia/Kolkata (IST +05:30)', 'Asia/Dubai (GST +04:00)', 'America/New_York (EST -05:00)', 'Europe/London (GMT +00:00)']
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: (v) => setState(() => _orgTimezone = v!),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 5, left: 2),
          child: Text('All shifts, geo-punches, and auto-clockouts baseline against this zone.',
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

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('STEP 2 OF 2: OPERATIONAL LOCATION SETUP · Final Touch', style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        const Text('Every operational record, member admission, and attendance punch is scoped to a location.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        const SizedBox(height: 24),
        
        // Branch Identification
        const Row(children: [Icon(Icons.credit_card, size: 20), SizedBox(width: 8), Text('Branch Identification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _locName,
          decoration: const InputDecoration(labelText: 'Branch Name *', hintText: 'Main Branch - [City]'),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          onSaved: (v) => _locName = v ?? '',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _locCode,
                decoration: const InputDecoration(labelText: 'Location Code'),
                onSaved: (v) => _locCode = v ?? '',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _locTimezone,
                decoration: const InputDecoration(labelText: 'Timezone'),
                items: ['IST', 'EST', 'PST', 'GMT'].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                onChanged: (v) => setState(() => _locTimezone = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _locAddress,
          decoration: const InputDecoration(labelText: 'Physical Street Address & Pincode', alignLabelWithHint: true),
          maxLines: 3,
          onSaved: (v) => _locAddress = v ?? '',
        ),
        
        const SizedBox(height: 32),
        // Geofencing & Positioning
        Row(
          children: [
            const Icon(Icons.navigation_outlined, size: 20), 
            const SizedBox(width: 8), 
            const Expanded(child: Text('Geofencing & Positioning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Text('Calibrate', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 32, color: Color(0xFFB45309)),
                SizedBox(height: 8),
                Text('Tap to set location on map', style: TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
            SizedBox(width: 4),
            Text('Satellite Lock OK', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _locLat,
                decoration: const InputDecoration(labelText: 'Latitude', prefixIcon: Icon(Icons.explore_outlined, size: 18)),
                onSaved: (v) => _locLat = v ?? '',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: _locLng,
                decoration: const InputDecoration(labelText: 'Longitude', prefixIcon: Icon(Icons.explore_outlined, size: 18)),
                onSaved: (v) => _locLng = v ?? '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Geofence Radius Perimeter', style: TextStyle(fontWeight: FontWeight.w500)),
            Text('${_geofenceRadius.toInt()}m', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
          ],
        ),
        Slider(
          value: _geofenceRadius,
          min: 50,
          max: 500,
          divisions: 9,
          activeColor: const Color(0xFFB45309),
          onChanged: (v) => setState(() => _geofenceRadius = v),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('50m (Tight)', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            Text('250m', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            Text('500m (Broad)', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
        
        const SizedBox(height: 32),
        // Verification Policies
        const Row(children: [Icon(Icons.security_outlined, size: 20), SizedBox(width: 8), Text('Verification Policies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Punch confirmation required', style: TextStyle(fontSize: 14)),
          value: _reqPunch,
          onChanged: (v) => setState(() => _reqPunch = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        CheckboxListTile(
          title: const Text('Geofence validation enabled', style: TextStyle(fontSize: 14)),
          value: _reqGeofence,
          onChanged: (v) => setState(() => _reqGeofence = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        CheckboxListTile(
          title: const Text('Live selfie verification', style: TextStyle(fontSize: 14)),
          value: _reqSelfie,
          onChanged: (v) => setState(() => _reqSelfie = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        
        const SizedBox(height: 32),
        // Operational Defaults
        const Row(children: [Icon(Icons.schedule_outlined, size: 20), SizedBox(width: 8), Text('Operational Defaults', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Icons.access_time, color: Color(0xFF6B7280), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Operating Hours Schedule Preset', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    SizedBox(height: 2),
                    Text('06:00 AM - 10:00 PM', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 18, color: Color(0xFFB45309)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('Assign Owner as initial Branch Admin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('You will have full permissions to manage this location.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          value: _assignOwner,
          onChanged: (v) => setState(() => _assignOwner = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _submit,
          child: const Text('Complete Setup & Launch Location →'),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _prevStep,
              child: const Text('Previous Step', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            const SizedBox(width: 24),
            TextButton(
              onPressed: () {}, // skip for now
              child: const Text('Skip for now', style: TextStyle(color: Color(0xFF6B7280))),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Note: Geofence boundaries and verification policies can be updated later in the location settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}
