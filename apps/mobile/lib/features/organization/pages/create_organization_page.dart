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

  // Organization Fields
  String _orgName = '';
  String _orgEmail = '';

  // Location Fields
  String _locName = '';
  String _locAddress = '';
  String _locCity = '';

  bool _isLoading = false;

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
            name: _locName, address: _locAddress, city: _locCity),
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
      appBar: AppBar(title: const Text('Create Your Organization')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Organization Details',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Organization Name *',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                      onSaved: (v) => _orgName = v ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Support Email',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                      onSaved: (v) => _orgEmail = v ?? '',
                    ),
                    const SizedBox(height: 32),
                    Text('First Location Details',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Location Name (e.g. Main Branch) *',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                      onSaved: (v) => _locName = v ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Address', border: OutlineInputBorder()),
                      onSaved: (v) => _locAddress = v ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'City', border: OutlineInputBorder()),
                      onSaved: (v) => _locCity = v ?? '',
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _submit,
                      child: const Text('Create Organization'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
