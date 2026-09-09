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
  String _orgWebsite = '';
  String _orgIndustry = 'Fitness';

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
      appBar: AppBar(
        title: Text(_step == 1 ? 'Create Your Organization' : 'Add First Location / Branch'),
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

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('STEP 1 OF 2: ORGANIZATION IDENTITY', style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 24),
        TextFormField(
          initialValue: _orgName,
          decoration: const InputDecoration(labelText: 'Organization Name *', prefixIcon: Icon(Icons.business)),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          onSaved: (v) => _orgName = v ?? '',
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _orgEmail,
          decoration: const InputDecoration(labelText: 'Support Email', prefixIcon: Icon(Icons.email_outlined)),
          keyboardType: TextInputType.emailAddress,
          onSaved: (v) => _orgEmail = v ?? '',
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _orgPhone,
          decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
          keyboardType: TextInputType.phone,
          onSaved: (v) => _orgPhone = v ?? '',
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _orgWebsite,
          decoration: const InputDecoration(labelText: 'Website', prefixIcon: Icon(Icons.language_outlined)),
          keyboardType: TextInputType.url,
          onSaved: (v) => _orgWebsite = v ?? '',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _orgIndustry,
          decoration: const InputDecoration(labelText: 'Industry/Type', prefixIcon: Icon(Icons.category_outlined)),
          items: ['Fitness', 'Corporate', 'Education', 'Healthcare', 'Other']
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: (v) => setState(() => _orgIndustry = v!),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _nextStep,
          child: const Text('Continue to Location Setup →'),
        ),
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
