import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/organization/controllers/organization_repository.dart';
import '../storage/preferences_storage.dart';

class BranchFilterTabs extends StatefulWidget {
  final String? selectedBranchId;
  final Function(String? branchId) onChanged;
  final EdgeInsetsGeometry contentPadding;

  const BranchFilterTabs({
    super.key,
    required this.selectedBranchId,
    required this.onChanged,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  State<BranchFilterTabs> createState() => _BranchFilterTabsState();
}

class _BranchFilterTabsState extends State<BranchFilterTabs> {
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: widget.contentPadding,
          child: Row(
            children: List.generate(
              3,
              (index) => Container(
                margin: const EdgeInsets.only(right: 8),
                height: 34,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: widget.contentPadding,
        child: Row(
          children: [
            _buildTab('All', null),
            ..._branches.map((b) => _buildTab(b['name'], b['id'])),
            _buildTab('No Branch', 'none'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String? value) {
    final isSelected = widget.selectedBranchId == value;
    return GestureDetector(
      onTap: () => widget.onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}


