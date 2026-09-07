import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../organization/controllers/organization_repository.dart';

class ContextSwitcherPage extends StatefulWidget {
  const ContextSwitcherPage({super.key});

  @override
  State<ContextSwitcherPage> createState() => _ContextSwitcherPageState();
}

class _ContextSwitcherPageState extends State<ContextSwitcherPage> {
  late final OrganizationRepository _repository;
  List<Map<String, dynamic>> _memberships = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<OrganizationRepository>();
    _loadContexts();
  }

  Future<void> _loadContexts() async {
    setState(() => _isLoading = true);
    try {
      final results = await _repository.getMyOrganizations();
      setState(() => _memberships = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectContext(
      Map<String, dynamic> organization, Map<String, dynamic> location) async {
    final prefs = context.read<PreferencesStorage>();
    await prefs.setActiveContext(
      organizationId: organization['id'],
      branchId: location['id'],
      organizationName: organization['name'],
      branchName: location['name'],
    );
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _memberships.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No active locations found.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go(AppRoutes.joinOrCreate),
                        child: const Text('Join or Create an Organization'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _memberships.length,
                  itemBuilder: (context, orgIndex) {
                    final membership = _memberships[orgIndex];
                    final organization = membership['organization'];
                    final locMemberships =
                        membership['location_memberships'] as List;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            organization['name'],
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...locMemberships.map((lm) {
                          final location = lm['location'];
                          return ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(location['name']),
                            subtitle: Text(location['address'] ?? ''),
                            onTap: () => _selectContext(organization, location),
                            trailing: const Icon(Icons.chevron_right),
                          );
                        }),
                        const Divider(),
                      ],
                    );
                  },
                ),
    );
  }
}
