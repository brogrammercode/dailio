import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/branch_filter_tabs.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../../../core/widgets/dailio_qr_sheet.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../organization/controllers/organization_repository.dart';
import '../../context_selection/controllers/branch_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allPlans = [];
  final List<Map<String, dynamic>> _branches = [];
  String? _formBranchId;
  String? _error;

  String? _selectedFilterBranchId;
  int _selectedIndex = -1;
  bool _isSaving = false;
  bool _isCreating = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _joiningFeeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _graceDaysCtrl = TextEditingController();
  bool _isActive = true;

  bool get _canManage =>
      context.read<PreferencesStorage>().hasPermission('PLAN_MANAGE');

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PreferencesStorage>();
    _selectedFilterBranchId = prefs.activeBranchId;
    _loadPlans();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _joiningFeeCtrl.dispose();
    _durationCtrl.dispose();
    _graceDaysCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPlans {
    if (_selectedFilterBranchId == null) return _allPlans;
    if (_selectedFilterBranchId == 'none') {
      return _allPlans.where((p) => p['branch_id'] == null).toList();
    }
    return _allPlans
        .where((p) =>
            p['branch_id'] == _selectedFilterBranchId || p['branch_id'] == null)
        .toList();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repository = context.read<OrganizationRepository>();
      final prefs = context.read<PreferencesStorage>();
      final orgId = prefs.activeOrganizationId!;
      final plans = await repository.getOrganizationPlans(
        orgId,
        branchId: _selectedFilterBranchId,
        onFresh: (freshPlans) {
          if (!mounted) return;
          setState(() {
            _allPlans = freshPlans;
            if (_filteredPlans.isNotEmpty && !_isCreating) _selectPlan(0);
          });
        },
      );
      final branches = await repository.getOrganizationBranches(orgId);

      if (mounted) {
        setState(() {
          _allPlans = plans;
          _branches.clear();
          _branches.addAll(branches);
          _isLoading = false;
          if (_filteredPlans.isNotEmpty && !_isCreating) {
            _selectPlan(0);
          }
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

  void _selectPlan(int index) {
    setState(() {
      _isCreating = false;
      _selectedIndex = index;
      if (index >= 0 && index < _filteredPlans.length) {
        final plan = _filteredPlans[index];
        _nameCtrl.text = plan['name'] ?? '';
        _amountCtrl.text =
            ((plan['amount_minor_unit'] ?? 0) / 100).toStringAsFixed(0);
        _joiningFeeCtrl.text =
            ((plan['joining_fee_minor'] ?? 0) / 100).toStringAsFixed(0);
        _durationCtrl.text = (plan['duration_days'] ?? 0).toString();
        _graceDaysCtrl.text = (plan['grace_days'] ?? 0).toString();
        _isActive = plan['is_active'] ?? true;
        _formBranchId = plan['branch_id'];
      }
    });
  }

  void _startCreating() {
    if (!_canManage) return;
    setState(() {
      _isCreating = true;
      _selectedIndex = -1;
      _nameCtrl.clear();
      _amountCtrl.clear();
      _joiningFeeCtrl.clear();
      _durationCtrl.clear();
      _graceDaysCtrl.clear();
      _isActive = true;
      _formBranchId =
          (_selectedFilterBranchId != null && _selectedFilterBranchId != 'none')
              ? _selectedFilterBranchId
              : null;
    });
  }

  Future<void> _savePlan() async {
    if (!_canManage) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repository = context.read<OrganizationRepository>();
      final prefs = context.read<PreferencesStorage>();
      final orgId = prefs.activeOrganizationId!;

      final data = {
        'name': _nameCtrl.text,
        'amount_minor_unit': (double.parse(_amountCtrl.text) * 100).toInt(),
        'joining_fee_minor': (double.parse(
                    _joiningFeeCtrl.text.isEmpty ? '0' : _joiningFeeCtrl.text) *
                100)
            .toInt(),
        'duration_days': int.parse(_durationCtrl.text),
        'grace_days':
            int.parse(_graceDaysCtrl.text.isEmpty ? '0' : _graceDaysCtrl.text),
        'is_active': _isActive,
        'branch_id': _formBranchId,
      };

      if (_isCreating) {
        await repository.createPlan(orgId, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Plan created successfully'),
              backgroundColor: Colors.green));
        }
      } else {
        final planId = _filteredPlans[_selectedIndex]['id'];
        await repository.updatePlan(orgId, planId, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Plan updated successfully'),
              backgroundColor: Colors.green));
        }
      }

      await _loadPlans();
      if (mounted && _isCreating && _filteredPlans.isNotEmpty) {
        _selectPlan(_filteredPlans.length - 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save plan: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showPlanQr() async {
    if (!_canManage) return;
    if (_isCreating ||
        _selectedIndex < 0 ||
        _selectedIndex >= _filteredPlans.length) {
      return;
    }
    final plan = _filteredPlans[_selectedIndex];
    if (plan['is_active'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Only active plans can have a purchase QR.')));
      return;
    }
    final branchId =
        (plan['branch_id'] ?? context.read<PreferencesStorage>().activeBranchId)
            ?.toString();
    final planId = plan['id']?.toString();
    if (branchId == null || planId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select an active branch before creating a plan QR.')));
      return;
    }
    try {
      final invite = await context
          .read<BranchRepository>()
          .createPlanInvite(branchId, planId);
      if (!mounted) return;
      final payload = invite['qr_payload']?.toString();
      if (payload == null || payload.isEmpty) {
        throw Exception('Plan QR was not created');
      }
      await showDailioQrSheet(
        context,
        title: 'Plan QR',
        payload: payload,
        subtitle:
            '${plan['name'] ?? 'Plan'} • ${plan['currency'] ?? 'INR'} ${(plan['amount_minor_unit'] as num? ?? 0) / 100}',
        detail: 'Permanent QR for recurring member purchases.',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create plan QR: $error')));
      }
    }
  }

  // Legacy implementation retained temporarily for reference.
  // ignore: unused_element
  Future<void> _showLegacyPlanQr() async {
    if (!_canManage) return;
    if (_isCreating ||
        _selectedIndex < 0 ||
        _selectedIndex >= _filteredPlans.length) {
      return;
    }
    final plan = _filteredPlans[_selectedIndex];
    if (plan['is_active'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Only active plans can have a purchase QR.')));
      return;
    }
    final branchId =
        (plan['branch_id'] ?? context.read<PreferencesStorage>().activeBranchId)
            ?.toString();
    final planId = plan['id']?.toString();
    if (branchId == null || planId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select an active branch before creating a plan QR.')));
      return;
    }
    try {
      final invite = await context
          .read<BranchRepository>()
          .createPlanInvite(branchId, planId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Plan QR • ${plan['name'] ?? 'Plan'}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 220.r,
              height: 220.r,
              child: QrImageView(
                data: invite['qr_payload'].toString(),
                size: 220.r,
              ),
            ),
            SizedBox(height: 12.r),
            Text(
                '${plan['duration_days'] ?? 0} days • ${plan['currency'] ?? 'INR'} ${(plan['amount_minor_unit'] as num? ?? 0) / 100}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
                'Admission fee: ${plan['currency'] ?? 'INR'} ${((plan['joining_fee_minor'] as num? ?? 0) / 100).toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey, fontSize: 12.r)),
            SizedBox(height: 6.r),
            const Text('Permanent QR • no expiry or revocation',
                style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8.r),
            Text('Generating another QR never invalidates this one.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.r)),
          ]),
          actions: [
            TextButton(
                onPressed: () async {
                  await context.read<BranchRepository>().revokeInvite(
                      branchId, invite['id'].toString(),
                      planId: planId);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Revoke')),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Done'))
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create plan QR: $error')));
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
            label: 'Refresh plans',
          ),
        ],
        onMenuSelected: (_) => _loadPlans(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 8.r),
            BranchFilterTabs(
              selectedBranchId: _selectedFilterBranchId,
              onChanged: (val) {
                setState(() {
                  _selectedFilterBranchId = val;
                  _isCreating = false;
                  if (_filteredPlans.isNotEmpty) {
                    _selectPlan(0);
                  } else {
                    _selectedIndex = -1;
                  }
                });
              },
            ),
            SizedBox(height: 16.r),
            Expanded(
              child: _isLoading
                  ? _buildSkeleton()
                  : _error != null
                      ? _buildError()
                      : _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() => ShimmerLoader.planEditor();

  // Legacy skeleton retained temporarily for reference while the shared
  // plan-editor geometry is used by the page.
  // ignore: unused_element
  Widget _buildLegacySkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.r),
      child: Column(
        children: [
          Container(
              height: 120.r,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16.r))),
          SizedBox(height: 16.r),
          Row(children: [
            Container(
                height: 40.r,
                width: 100.r,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8.r))),
            SizedBox(width: 8.r),
            Container(
                height: 40.r,
                width: 100.r,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8.r))),
          ]),
          SizedBox(height: 24.r),
          Container(
              height: 300.r,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16.r))),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16.r, 4.r, 16.r, 120.r),
          children: [
            if (_filteredPlans.isEmpty && !_isCreating)
              _buildEmptyState()
            else
              _buildEditor(),
          ],
        ),
        if ((_filteredPlans.isNotEmpty || _isCreating) && _canManage)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 32.r),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10.r,
                    offset: Offset(0, (-4).r))
              ]),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.r),
                  minimumSize: const Size(double.infinity, 0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 24.r,
                        height: 24.r,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.r))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_isCreating ? 'Create Plan' : 'Save Changes',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16.r)),
                          SizedBox(width: 8.r),
                          Icon(Iconsax.save_2, size: 20.r),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }

  // Kept for the legacy layout contract; the page now uses the shared bar.
  // ignore: unused_element
  Widget _buildHeader(BuildContext context) {
    final prefs = context.read<PreferencesStorage>();
    return Padding(
      padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.r)),
            child: IconButton(
                icon: Icon(Iconsax.arrow_left, size: 20.r),
                onPressed: () => context.pop(),
                constraints: BoxConstraints(minWidth: 40.r, minHeight: 40.r),
                padding: EdgeInsets.zero),
          ),
          SizedBox(width: 16.r),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subscription Plans',
                    style:
                        TextStyle(fontSize: 20.r, fontWeight: FontWeight.bold)),
                Text(prefs.activeOrganizationName ?? 'Gym Management',
                    style: TextStyle(fontSize: 12.r, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Legacy catalog summary retained for compatibility with older routes.
  // ignore: unused_element
  Widget _buildCatalogHeader() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, size: 16.r, color: Colors.orange),
              SizedBox(width: 8.r),
              Text('Membership Plans Catalog',
                  style:
                      TextStyle(fontSize: 14.r, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12.r)),
                child: Row(
                  children: [
                    CircleAvatar(radius: 3.r, backgroundColor: Colors.green),
                    SizedBox(width: 4.r),
                    Text('Live Sync',
                        style: TextStyle(
                            fontSize: 9.r,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          SizedBox(height: 8.r),
          Text(
              'Configure branch-level commercial pricing, access rules, and membership perks.',
              style: TextStyle(fontSize: 11.r, color: Colors.grey)),
          SizedBox(height: 16.r),
          Row(
            children: [
              Expanded(
                  child: _buildStatBox(
                      'Active Tiers',
                      _filteredPlans
                          .where((p) => p['is_active'] == true)
                          .length
                          .toString()
                          .padLeft(2, '0'),
                      'Selected Branch',
                      null)),
              SizedBox(width: 8.r),
              Expanded(
                  child: _buildStatBox(
                      'Enrolled', '--', 'Coming Soon', Colors.green)),
              SizedBox(width: 8.r),
              Expanded(
                  child: _buildStatBox(
                      'Avg Amount',
                      _filteredPlans.isEmpty ? '\u20B90' : '\u20B9',
                      'Catalog Avg',
                      null)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatBox(
      String title, String value, String subtitle, Color? subtitleColor) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
          color: Colors.blue.shade50.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 10.r, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          SizedBox(height: 4.r),
          Text(value,
              style: TextStyle(fontSize: 16.r, fontWeight: FontWeight.bold)),
          SizedBox(height: 2.r),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 9.r,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor ?? Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.only(top: 48.r),
      child: Column(
        children: [
          Icon(Iconsax.card, size: 30.r, color: Colors.orange),
          SizedBox(height: 12.r),
          Text('No plans yet',
              style: TextStyle(fontSize: 15.r, fontWeight: FontWeight.w800)),
          SizedBox(height: 6.r),
          Text('Create a plan with its price and duration.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 11.r)),
          SizedBox(height: 18.r),
          ElevatedButton.icon(
            onPressed: _startCreating,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                padding:
                    EdgeInsets.symmetric(horizontal: 18.r, vertical: 11.r)),
            icon: Icon(Iconsax.add, size: 16.r),
            label: const Text('Create plan'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.warning_2, size: 48.r, color: Colors.red),
            SizedBox(height: 16.r),
            Text('Failed to load plans',
                style: TextStyle(fontSize: 16.r, fontWeight: FontWeight.bold)),
            SizedBox(height: 8.r),
            Text(_error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            SizedBox(height: 24.r),
            ElevatedButton(
                onPressed: _loadPlans,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
                child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlanTabs(),
        SizedBox(height: 16.r),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isCreating ? 'Create plan' : 'Plan details',
                      style: TextStyle(
                          fontSize: 15.r, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (!_isCreating)
                    IconButton(
                      tooltip: 'Show plan purchase QR',
                      onPressed: _showPlanQr,
                      icon: Icon(Iconsax.scan_barcode, size: 19.r),
                      padding: EdgeInsets.zero,
                      constraints:
                          BoxConstraints(minWidth: 32.r, minHeight: 32.r),
                    ),
                ],
              ),
              SizedBox(height: 14.r),
              if (_branches.isNotEmpty) ...[
                _buildFieldLabel('Branch'),
                DailioPickerField<String>(
                  initialValue: _formBranchId,
                  decoration: _buildInputDecoration(
                      'Select branch', Iconsax.building_4),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('No Branch (HQ)')),
                    ..._branches.map((b) => DropdownMenuItem<String>(
                        value: b['id'], child: Text(b['name']))),
                  ],
                  onChanged: _canManage
                      ? (val) => setState(() => _formBranchId = val)
                      : null,
                ),
                SizedBox(height: 14.r),
              ],
              _buildTextField('Plan name', _nameCtrl, 'e.g. 3 Months',
                  TextInputType.text, Iconsax.card),
              SizedBox(height: 14.r),
              _buildTextField('Plan amount (₹)', _amountCtrl, 'e.g. 2500',
                  TextInputType.number, Iconsax.wallet_2),
              SizedBox(height: 14.r),
              _buildTextField('Admission fee (₹)', _joiningFeeCtrl, '0 if none',
                  TextInputType.number, Iconsax.money_recive),
              SizedBox(height: 14.r),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('Duration (days)', _durationCtrl,
                        'e.g. 90', TextInputType.number, Iconsax.calendar_1),
                  ),
                  SizedBox(width: 12.r),
                  Expanded(
                    child: _buildTextField('Grace (days)', _graceDaysCtrl,
                        '0 if none', TextInputType.number, Iconsax.clock),
                  ),
                ],
              ),
              SizedBox(height: 14.r),
              _buildActiveRow(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanTabs() {
    if (_filteredPlans.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: DailioTabStrip<int>(
            tabs: List.generate(
              _filteredPlans.length,
              (index) => DailioTabItem<int>(
                value: index,
                label: _filteredPlans[index]['name'] ?? 'Plan ${index + 1}',
              ),
            ),
            selected: _isCreating ? -1 : _selectedIndex,
            onChanged: _selectPlan,
          ),
        ),
        if (_canManage)
          IconButton(
            tooltip: 'Create plan',
            onPressed: _startCreating,
            icon: const Icon(Iconsax.add_circle, color: Colors.orange),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 34.r, minHeight: 34.r),
          ),
      ],
    );
  }

  Widget _buildActiveRow() {
    return Row(
      children: [
        Icon(Iconsax.eye, size: 17.r, color: Colors.grey),
        SizedBox(width: 10.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available for purchase',
                  style:
                      TextStyle(fontSize: 12.r, fontWeight: FontWeight.w600)),
              Text('Members can see and buy this plan.',
                  style: TextStyle(fontSize: 10.r, color: Colors.grey)),
            ],
          ),
        ),
        Switch(
          value: _isActive,
          onChanged:
              _canManage ? (value) => setState(() => _isActive = value) : null,
          activeThumbColor: Colors.orange,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.r),
      child: Text(label,
          style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _buildInputDecoration(String hint, [IconData? icon]) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.r, color: Colors.grey),
      prefixIcon:
          icon == null ? null : Icon(icon, size: 16.r, color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(vertical: 13.r, horizontal: 14.r),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: Colors.orange.shade400, width: 1.5.r),
      ),
    );
  }

  // Legacy editor retained below temporarily for reference while the clean
  // plan form is rolled out.
  // ignore: unused_element
  Widget _buildLegacyEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...List.generate(_filteredPlans.length, (index) {
                final isActive = _selectedIndex == index && !_isCreating;
                return GestureDetector(
                  onTap: () => _selectPlan(index),
                  child: Container(
                    margin: EdgeInsets.only(right: 8.r),
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.r, vertical: 12.r),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.orange.shade800 : Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                          color: isActive
                              ? Colors.orange.shade800
                              : Colors.grey.shade200),
                    ),
                    child: Text(
                      _filteredPlans[index]['name'] ?? 'Unnamed Plan',
                      style: TextStyle(
                          fontSize: 12.r,
                          fontWeight: FontWeight.bold,
                          color:
                              isActive ? Colors.white : Colors.grey.shade700),
                    ),
                  ),
                );
              }),
              if (_canManage)
                GestureDetector(
                  onTap: _startCreating,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.r, vertical: 12.r),
                    decoration: BoxDecoration(
                      color: _isCreating
                          ? Colors.blue.shade600
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                          color: _isCreating
                              ? Colors.blue.shade600
                              : Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Iconsax.add,
                            size: 14.r,
                            color: _isCreating
                                ? Colors.white
                                : Colors.blue.shade700),
                        SizedBox(width: 4.r),
                        Text('New Plan',
                            style: TextStyle(
                                fontSize: 12.r,
                                fontWeight: FontWeight.bold,
                                color: _isCreating
                                    ? Colors.white
                                    : Colors.blue.shade700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 24.r),
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.shade200)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 4.r, backgroundColor: Colors.green),
                    SizedBox(width: 12.r),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active & Publicly Available',
                              style: TextStyle(
                                  fontSize: 12.r, fontWeight: FontWeight.bold)),
                          Text('Members can purchase this plan',
                              style: TextStyle(
                                  fontSize: 10.r, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: _canManage
                          ? (v) => setState(() => _isActive = v)
                          : null,
                      activeThumbColor: Colors.orange.shade800,
                    ),
                    if (!_isCreating)
                      IconButton(
                        tooltip: 'Show plan purchase QR',
                        onPressed: _showPlanQr,
                        icon: const Icon(Iconsax.scan_barcode),
                      ),
                  ],
                ),
                Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.r),
                    child: Divider(height: 1.r)),
                if (_branches.isNotEmpty) ...[
                  DailioPickerField<String>(
                    initialValue: _formBranchId,
                    decoration: const InputDecoration(
                        labelText: 'Branch', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('No Branch (HQ)')),
                      ..._branches.map((b) => DropdownMenuItem<String>(
                          value: b['id'], child: Text(b['name'])))
                    ],
                    onChanged: _canManage
                        ? (val) => setState(() => _formBranchId = val)
                        : null,
                  ),
                  SizedBox(height: 16.r),
                ],
                _buildTextField('Plan Name', _nameCtrl, 'e.g. Annual Elite',
                    TextInputType.text),
                SizedBox(height: 16.r),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField('Base Amount (\u20B9)',
                            _amountCtrl, '0', TextInputType.number)),
                    SizedBox(width: 12.r),
                    Expanded(
                        child: _buildTextField('Joining Fee (\u20B9)',
                            _joiningFeeCtrl, '0', TextInputType.number)),
                  ],
                ),
                SizedBox(height: 16.r),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField('Duration (Days)', _durationCtrl,
                            'e.g. 365', TextInputType.number)),
                    SizedBox(width: 12.r),
                    Expanded(
                        child: _buildTextField('Grace Period (Days)',
                            _graceDaysCtrl, 'e.g. 7', TextInputType.number)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      String hint, TextInputType type,
      [IconData? icon]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        TextFormField(
          controller: controller,
          enabled: _canManage,
          keyboardType: type,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          decoration: _buildInputDecoration(hint, icon),
          style: TextStyle(fontSize: 13.r),
        ),
      ],
    );
  }
}
