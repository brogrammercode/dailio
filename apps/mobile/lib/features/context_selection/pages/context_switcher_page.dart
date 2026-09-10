import 'package:iconsax/iconsax.dart';
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
      Map<String, dynamic> organization, Map<String, dynamic> branch) async {
    final prefs = context.read<PreferencesStorage>();
    await prefs.setActiveContext(
      organizationId: organization['id'],
      branchId: branch['id'],
      organizationName: organization['name'],
      branchName: branch['name'],
    );
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/logo.png',
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Switch Workspace',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _memberships.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.domain_disabled_outlined,
                size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            const Text('No active branches found.',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            const Text(
                'You are not currently a member of any organization or branch. Please join an existing one or create your own.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.joinOrCreate),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Join or Create Organization'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _memberships.length,
      itemBuilder: (context, orgIndex) {
        final membership = _memberships[orgIndex];
        final organization = membership['organization'];
        final locMemberships = membership['location_memberships'] as List;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  organization['name']?.toUpperCase() ?? 'ORGANIZATION',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: locMemberships.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  itemBuilder: (context, branchIndex) {
                    final branch = locMemberships[branchIndex]['location'];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Iconsax.shop,
                            color: Color(0xFFB45309), size: 20),
                      ),
                      title: Text(branch['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: Text(branch['address'] ?? 'No address set',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                      trailing: const Icon(Iconsax.arrow_right_3,
                          color: Color(0xFFD1D5DB)),
                      onTap: () => _selectContext(organization, branch),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
