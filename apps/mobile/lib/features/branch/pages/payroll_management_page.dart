import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/branch_filter_tabs.dart';
import '../../organization/controllers/organization_repository.dart';
import '../controllers/payroll_repository.dart';

class PayrollManagementPage extends StatefulWidget {
  const PayrollManagementPage({super.key});

  @override
  State<PayrollManagementPage> createState() => _PayrollManagementPageState();
}

class _PayrollManagementPageState extends State<PayrollManagementPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _structures = [];
  String? _selectedFilterBranchId;
  late String _orgId;
  late PayrollRepository _repo;

  // UI States
  int _selectedPrimaryTab = 0; // 0 = Salary Structure, 1 = Payroll Runs

  @override
  void initState() {
    super.initState();
    _repo = context.read<PayrollRepository>();
    _orgId = context.read<PreferencesStorage>().activeOrganizationId!;
    _selectedFilterBranchId = context.read<PreferencesStorage>().activeBranchId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final structures = await _repo.listSalaryStructures(
        _orgId,
        branchId: _selectedFilterBranchId,
      );
      if (mounted) {
        setState(() {
          _structures = structures;
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

  void _showFormModal({Map<String, dynamic>? struct}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _StructureFormSheet(
        orgId: _orgId,
        defaultBranchId: _selectedFilterBranchId,
        structureToEdit: struct,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String title, VoidCallback onConfirm) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text(
            'Are you sure you want to delete this? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                BranchFilterTabs(
                  selectedBranchId: _selectedFilterBranchId,
                  onChanged: (val) {
                    setState(() => _selectedFilterBranchId = val);
                    _loadData();
                  },
                ),
                const SizedBox(height: 16),
                _buildPrimarySegmentedControl(),
                const SizedBox(height: 16),
                if (_selectedPrimaryTab == 0) _buildSectionHeader(),
                Expanded(
                  child: _selectedPrimaryTab == 1
                      ? _buildPayrollRunsEmptyState()
                      : _isLoading
                          ? _buildSkeleton()
                          : _error != null
                              ? Center(child: Text('Error: $_error'))
                              : _structures.isEmpty
                                  ? _buildEmptyState()
                                  : _buildList(),
                )
              ],
            ),
            if (_selectedPrimaryTab == 0)
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: ElevatedButton(
                  onPressed: () => _showFormModal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.add, size: 20),
                      SizedBox(width: 8),
                      Text('New Structure',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Iconsax.arrow_left, size: 20),
              onPressed: () => context.pop(),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payroll Management',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Manage compensation and payroll runs',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimarySegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPrimaryTab = 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedPrimaryTab == 0
                        ? const Color(0xFF8D490B)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _selectedPrimaryTab == 0
                        ? [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.wallet_1,
                            size: 16,
                            color: _selectedPrimaryTab == 0
                                ? Colors.white
                                : Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text('Salary Structure',
                            style: TextStyle(
                                color: _selectedPrimaryTab == 0
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPrimaryTab = 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedPrimaryTab == 1
                        ? const Color(0xFF8D490B)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.receipt_item,
                            size: 16,
                            color: _selectedPrimaryTab == 1
                                ? Colors.white
                                : Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text('Payroll Runs',
                            style: TextStyle(
                                color: _selectedPrimaryTab == 1
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text('Active Compensation Profiles',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('Profiles Active',
                style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      itemCount: 3,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.wallet_2, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No Salary Structures',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Create standard salary bands to assign to members.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  Widget _buildPayrollRunsEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.receipt_item, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No Payroll Runs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Run payroll at the end of the billing cycle.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  Widget _buildStackedAvatars(List<dynamic> avatars, int totalCount) {
    if (totalCount == 0) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFF1F5F9),
          child: Icon(Iconsax.profile_2user, size: 16, color: Colors.grey),
        ),
      );
    }

    int displayedCount = avatars.length > 2 ? 2 : avatars.length;
    int remainingCount = totalCount - displayedCount;
    if (avatars.length == 3 && totalCount == 3) {
      displayedCount = 3;
      remainingCount = 0;
    }

    return SizedBox(
      width: (displayedCount * 20.0) + (remainingCount > 0 ? 20.0 : 0.0) + 16.0,
      height: 36,
      child: Stack(
        children: [
          for (int i = 0; i < displayedCount; i++)
            Positioned(
              left: i * 20.0,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      avatars[i] != null && avatars[i].toString().isNotEmpty
                          ? NetworkImage(avatars[i].toString())
                          : null,
                  backgroundColor: Colors.grey.shade300,
                  child: avatars[i] == null || avatars[i].toString().isEmpty
                      ? const Icon(Icons.person, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ),
          if (remainingCount > 0)
            Positioned(
              left: displayedCount * 20.0,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text('+',
                      style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      itemCount: _structures.length,
      itemBuilder: (context, index) {
        final struct = _structures[index];
        final formatter = NumberFormat.decimalPattern('en_IN');

        final name = struct['name'] ?? 'Unnamed';
        final baseAmt = (struct['amount'] ?? 0) as int;

        final List<dynamic> earningsList = struct['earnings'] ?? [];
        final List<dynamic> deductionsList = struct['deductions'] ?? [];

        int earningsTotal = 0;
        int deductionsTotal = 0;
        for (var e in earningsList) {
          earningsTotal += (e['amount'] as int? ?? 0);
        }
        for (var d in deductionsList) {
          deductionsTotal += (d['amount'] as int? ?? 0);
        }

        final baseSalaryStr = formatter.format((baseAmt / 100).round());
        final netSalary =
            ((baseAmt + earningsTotal - deductionsTotal) / 100).round();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              // HEADER ROW
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStackedAvatars(
                        struct['avatars'] ?? [], struct['membersCount'] ?? 0),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text('ID: ${struct['id'].toString().substring(0, 8)}',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        children: [
                          Icon(Iconsax.verify, color: Colors.green, size: 12),
                          SizedBox(width: 4),
                          Text('Verified',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              const Divider(height: 1),

              // DETAILS GRID
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFF9FAFB),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Net Payable',
                                  style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('\u20B9${formatter.format(netSalary)}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          height: 1)),
                                  const Text('/mo',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          height: 1.2)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Base Salary',
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('\u20B9$baseSalaryStr',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          height: 1)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (earningsList.isNotEmpty ||
                        deductionsList.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (earningsList.isNotEmpty)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('EARNINGS',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ...earningsList.map((e) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                                child: Text(e['label'] ?? '',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black87),
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                            Text(
                                                '\u20B9${formatter.format(((e['amount'] ?? 0) / 100).round())}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          if (earningsList.isNotEmpty &&
                              deductionsList.isNotEmpty)
                            const SizedBox(width: 16),
                          if (deductionsList.isNotEmpty)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('DEDUCTIONS',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ...deductionsList.map((d) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                                child: Text(d['label'] ?? '',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black87),
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                            Text(
                                                '\u20B9${formatter.format(((d['amount'] ?? 0) / 100).round())}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1),

              // FOOTER
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.clock,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('Updated recently',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _confirmDelete(
                              context, 'Delete Structure', () async {
                            await _repo.deleteSalaryStructure(
                                _orgId, struct['id']);
                            _loadData();
                          }),
                          icon: const Icon(Iconsax.trash,
                              color: Colors.red, size: 16),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(right: 12),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showFormModal(struct: struct),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8D490B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              minimumSize: const Size(0, 32)),
                          icon: const Icon(Iconsax.edit_2, size: 14),
                          label: const Text('Edit Structure',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StructureFormSheet extends StatefulWidget {
  final String orgId;
  final String? defaultBranchId;
  final Map<String, dynamic>? structureToEdit;
  final VoidCallback onSaved;

  const _StructureFormSheet(
      {required this.orgId,
      this.defaultBranchId,
      this.structureToEdit,
      required this.onSaved});

  @override
  State<_StructureFormSheet> createState() => _StructureFormSheetState();
}

class _StructureFormSheetState extends State<_StructureFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _amount = 0;
  String? _selectedBranchId;

  List<Map<String, dynamic>> _earnings = [];
  List<Map<String, dynamic>> _deductions = [];

  List<Map<String, dynamic>> _branches = [];
  bool _isLoadingBranches = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.structureToEdit != null) {
      _name = widget.structureToEdit!['name'] ?? '';
      _amount = widget.structureToEdit!['amount'] ?? 0;
      _selectedBranchId = widget.structureToEdit!['branch_id'];

      if (widget.structureToEdit!['earnings'] != null) {
        _earnings = List<Map<String, dynamic>>.from(widget
            .structureToEdit!['earnings']
            .map((x) => Map<String, dynamic>.from(x)));
      }
      if (widget.structureToEdit!['deductions'] != null) {
        _deductions = List<Map<String, dynamic>>.from(widget
            .structureToEdit!['deductions']
            .map((x) => Map<String, dynamic>.from(x)));
      }
    } else {
      _selectedBranchId =
          widget.defaultBranchId == 'none' ? null : widget.defaultBranchId;
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final repo = context.read<OrganizationRepository>();
      final branches = await repo.getOrganizationBranches(widget.orgId);
      if (mounted) {
        setState(() {
          _branches = branches;
          _isLoadingBranches = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBranches = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);
    try {
      final repo = context.read<PayrollRepository>();
      final data = {
        'name': _name,
        'branch_id': _selectedBranchId,
        'amount': _amount,
        'earnings': _earnings,
        'deductions': _deductions,
      };

      if (widget.structureToEdit != null) {
        await repo.updateSalaryStructure(
            widget.orgId, widget.structureToEdit!['id'], data);
      } else {
        await repo.createSalaryStructure(widget.orgId, data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildDynamicList(
      String title, List<Map<String, dynamic>> items, Color headerColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: headerColor)),
            TextButton.icon(
              onPressed: () =>
                  setState(() => items.add({'label': '', 'amount': 0})),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: headerColor),
            )
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('No $title added',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ...List.generate(items.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: items[i]['label'],
                    decoration: InputDecoration(
                      labelText: 'Label (e.g. Bonus)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => items[i]['label'] = val,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: items[i]['amount'] != 0
                        ? (items[i]['amount'] / 100).toStringAsFixed(0)
                        : '',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amt (\u20B9)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      items[i]['amount'] = (int.tryParse(val) ?? 0) * 100;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () => setState(() => items.removeAt(i)),
                )
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.structureToEdit != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    isEditing
                        ? 'Edit Salary Structure'
                        : 'New Salary Structure',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      if (!_isLoadingBranches)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBranchId,
                          decoration: InputDecoration(
                              labelText: 'Branch',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.black))),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null, child: Text('No Branch (HQ)')),
                            ..._branches.map((b) => DropdownMenuItem<String>(
                                value: b['id'], child: Text(b['name'])))
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedBranchId = val),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _name,
                        decoration: InputDecoration(
                            labelText: 'Structure Name (e.g. Senior Trainer)',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.black))),
                        onSaved: (val) => _name = val ?? '',
                        validator: (val) =>
                            (val == null || val.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: isEditing
                            ? (_amount / 100).toStringAsFixed(0)
                            : null,
                        decoration: InputDecoration(
                            labelText: 'Monthly Base Salary',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.black))),
                        keyboardType: TextInputType.number,
                        onSaved: (val) =>
                            _amount = (int.tryParse(val ?? '0') ?? 0) * 100,
                        validator: (val) =>
                            (val == null || val.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDynamicList('Earnings', _earnings, Colors.green),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDynamicList('Deductions', _deductions, Colors.red),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isEditing ? 'Save Changes' : 'Create Structure',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
