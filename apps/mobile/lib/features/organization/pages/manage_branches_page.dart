import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/organization_repository.dart';

class ManageBranchesPage extends StatefulWidget {
  const ManageBranchesPage({super.key});

  @override
  State<ManageBranchesPage> createState() => _ManageBranchesPageState();
}

class _ManageBranchesPageState extends State<ManageBranchesPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _branches = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repository = context.read<OrganizationRepository>();
      final prefs = context.read<PreferencesStorage>();
      final orgId = prefs.activeOrganizationId!;
      final branches = await repository.getOrganizationBranches(orgId);

      if (mounted) {
        setState(() {
          _branches = branches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
            Expanded(
              child: _isLoading
                  ? ShimmerLoader.list()
                  : _error != null
                      ? _buildError()
                      : _buildBranchList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRoutes.addBranch);
          _loadBranches(); // Refresh list after adding
        },
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Iconsax.add, size: 20),
        label: const Text('Add Branch',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
                icon: const Icon(Iconsax.arrow_left, size: 20),
                onPressed: () => context.pop(),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Branches',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('View and edit your organization locations',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.warning_2, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load branches',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBranches,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchList() {
    if (_branches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.shop, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No branches found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Add a new branch to get started.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBranches,
      color: Colors.orange,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
        itemCount: _branches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final branch = _branches[index];
          final isActive = branch['status'] == 'ACTIVE';
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Iconsax.shop, color: Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              branch['name'] ?? 'Unnamed Branch',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.green.shade700
                                      : Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [branch['city'], branch['state']]
                            .where((e) => e != null && e.toString().isNotEmpty)
                            .join(', '),
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        branch['address'] ?? 'No address provided',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    await context.push(AppRoutes.editBranch
                        .replaceFirst(':branchId', branch['id']));
                    _loadBranches(); // Refresh list after edit
                  },
                  icon:
                      const Icon(Iconsax.edit, size: 20, color: Colors.orange),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.orange.shade50),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
