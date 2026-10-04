import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/branch_filter_tabs.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../organization/controllers/organization_repository.dart';
import '../controllers/shift_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      final data = await _repo.listShifts(
        _orgId,
        branchId:
            _selectedFilterBranchId == 'none' ? null : _selectedFilterBranchId,
        onFresh: (freshShifts) {
          if (mounted) setState(() => _shifts = freshShifts);
        },
      );
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
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
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh shifts',
          ),
        ],
        onMenuSelected: (_) => _loadShifts(),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: 8.r),
                BranchFilterTabs(
                  selectedBranchId: _selectedFilterBranchId,
                  onChanged: (val) {
                    setState(() => _selectedFilterBranchId = val);
                    _loadShifts();
                  },
                ),
                SizedBox(height: 8.r),
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
              right: 16.r,
              bottom: 16.r,
              child: FloatingActionButton.small(
                heroTag: 'add-shift',
                backgroundColor: const Color(0xFFCC5A00),
                foregroundColor: Colors.white,
                tooltip: 'Add shift',
                onPressed: () => _showShiftModal(),
                child: Icon(Iconsax.add, size: 20.r),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Kept for the legacy layout contract; the page now uses the shared bar.
  // ignore: unused_element
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.r)),
            child: IconButton(
              icon: Icon(Iconsax.arrow_left, size: 20.r),
              onPressed: () => context.pop(),
              constraints: BoxConstraints(minWidth: 40.r, minHeight: 40.r),
              padding: EdgeInsets.zero,
            ),
          ),
          SizedBox(width: 12.r),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shift Management',
                    style:
                        TextStyle(fontSize: 20.r, fontWeight: FontWeight.bold)),
                SizedBox(height: 4.r),
                Text('Configure timings and rosters',
                    style: TextStyle(fontSize: 10.r, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() => ShimmerLoader.settingsList();

  // Legacy skeleton retained temporarily for reference while the shared
  // compact-row geometry is used by the page.
  // ignore: unused_element
  Widget _buildLegacySkeleton() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.r, 0, 16.r, 100.r),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: EdgeInsets.only(bottom: 12.r),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: Container(
                  width: 48.r,
                  height: 48.r,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r))),
            ),
            SizedBox(width: 16.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                          width: 120.r, height: 14.r, color: Colors.white)),
                  SizedBox(height: 8.r),
                  Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                          width: 80.r, height: 12.r, color: Colors.white)),
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
          Icon(Iconsax.clock, size: 34.r, color: Colors.grey.shade400),
          SizedBox(height: 10.r),
          Text('No shifts yet',
              style: TextStyle(fontSize: 15.r, fontWeight: FontWeight.w700)),
          SizedBox(height: 4.r),
          Text('Add the first working schedule.',
              style: TextStyle(color: Colors.grey, fontSize: 12.r)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String title, VoidCallback onConfirm) async {
    final confirm = await showConfirmDialog(
      context,
      title: title,
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Iconsax.trash,
    );
    if (confirm == true) onConfirm();
  }

  Widget _buildShiftsList() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(0, 8.r, 0, 88.r),
      itemCount: _shifts.length,
      separatorBuilder: (_, __) => Divider(height: 1.r, indent: 66.r),
      itemBuilder: (context, index) {
        final shift = _shifts[index];
        final tIn = shift['start_time'] ?? '00:00';
        final tOut = shift['end_time'] ?? '00:00';
        final isOvernight = shift['is_overnight'] ?? false;
        final breakMins = shift['break_minutes'] ?? 0;
        final graceIn = shift['grace_in_min'] ?? 0;

        return DailioCompactTile(
          avatar: CircleAvatar(
            radius: 22.r,
            backgroundColor:
                isOvernight ? const Color(0xFFF0EEFF) : const Color(0xFFFFF0E6),
            child: Icon(isOvernight ? Iconsax.moon : Iconsax.sun_1,
                size: 20.r,
                color: isOvernight
                    ? const Color(0xFF635BBD)
                    : const Color(0xFFCC5A00)),
          ),
          title: shift['name'] ?? 'Unnamed shift',
          titleBadge: isOvernight ? 'Overnight' : null,
          subtitle: '$tIn – $tOut · Break $breakMins min · Grace $graceIn min',
          trailing: '7 days',
          menuItems: [
            const DailioMenuItem(
                value: 'edit', icon: Iconsax.edit_2, label: 'Edit shift'),
            const DailioMenuItem(
                value: 'delete', icon: Iconsax.trash, label: 'Delete shift'),
          ],
          onMenuSelected: (value) {
            if (value == 'edit') {
              _showShiftModal(shift: shift);
            } else {
              _confirmDelete(context, 'Delete shift', () async {
                await _repo.deleteShift(_orgId, shift['id']);
                _loadShifts();
              });
            }
          },
          onTap: () => _showShiftModal(shift: shift),
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

  const _ShiftFormSheet(
      {required this.orgId,
      this.defaultBranchId,
      this.shiftToEdit,
      required this.onSaved});

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
      _timeIn = widget.shiftToEdit!['start_time'] ?? '09:00';
      _timeOut = widget.shiftToEdit!['end_time'] ?? '18:00';
      _isOvernight = widget.shiftToEdit!['is_overnight'] ?? false;
      _selectedBranchId = widget.shiftToEdit!['branch_id'];
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
      final repo = context.read<ShiftRepository>();
      final data = {
        'name': _name,
        'branch_id': _selectedBranchId,
        'start_time': _timeIn,
        'end_time': _timeOut,
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: const BorderSide(color: Color(0xFFE4E4E4)),
    );
    InputDecoration fieldDecoration(String hint, IconData icon) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13.r, color: Color(0xFF929292)),
        prefixIcon: Icon(icon, size: 17.r, color: const Color(0xFF929292)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 13.r),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Color(0xFFCC5A00), width: 1.4.r),
        ),
      );
    }

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
                      borderRadius: BorderRadius.circular(99.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.r),
                Text(widget.shiftToEdit != null ? 'Edit shift' : 'New shift',
                    style:
                        TextStyle(fontSize: 18.r, fontWeight: FontWeight.w800)),
                SizedBox(height: 4.r),
                Text('Set the working hours used for attendance.',
                    style: TextStyle(fontSize: 12.r, color: Color(0xFF858585))),
                SizedBox(height: 18.r),
                if (!_isLoadingBranches) ...[
                  DailioPickerField<String>(
                    initialValue: _selectedBranchId,
                    decoration: fieldDecoration('Branch', Iconsax.location),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('No branch (HQ)')),
                      ..._branches.map((b) => DropdownMenuItem<String>(
                          value: b['id'], child: Text(b['name'])))
                    ],
                    onChanged: (val) => setState(() => _selectedBranchId = val),
                  ),
                  SizedBox(height: 12.r),
                ],
                TextFormField(
                  initialValue: _name,
                  decoration: fieldDecoration('Shift name', Iconsax.edit_2),
                  onSaved: (val) => _name = val?.trim() ?? '',
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: 12.r),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _timeIn,
                        decoration:
                            fieldDecoration('Starts (HH:MM)', Iconsax.login),
                        onSaved: (val) => _timeIn = val?.trim() ?? '09:00',
                      ),
                    ),
                    SizedBox(width: 10.r),
                    Expanded(
                      child: TextFormField(
                        initialValue: _timeOut,
                        decoration:
                            fieldDecoration('Ends (HH:MM)', Iconsax.logout),
                        onSaved: (val) => _timeOut = val?.trim() ?? '18:00',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.r),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Overnight',
                      style: TextStyle(
                          fontSize: 13.r, fontWeight: FontWeight.w700)),
                  subtitle: Text('Ends on the next day',
                      style:
                          TextStyle(fontSize: 11.r, color: Color(0xFF858585))),
                  value: _isOvernight,
                  onChanged: (value) => setState(() => _isOvernight = value),
                  activeThumbColor: const Color(0xFFCC5A00),
                ),
                SizedBox(height: 10.r),
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
                        : Text(widget.shiftToEdit != null
                            ? 'Save changes'
                            : 'Create shift'),
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
