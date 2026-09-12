import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/branch_filter_tabs.dart';
import '../../organization/controllers/organization_repository.dart';
import '../controllers/shift_repository.dart';

class ShiftManagementPage extends StatefulWidget {
  const ShiftManagementPage({super.key});

  @override
  State<ShiftManagementPage> createState() => _ShiftManagementPageState();
}

class _ShiftManagementPageState extends State<ShiftManagementPage> {
  String? _selectedFilterBranchId;
  late final String _orgId;
  late final ShiftRepository _repo;

  List<Map<String, dynamic>> _shifts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedFilterBranchId = context.read<PreferencesStorage>().activeBranchId;
    _orgId = context.read<PreferencesStorage>().activeOrganizationId!;
    _repo = context.read<ShiftRepository>();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.listShifts(_orgId, branchId: _selectedFilterBranchId == 'none' ? null : _selectedFilterBranchId);
      if (mounted) setState(() => _shifts = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showShiftModal({Map<String, dynamic>? shift}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ShiftFormSheet(
        orgId: _orgId,
        defaultBranchId: _selectedFilterBranchId,
        shiftToEdit: shift,
        onSaved: _loadShifts,
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
                    _loadShifts();
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? _buildSkeleton()
                      : _error != null
                          ? Center(child: Text('Error: $_error'))
                          : _shifts.isEmpty
                              ? _buildEmptyState()
                              : _buildShiftsList(),
                )
              ],
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: () => _showShiftModal(),
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
                    Text('New Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                Text('Shift Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Configure timings and rosters', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
          Icon(Iconsax.clock, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No Shifts Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Create a shift to manage staff timings.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  Widget _buildShiftsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: _shifts.length,
      itemBuilder: (context, index) {
        final shift = _shifts[index];
        final tIn = shift['time_in'] ?? '00:00';
        final tOut = shift['time_out'] ?? '00:00';
        
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
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(Iconsax.clock, color: Colors.blue.shade700, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shift['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('$tIn - $tOut', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Iconsax.edit, size: 18, color: Colors.blue),
                onPressed: () => _showShiftModal(shift: shift),
              ),
              IconButton(
                icon: const Icon(Iconsax.trash, size: 18, color: Colors.red),
                onPressed: () async {
                  await _repo.deleteShift(_orgId, shift['id']);
                  _loadShifts();
                },
              )
            ],
          ),
        );
      },
    );
  }
}

class _ShiftFormSheet extends StatefulWidget {
  final String orgId;
  final String? defaultBranchId;
  final Map<String, dynamic>? shiftToEdit;
  final VoidCallback onSaved;

  const _ShiftFormSheet({required this.orgId, this.defaultBranchId, this.shiftToEdit, required this.onSaved});

  @override
  State<_ShiftFormSheet> createState() => _ShiftFormSheetState();
}

class _ShiftFormSheetState extends State<_ShiftFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _timeIn = '09:00';
  String _timeOut = '18:00';
  bool _isOvernight = false;
  String? _selectedBranchId;
  
  List<Map<String, dynamic>> _branches = [];
  bool _isLoadingBranches = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.shiftToEdit != null) {
      _name = widget.shiftToEdit!['name'] ?? '';
      _timeIn = widget.shiftToEdit!['time_in'] ?? '09:00';
      _timeOut = widget.shiftToEdit!['time_out'] ?? '18:00';
      _isOvernight = widget.shiftToEdit!['is_overnight'] ?? false;
      _selectedBranchId = widget.shiftToEdit!['branch_id'];
    } else {
      _selectedBranchId = widget.defaultBranchId == 'none' ? null : widget.defaultBranchId;
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
      final repo = context.read<ShiftRepository>();
      final data = {
        'name': _name,
        'branch_id': _selectedBranchId,
        'time_in': _timeIn,
        'time_out': _timeOut,
        'is_overnight': _isOvernight,
      };
      
      if (widget.shiftToEdit != null) {
        await repo.updateShift(widget.orgId, widget.shiftToEdit!['id'], data);
      } else {
        await repo.createShift(widget.orgId, data);
      }
      
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
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
            Text(widget.shiftToEdit != null ? 'Edit Shift' : 'New Shift', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 24),
            if (!_isLoadingBranches)
              DropdownButtonFormField<String>(
                value: _selectedBranchId,
                decoration: InputDecoration(labelText: 'Branch', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black))),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('No Branch (HQ)')),
                  ..._branches.map((b) => DropdownMenuItem<String>(value: b['id'], child: Text(b['name'])))
                ],
                onChanged: (val) => setState(() => _selectedBranchId = val),
              ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _name,
              decoration: InputDecoration(labelText: 'Shift Name', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black))),
              onSaved: (val) => _name = val ?? '',
              validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _timeIn,
                    decoration: InputDecoration(labelText: 'Time In (HH:MM)', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black))),
                    onSaved: (val) => _timeIn = val ?? '09:00',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _timeOut,
                    decoration: InputDecoration(labelText: 'Time Out (HH:MM)', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black))),
                    onSaved: (val) => _timeOut = val ?? '18:00',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Overnight Shift', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: const Text('Check if shift crosses midnight', style: TextStyle(fontSize: 12, color: Colors.grey)),
              value: _isOvernight,
              onChanged: (val) => setState(() => _isOvernight = val),
              activeColor: Colors.black,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(widget.shiftToEdit != null ? 'Save Changes' : 'Create Shift', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
