import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../features/organization/controllers/organization_repository.dart';
import '../storage/preferences_storage.dart';
import 'dailio_tab_strip.dart';

class BranchFilterTabs extends StatefulWidget {
  final String? selectedBranchId;
  final Function(String? branchId) onChanged;
  final EdgeInsetsGeometry contentPadding;
  final bool centered;

  const BranchFilterTabs({
    super.key,
    required this.selectedBranchId,
    required this.onChanged,
    this.contentPadding = EdgeInsets.zero,
    this.centered = false,
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
      return Padding(
        padding: widget.contentPadding,
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: SizedBox(
            height: 44,
            child: Align(
              // Keep the loading geometry in the same visual position as the
              // compact branch tabs once they resolve.
              alignment: Alignment.center,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE9E9E9)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 12),
                      child: const SizedBox(
                        width: 62,
                        height: 16,
                        child: ColoredBox(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final tabs = <DailioTabItem<String?>>[
      const DailioTabItem(value: null, label: 'All'),
      ..._branches.map(
        (branch) => DailioTabItem<String?>(
          value: branch['id']?.toString(),
          label: branch['name']?.toString() ?? 'Branch',
        ),
      ),
      const DailioTabItem(value: 'none', label: 'No Branch'),
    ];
    return Padding(
      padding: widget.contentPadding,
      child: DailioTabStrip<String?>(
        tabs: tabs,
        selected: widget.selectedBranchId,
        onChanged: widget.onChanged,
        centered: widget.centered,
      ),
    );
  }
}
