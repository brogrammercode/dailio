import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  String? _selectedFilterBranchId;
  late final String _orgId;
  late final PayrollRepository _repo;

  List<Map<String, dynamic>> _structures = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedFilterBranchId = context.read<PreferencesStorage>().activeBranchId;
    _orgId = context.read<PreferencesStorage>().activeOrganizationId!;
    _repo = context.read<PayrollRepository>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.listSalaryStructures(_orgId, branchId: _selectedFilterBranchId == 'none' ? null : _selectedFilterBranchId);
      if (mounted) setState(() => _structures = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddStructureModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _AddStructureSheet(
        orgId: _orgId,
        defaultBranchId: _selectedFilterBranchId,
        onCreated: _loadData,
      ),
    );
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
                  contentPadding: EdgeInsets.zero,
                  selectedBranchId: _selectedFilterBranchId,
                  onChanged: (val) {
                    setState(() => _selectedFilterBranchId = val);
                    _loadData();
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? _buildSkeleton()
                      : _error != null
                          ? Center(child: Text('Error: $_error'))
                          : _structures.isEmpty
                              ? _buildEmptyState()
                              : _buildList(),
                )
              ],
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: _showAddStructureModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.add, size: 20),
                    SizedBox(width: 8),
                    Text('New Salary Structure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
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
                Text('Payroll Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Salary structures & payroll runs', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100, child: Container(width: 120, height: 14, color: Colors.white)),
                  const SizedBox(height: 8),
                  Shimmer.fromColors(baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100, child: Container(width: 80, height: 12, color: Colors.white)),
                ],
              ),
            ),
          ],
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
          const Text('No Salary Structures', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Create standard salary bands to assign to members.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 64), // extra space for bottom button
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: _structures.length,
      itemBuilder: (context, index) {
        final struct = _structures[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(Iconsax.wallet_1, color: Colors.orange.shade700, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(struct['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('\u20B9  / month', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Iconsax.trash, size: 18, color: Colors.red),
                onPressed: () async {
                  await _repo.deleteSalaryStructure(_orgId, struct['id']);
                  _loadData();
                },
              )
            ],
          ),
        );
      },
    );
  }
}

class _AddStructureSheet extends StatefulWidget {
  final String orgId;
  final String? defaultBranchId;
  final VoidCallback onCreated;

  const _AddStructureSheet({required this.orgId, this.defaultBranchId, required this.onCreated});

  @override
  State<_AddStructureSheet> createState() => _AddStructureSheetState();
}

class _AddStructureSheetState extends State<_AddStructureSheet> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _amount = 0;
  String? _selectedBranchId;
  
  List<Map<String, dynamic>> _branches = [];
  bool _isLoadingBranches = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.defaultBranchId == 'none' ? null : widget.defaultBranchId;
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

    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a branch')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = context.read<PayrollRepository>();
      await repo.createSalaryStructure(widget.orgId, {
        'name': _name,
        'branch_id': _selectedBranchId,
        'amount': _amount,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Salary Structure', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 24),
            if (!_isLoadingBranches)
              DropdownButtonFormField<String>(
                initialValue: _selectedBranchId,
                decoration: InputDecoration(labelText: 'Branch', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade400))),
                items: _branches.map((b) => DropdownMenuItem<String>(value: b['id'], child: Text(b['name']))).toList(),
                onChanged: (val) => setState(() => _selectedBranchId = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(labelText: 'Structure Name (e.g. Senior Trainer)', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade400))),
              onSaved: (val) => _name = val ?? '',
              validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(labelText: 'Monthly Salary (Base Amount)', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade400))),
              keyboardType: TextInputType.number,
              onSaved: (val) => _amount = (int.tryParse(val ?? '0') ?? 0) * 100, // store as minor units
              validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Structure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}



