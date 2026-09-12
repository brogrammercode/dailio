import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/branch_filter_tabs.dart';
import '../../organization/controllers/organization_repository.dart';

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
        .where((p) => p['branch_id'] == _selectedFilterBranchId)
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
      final plans = await repository.getOrganizationPlans(orgId);

      if (mounted) {
        setState(() {
          _allPlans = plans;
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
    setState(() {
      _isCreating = true;
      _selectedIndex = -1;
      _nameCtrl.clear();
      _amountCtrl.clear();
      _joiningFeeCtrl.clear();
      _durationCtrl.clear();
      _graceDaysCtrl.clear();
      _isActive = true;
        _formBranchId = (_selectedFilterBranchId != null && _selectedFilterBranchId != 'none') ? _selectedFilterBranchId : null;
    });
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_formBranchId == null || _formBranchId == 'none') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select a specific branch for this plan'),
            backgroundColor: Colors.red));
        return;
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
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

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
              height: 120,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
                height: 40,
                width: 100,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 8),
            Container(
                height: 40,
                width: 100,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8))),
          ]),
          const SizedBox(height: 24),
          Container(
              height: 300,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16))),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
          children: [
            _buildCatalogHeader(),
            const SizedBox(height: 16),
            if (_filteredPlans.isEmpty && !_isCreating)
              _buildEmptyState()
            else
              _buildEditor(),
          ],
        ),
        if (_filteredPlans.isNotEmpty || _isCreating)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4))
              ]),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_isCreating ? 'Create Plan' : 'Save Changes',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          const Icon(Iconsax.save_2, size: 20),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final prefs = context.read<PreferencesStorage>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subscription Plans',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(prefs.activeOrganizationName ?? 'Gym Management',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Membership Plans Catalog',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const CircleAvatar(
                        radius: 3, backgroundColor: Colors.green),
                    const SizedBox(width: 4),
                    Text('Live Sync',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          const Text(
              'Configure branch-level commercial pricing, access rules, and membership perks.',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 16),
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
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatBox(
                      'Enrolled', '--', 'Coming Soon', Colors.green)),
              const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.blue.shade50.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor ?? Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: Colors.orange.shade50, shape: BoxShape.circle),
            child: const Icon(Iconsax.card, size: 40, color: Colors.orange),
          ),
          const SizedBox(height: 24),
          const Text('No Subscription Plans',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'Create membership tiers, set pricing, and configure durations to start admitting members.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _startCreating,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            icon: const Icon(Iconsax.add, size: 18),
            label: const Text('Create First Plan'),
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
            const Text('Failed to load plans',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...List.generate(_filteredPlans.length, (index) {
                final isActive = _selectedIndex == index && !_isCreating;
                return GestureDetector(
                  onTap: () => _selectPlan(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.orange.shade800 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isActive
                              ? Colors.orange.shade800
                              : Colors.grey.shade200),
                    ),
                    child: Text(
                      _filteredPlans[index]['name'] ?? 'Unnamed Plan',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isActive ? Colors.white : Colors.grey.shade700),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: _startCreating,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isCreating
                        ? Colors.blue.shade600
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _isCreating
                            ? Colors.blue.shade600
                            : Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.add,
                          size: 14,
                          color: _isCreating
                              ? Colors.white
                              : Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text('New Plan',
                          style: TextStyle(
                              fontSize: 12,
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
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                        radius: 4, backgroundColor: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active & Publicly Available',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('Members can purchase this plan',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeThumbColor: Colors.orange.shade800,
                    ),
                  ],
                ),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1)),
                if (_branches.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _formBranchId,
                      decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder()),
                      items: _branches.map((b) => DropdownMenuItem<String>(value: b['id'], child: Text(b['name']))).toList(),
                      onChanged: (val) => setState(() => _formBranchId = val), 
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildTextField('Plan Name', _nameCtrl, 'e.g. Annual Elite', TextInputType.text),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField('Base Amount (\u20B9)',
                            _amountCtrl, '0', TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildTextField('Joining Fee (\u20B9)',
                            _joiningFeeCtrl, '0', TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField('Duration (Days)', _durationCtrl,
                            'e.g. 365', TextInputType.number)),
                    const SizedBox(width: 12),
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
      String hint, TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: type,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}










