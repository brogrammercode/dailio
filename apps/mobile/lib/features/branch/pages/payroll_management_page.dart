import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/branch_filter_tabs.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../organization/controllers/organization_repository.dart';
import '../controllers/payroll_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  late final String _orgId;
  late final PayrollRepository _repo;
  int _selectedPrimaryTab = 0;

  @override
  void initState() {
    super.initState();
    final preferences = context.read<PreferencesStorage>();
    _repo = context.read<PayrollRepository>();
    _orgId = preferences.activeOrganizationId!;
    _selectedFilterBranchId = preferences.activeBranchId;
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final structures = await _repo.listSalaryStructures(
        _orgId,
        branchId: _selectedFilterBranchId,
        onFresh: (freshStructures) {
          if (mounted) setState(() => _structures = freshStructures);
        },
      );
      if (mounted) {
        setState(() {
          _structures = structures;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showFormModal({Map<String, dynamic>? structure}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (_) => _StructureFormSheet(
        orgId: _orgId,
        defaultBranchId: _selectedFilterBranchId,
        structureToEdit: structure,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> structure) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete structure?',
      message: 'This salary structure will no longer be available.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Iconsax.trash,
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteSalaryStructure(_orgId, structure['id'].toString());
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete structure: $error')),
      );
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
            label: 'Refresh payroll',
          ),
        ],
        onMenuSelected: (_) => _loadData(),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: 8.r),
                BranchFilterTabs(
                  selectedBranchId: _selectedFilterBranchId,
                  onChanged: (value) {
                    setState(() => _selectedFilterBranchId = value);
                    _loadData();
                  },
                ),
                SizedBox(height: 8.r),
                _buildPrimaryTabs(),
                SizedBox(height: 4.r),
                Expanded(
                  child: _selectedPrimaryTab == 1
                      ? _buildRunsEmpty()
                      : _isLoading
                          ? ShimmerLoader.settingsList()
                          : _error != null
                              ? _buildError()
                              : _structures.isEmpty
                                  ? _buildEmpty()
                                  : _buildList(),
                ),
              ],
            ),
            if (_selectedPrimaryTab == 0)
              Positioned(
                right: 16.r,
                bottom: 16.r,
                child: FloatingActionButton.small(
                  heroTag: 'add-salary-structure',
                  backgroundColor: const Color(0xFFCC5A00),
                  foregroundColor: Colors.white,
                  tooltip: 'Add salary structure',
                  onPressed: () => _showFormModal(),
                  child: Icon(Iconsax.add, size: 20.r),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryTabs() {
    return DailioTabStrip<int>(
      tabs: const [
        DailioTabItem(value: 0, label: 'Salary structures'),
        DailioTabItem(value: 1, label: 'Payroll runs'),
      ],
      selected: _selectedPrimaryTab,
      onChanged: (value) => setState(() => _selectedPrimaryTab = value),
    );
  }

  Widget _buildError() {
    return Center(
      child: TextButton.icon(
        onPressed: _loadData,
        icon: const Icon(Iconsax.refresh),
        label: const Text('Could not load payroll. Try again.'),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text('No salary structures yet',
          style: TextStyle(fontSize: 14.r, color: Color(0xFF858585))),
    );
  }

  Widget _buildRunsEmpty() {
    return Center(
      child: Text('No payroll runs yet',
          style: TextStyle(fontSize: 14.r, color: Color(0xFF858585))),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(0, 8.r, 0, 88.r),
      itemCount: _structures.length,
      separatorBuilder: (_, __) => Divider(height: 1.r, indent: 66.r),
      itemBuilder: (context, index) {
        final structure = _structures[index];
        final earnings = _items(structure['earnings']);
        final deductions = _items(structure['deductions']);
        final base = _money(_asInt(structure['amount']));
        final earningsTotal =
            earnings.fold<int>(0, (sum, item) => sum + _asInt(item['amount']));
        final deductionTotal = deductions.fold<int>(
            0, (sum, item) => sum + _asInt(item['amount']));
        final net = _money(
            _asInt(structure['amount']) + earningsTotal - deductionTotal);
        final branch = structure['branch'] is Map
            ? structure['branch']['name']?.toString()
            : null;
        final subtitle = [
          'Base $base',
          if (earnings.isNotEmpty)
            '${earnings.length} earning${earnings.length == 1 ? '' : 's'}',
          if (deductions.isNotEmpty)
            '${deductions.length} deduction${deductions.length == 1 ? '' : 's'}',
        ].join(' · ');

        return DailioCompactTile(
          avatar: CircleAvatar(
            radius: 22.r,
            backgroundColor: Color(0xFFFFF0E6),
            child: Icon(Iconsax.wallet_2, size: 20.r, color: Color(0xFFCC5A00)),
          ),
          title: structure['name']?.toString() ?? 'Unnamed structure',
          titleBadge: branch,
          statusBadge: 'Active',
          statusBadgeColor: const Color(0xFF2E9D59),
          subtitle: '$subtitle · Net $net',
          trailing: 'Monthly',
          menuItems: const [
            DailioMenuItem(
                value: 'edit', icon: Iconsax.edit_2, label: 'Edit structure'),
            DailioMenuItem(
                value: 'delete',
                icon: Iconsax.trash,
                label: 'Delete structure'),
          ],
          onMenuSelected: (value) {
            if (value == 'edit') {
              _showFormModal(structure: structure);
            } else {
              _confirmDelete(structure);
            }
          },
          onTap: () => _showFormModal(structure: structure),
        );
      },
    );
  }

  List<Map<String, dynamic>> _items(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(int minorUnits) {
    final amount = (minorUnits / 100).round();
    final digits = amount.toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'(?<=\d)(?=(\d\d)+\d$)'),
      (_) => ',',
    );
    return '₹$formatted';
  }
}

class _StructureFormSheet extends StatefulWidget {
  final String orgId;
  final String? defaultBranchId;
  final Map<String, dynamic>? structureToEdit;
  final VoidCallback onSaved;

  const _StructureFormSheet({
    required this.orgId,
    this.defaultBranchId,
    this.structureToEdit,
    required this.onSaved,
  });

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
    final existing = widget.structureToEdit;
    if (existing != null) {
      _name = existing['name']?.toString() ?? '';
      _amount = _asInt(existing['amount']);
      _selectedBranchId = existing['branch_id']?.toString();
      _earnings = _items(existing['earnings']);
      _deductions = _items(existing['deductions']);
    } else {
      _selectedBranchId =
          widget.defaultBranchId == 'none' ? null : widget.defaultBranchId;
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await context
          .read<OrganizationRepository>()
          .getOrganizationBranches(widget.orgId);
      if (mounted) {
        setState(() {
          _branches = branches;
          _isLoadingBranches = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBranches = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isSaving = true);
    try {
      final data = {
        'name': _name.trim(),
        'branch_id': _selectedBranchId,
        'amount': _amount,
        'earnings': _earnings,
        'deductions': _deductions,
      };
      final repository = context.read<PayrollRepository>();
      if (widget.structureToEdit != null) {
        await repository.updateSalaryStructure(
            widget.orgId, widget.structureToEdit!['id'].toString(), data);
      } else {
        await repository.createSalaryStructure(widget.orgId, data);
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $error')));
    }
  }

  List<Map<String, dynamic>> _items(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  InputDecoration _decoration(String hint, IconData icon) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: const BorderSide(color: Color(0xFFE4E4E4)),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.r, color: Color(0xFF929292)),
      prefixIcon: Icon(icon, size: 17.r, color: const Color(0xFF929292)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 13.r),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Color(0xFFCC5A00), width: 1.4.r),
      ),
    );
  }

  Widget _buildLineItems(
      String title, List<Map<String, dynamic>> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13.r, fontWeight: FontWeight.w800, color: color)),
            TextButton.icon(
              onPressed: () =>
                  setState(() => items.add({'label': '', 'amount': 0})),
              icon: Icon(Iconsax.add, size: 14.r, color: color),
              label:
                  Text('Add', style: TextStyle(fontSize: 12.r, color: color)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ],
        ),
        if (items.isEmpty)
          Text('None added',
              style: TextStyle(fontSize: 11.r, color: Color(0xFF929292))),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 8.r),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item['label']?.toString() ?? '',
                    decoration: _decoration('Label', Iconsax.tag),
                    onChanged: (value) => item['label'] = value,
                  ),
                ),
                SizedBox(width: 8.r),
                SizedBox(
                  width: 105.r,
                  child: TextFormField(
                    initialValue: _asInt(item['amount']) == 0
                        ? ''
                        : (_asInt(item['amount']) / 100).round().toString(),
                    keyboardType: TextInputType.number,
                    decoration: _decoration('₹ amount', Iconsax.money_2),
                    onChanged: (value) => item['amount'] = _asInt(value) * 100,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => items.removeAt(index)),
                  icon: Icon(Iconsax.trash, size: 17.r, color: Colors.red),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.structureToEdit != null;
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.r, 10.r, 16.r, 16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 34.r,
                    height: 4.r,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD5D5D5),
                        borderRadius: BorderRadius.circular(99.r)),
                  ),
                ),
                SizedBox(height: 16.r),
                Text(editing ? 'Edit salary structure' : 'New salary structure',
                    style:
                        TextStyle(fontSize: 18.r, fontWeight: FontWeight.w800)),
                SizedBox(height: 4.r),
                Text('Define the monthly pay and adjustments.',
                    style: TextStyle(fontSize: 12.r, color: Color(0xFF858585))),
                SizedBox(height: 18.r),
                if (!_isLoadingBranches) ...[
                  DailioPickerField<String>(
                    initialValue: _selectedBranchId,
                    decoration: _decoration('Branch', Iconsax.location),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('No branch (HQ)')),
                      ..._branches.map((branch) => DropdownMenuItem<String>(
                          value: branch['id'], child: Text(branch['name'])))
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedBranchId = value),
                  ),
                  SizedBox(height: 12.r),
                ],
                TextFormField(
                  initialValue: _name,
                  decoration: _decoration('Structure name', Iconsax.edit_2),
                  onSaved: (value) => _name = value?.trim() ?? '',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 12.r),
                TextFormField(
                  initialValue:
                      editing ? (_amount / 100).round().toString() : '',
                  keyboardType: TextInputType.number,
                  decoration:
                      _decoration('Monthly base salary', Iconsax.money_2),
                  onSaved: (value) => _amount = _asInt(value) * 100,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 18.r),
                _buildLineItems('Earnings', _earnings, const Color(0xFF2E9D59)),
                SizedBox(height: 12.r),
                _buildLineItems(
                    'Deductions', _deductions, const Color(0xFFC44545)),
                SizedBox(height: 16.r),
                SizedBox(
                  width: double.infinity,
                  height: 46.r,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC5A00),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 18.r,
                            height: 18.r,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.r))
                        : Text(editing ? 'Save changes' : 'Create structure'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
