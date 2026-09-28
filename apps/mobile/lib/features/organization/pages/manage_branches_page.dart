import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
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
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh branches',
          ),
        ],
        onMenuSelected: (_) => _loadBranches(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? ShimmerLoader.settingsList()
                  : _error != null
                      ? _buildError()
                      : _buildBranchList(),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ]),
        child: ElevatedButton(
          onPressed: () async {
            await context.push(AppRoutes.addBranch);
            _loadBranches(); // Refresh list after adding
          },
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
              Text('Create New Branch',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(width: 8),
              Icon(Iconsax.add_square, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Kept for the legacy form layout contract; the page now uses the shared bar.
  // ignore: unused_element
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: _branches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final branch = _branches[index];
          final branchId = branch['id']?.toString() ?? '';
          final isActive = branch['status'] == 'ACTIVE';
          final isPrimary =
              context.read<PreferencesStorage>().activeBranchId == branchId;
          final location = [branch['city'], branch['state']]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join(', ');
          final subtitle = [
            if (location.isNotEmpty) location,
            branch['address']?.toString() ?? 'No address provided',
          ].join(' · ');

          return DailioCompactTile(
            avatar: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.orange.shade50,
              child: const Icon(Iconsax.shop, color: Colors.orange, size: 20),
            ),
            title: branch['name']?.toString() ?? 'Unnamed Branch',
            titleBadge: isPrimary ? 'Current' : 'Branch',
            statusBadge: isActive ? 'Active' : 'Inactive',
            statusBadgeColor: isActive ? Colors.green : Colors.red,
            subtitle: subtitle,
            trailing: branch['code']?.toString() ?? '',
            menuItems: const [
              DailioMenuItem(
                value: 'edit',
                icon: Iconsax.edit_2,
                label: 'Edit branch',
              ),
            ],
            onMenuSelected: (value) async {
              if (value == 'edit') {
                await context.push(
                  AppRoutes.editBranch.replaceFirst(':branchId', branchId),
                );
                if (mounted) _loadBranches();
              }
            },
            onTap: () async {
              await context.push(
                AppRoutes.editBranch.replaceFirst(':branchId', branchId),
              );
              if (mounted) _loadBranches();
            },
          );
        },
      ),
    );
  }
}
