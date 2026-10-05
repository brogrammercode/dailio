import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/storage/json_cache_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../../core/widgets/dailio_qr_sheet.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/meals_repository.dart';
import '../widgets/meal_ui.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  late final MealsRepository _repository;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _entitlements = [];
  String? _memberId;
  String? _slotId;
  String? _planId;
  Map<String, dynamic>? _eligibility;
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _busy = false;
  String _tab = 'Serve';

  String? get _branchId => context.read<PreferencesStorage>().activeBranchId;
  String? get _organizationId =>
      context.read<PreferencesStorage>().activeOrganizationId;
  bool get _canServe =>
      context.read<PreferencesStorage>().hasPermission('MEAL_SERVE');
  bool get _canManage =>
      context.read<PreferencesStorage>().hasPermission('MEAL_MANAGE');

  List<String> get _tabs => [
        if (_canServe) 'Serve',
        if (_canManage) 'Configure',
      ];

  @override
  void initState() {
    super.initState();
    _repository = MealsRepository(
      context.read<ApiClient>(),
      cache: context.read<JsonCacheStore?>(),
    );
    _load();
  }

  Future<void> _load() async {
    final branchId = _branchId;
    if (branchId == null) {
      setState(() {
        _loading = false;
        _error = 'Choose a branch to view meal operations.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slots = await _repository.slots(branchId);
      final members = _canServe
          ? await _repository.members(branchId, _search.text.trim())
          : <Map<String, dynamic>>[];
      final plans = _canManage && _organizationId != null
          ? await _repository.plans(_organizationId!)
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      final activeSlot = slots
          .where((slot) => slot['is_active'] == true)
          .firstOrNull?['id']
          ?.toString();
      setState(() {
        _slots = slots;
        _members = members;
        _plans = plans;
        _slotId ??= activeSlot;
        _loading = false;
        if (!_tabs.contains(_tab) && _tabs.isNotEmpty) _tab = _tabs.first;
      });
      if (_memberId != null && _slotId != null) await _checkEligibility();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _searchMembers() async {
    final branchId = _branchId;
    if (branchId == null || !_canServe) return;
    try {
      final members = await _repository.members(branchId, _search.text.trim());
      if (mounted) setState(() => _members = members);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _checkEligibility() async {
    final branchId = _branchId;
    if (branchId == null || _memberId == null || _slotId == null) {
      if (mounted) setState(() => _eligibility = null);
      return;
    }
    try {
      final result = await _repository.eligibility(
        branchId,
        _slotId!,
        _memberId!,
      );
      if (mounted) setState(() => _eligibility = result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _eligibility = null;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _serve() async {
    if (_branchId == null || _memberId == null || _slotId == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm meal attendance?',
      message: 'This records one confirmed serving for the selected member.',
      confirmLabel: 'Mark attendance',
      icon: Iconsax.tick_circle,
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.serve(_branchId!, _memberId!, _slotId!);
      if (mounted) setState(() => _notice = 'Meal attendance marked.');
      await _checkEligibility();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSlot([Map<String, dynamic>? slot]) async {
    final code = TextEditingController(text: slot?['code']?.toString() ?? '');
    final name = TextEditingController(text: slot?['name']?.toString() ?? '');
    final start = TextEditingController(
      text: slot?['starts_at_local']?.toString() ?? '07:00',
    );
    final end = TextEditingController(
      text: slot?['ends_at_local']?.toString() ?? '10:00',
    );
    var active = slot?['is_active'] != false;
    final input = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => _MealEditorSheet(
          title: slot == null ? 'Add meal slot' : 'Edit meal slot',
          code: code,
          name: name,
          start: start,
          end: end,
          active: active,
          onActiveChanged: (value) => update(() => active = value),
          onCancel: () => Navigator.pop(sheetContext),
          onSave: () => Navigator.pop(sheetContext, {
            'code': code.text.trim(),
            'name': name.text.trim(),
            'starts_at_local': start.text.trim(),
            'ends_at_local': end.text.trim(),
            'is_active': active,
          }),
        ),
      ),
    );
    code.dispose();
    name.dispose();
    start.dispose();
    end.dispose();
    if (input == null || _branchId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.saveSlot(
        _branchId!,
        input,
        id: slot?['id']?.toString(),
      );
      if (mounted) setState(() => _notice = 'Meal slot saved.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadEntitlements(String planId) async {
    if (_branchId == null) return;
    try {
      final rows = await _repository.entitlements(_branchId!, planId);
      if (mounted) {
        setState(() {
          _planId = planId;
          _entitlements = rows;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _editEntitlement(Map<String, dynamic> slot) async {
    if (_planId == null || _branchId == null) return;
    final current = _entitlements
        .where((item) => item['meal_slot_id'] == slot['id'])
        .firstOrNull;
    final limit = TextEditingController(
      text: '${current?['max_servings_per_day'] ?? 1}',
    );
    var active = current?['is_active'] == true;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => _EntitlementSheet(
          title: '${slot['name']} entitlement',
          limit: limit,
          active: active,
          onActiveChanged: (value) => update(() => active = value),
          onCancel: () => Navigator.pop(sheetContext),
          onSave: () => Navigator.pop(sheetContext, {
            'limit': limit.text.trim(),
            'active': active,
          }),
        ),
      ),
    );
    limit.dispose();
    if (result == null) return;
    final value = int.tryParse(result['limit'].toString());
    if (value == null || value < 1 || value > 10) {
      setState(() => _error = 'Servings per day must be between 1 and 10.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.setEntitlement(
        _branchId!,
        _planId!,
        slot['id'].toString(),
        value,
        result['active'] == true,
      );
      await _loadEntitlements(_planId!);
      if (mounted) setState(() => _notice = 'Plan entitlement saved.');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final activeTab = tabs.contains(_tab) ? _tab : tabs.firstOrNull;
    return Scaffold(
      backgroundColor: MealUi.canvas,
      appBar: DailioSimpleAppBar(
        menuItems: const [
          DailioMenuItem(
              value: 'refresh', icon: Iconsax.refresh, label: 'Refresh'),
        ],
        onMenuSelected: (_) => _load(),
      ),
      body: _loading
          ? ShimmerLoader.meals()
          : tabs.isEmpty
              ? _forbiddenState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.brandAccent,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 100.r),
                    children: [
                      Text(
                        'Meals',
                        style: TextStyle(
                          color: AppColors.brandDark,
                          fontSize: 20.r,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4.r),
                      Text(
                        context.read<PreferencesStorage>().activeBranchName ??
                            'Branch operations',
                        style: TextStyle(color: MealUi.muted, fontSize: 11.r),
                      ),
                      SizedBox(height: 12.r),
                      DailioTabStrip<String>(
                        tabs: tabs
                            .map((tab) => DailioTabItem(value: tab, label: tab))
                            .toList(),
                        selected: activeTab!,
                        onChanged: (tab) => setState(() => _tab = tab),
                      ),
                      SizedBox(height: 14.r),
                      if (_error != null) _message(_error!, error: true),
                      if (_notice != null) _message(_notice!),
                      if (activeTab == 'Serve') _register(),
                      if (activeTab == 'Configure') _configuration(),
                    ],
                  ),
                ),
    );
  }

  Widget _forbiddenState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.r),
        child: MealPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.lock, size: 28.r, color: MealUi.muted),
              SizedBox(height: 10.r),
              Text(
                'Meal operations are not enabled for this account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.r, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(String value, {bool error = false}) {
    final color = error ? MealUi.negative : AppColors.brandAccent;
    return Container(
      margin: EdgeInsets.only(bottom: 12.r),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(value, style: TextStyle(color: color, fontSize: 11.r)),
    );
  }

  Widget _register() {
    final activeSlots = _slots.where((slot) => slot['is_active'] == true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MealSectionHeader(
          title: 'Mark meal attendance',
          subtitle: 'Select a member and the meal they received.',
        ),
        MealPanel(
          child: Column(
            children: [
              TextField(
                controller: _search,
                style: TextStyle(fontSize: 13.r),
                decoration: MealUi.inputDecoration(
                  hint: 'Search member',
                  icon: Iconsax.search_normal,
                  suffix: IconButton(
                    tooltip: 'Search',
                    onPressed: _searchMembers,
                    icon: Icon(Iconsax.search_normal, size: 16.r),
                  ),
                ),
                onSubmitted: (_) => _searchMembers(),
              ),
              SizedBox(height: 10.r),
              MealUi.fieldLabel('Member'),
              DailioPickerField<String>(
                key: ValueKey(_memberId ?? ''),
                initialValue: _members.any((item) => item['id'] == _memberId)
                    ? _memberId
                    : null,
                decoration: MealUi.inputDecoration(
                  hint: 'Select member',
                  icon: Iconsax.personalcard,
                ),
                items: _members
                    .map(
                      (member) => DropdownMenuItem<String>(
                        value: member['id'].toString(),
                        child: Text(
                          '${(member['user'] as Map?)?['name'] ?? 'Member'}',
                          style: TextStyle(fontSize: 13.r),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _memberId = value);
                  _checkEligibility();
                },
              ),
              SizedBox(height: 10.r),
              MealUi.fieldLabel('Meal window'),
              DailioPickerField<String>(
                key: ValueKey(_slotId ?? ''),
                initialValue: activeSlots.any((item) => item['id'] == _slotId)
                    ? _slotId
                    : null,
                decoration: MealUi.inputDecoration(
                  hint: 'Select meal window',
                  icon: Iconsax.cup,
                ),
                items: activeSlots
                    .map(
                      (slot) => DropdownMenuItem<String>(
                        value: slot['id'].toString(),
                        child: Text(
                          '${slot['name']}  ·  ${slot['starts_at_local']}–${slot['ends_at_local']}',
                          style: TextStyle(fontSize: 13.r),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _slotId = value);
                  _checkEligibility();
                },
              ),
              if (_eligibility != null) ...[
                SizedBox(height: 10.r),
                _message(
                  _eligibility!['entitled'] == true
                      ? '${_eligibility!['remaining']} of ${_eligibility!['max_servings_per_day']} remaining today${_eligibility!['window_open'] == true ? '' : ' · Window closed'}'
                      : 'No active subscription includes this meal.',
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy || _eligibility?['eligible'] != true
                      ? null
                      : _serve,
                  icon: _busy
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Iconsax.tick_circle, size: 17.r),
                  label: Text(_busy ? 'Saving…' : 'Mark attendance'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _configuration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MealSectionHeader(
          title: 'Meal windows',
          subtitle: 'Configure the breakfast, lunch, and dinner schedule.',
          action: TextButton.icon(
            onPressed: _busy ? null : () => _editSlot(),
            icon: Icon(Iconsax.add, size: 15.r),
            label: const Text('Add'),
          ),
        ),
        MealPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: _slots.isEmpty
                ? [
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Text(
                        'No meal windows configured yet.',
                        style: TextStyle(color: MealUi.muted, fontSize: 12.r),
                      ),
                    ),
                  ]
                : _slots
                    .map(
                      (slot) => _mealRow(
                        icon: Iconsax.clock,
                        title: '${slot['name']}',
                        subtitle:
                            '${slot['starts_at_local']}–${slot['ends_at_local']}',
                        badge: slot['is_active'] == true ? 'ACTIVE' : 'OFF',
                        onTap: _busy ? null : () => _editSlot(slot),
                      ),
                    )
                    .toList(),
          ),
        ),
        SizedBox(height: 20.r),
        const MealSectionHeader(
          title: 'Plan entitlements',
          subtitle: 'Meal access updates active and future subscriptions.',
        ),
        MealPanel(
          child: Column(
            children: [
              MealUi.fieldLabel('Plan'),
              DailioPickerField<String>(
                key: ValueKey(_planId ?? ''),
                initialValue: _plans.any((item) => item['id'] == _planId)
                    ? _planId
                    : null,
                decoration: MealUi.inputDecoration(
                  hint: 'Select plan',
                  icon: Iconsax.card,
                ),
                items: _plans
                    .map(
                      (plan) => DropdownMenuItem<String>(
                        value: plan['id'].toString(),
                        child: Text(
                          '${plan['name']}',
                          style: TextStyle(fontSize: 13.r),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _loadEntitlements(value);
                },
              ),
              SizedBox(height: 14.r),
              if (_planId != null) ...[
                SizedBox(height: 10.r),
                ..._slots.map((slot) {
                  final entitlement = _entitlements
                      .where((item) => item['meal_slot_id'] == slot['id'])
                      .firstOrNull;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.r),
                    child: _mealRow(
                      icon: Iconsax.cup,
                      title: '${slot['name']}',
                      subtitle: entitlement?['is_active'] == true
                          ? '${entitlement?['max_servings_per_day']} serving(s) per day'
                          : 'Not included in this plan',
                      badge: entitlement?['is_active'] == true ? 'ON' : 'OFF',
                      onTap: _busy ? null : () => _editEntitlement(slot),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        SizedBox(height: 20.r),
        const MealSectionHeader(
          title: 'Printed meal QR',
          subtitle: 'Put this permanent QR at the mess counter.',
        ),
        MealPanel(
          child: Row(
            children: [
              Container(
                width: 38.r,
                height: 38.r,
                decoration: BoxDecoration(
                  color: AppColors.brandAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Iconsax.scan_barcode,
                    size: 19.r, color: AppColors.brandAccent),
              ),
              SizedBox(width: 11.r),
              Expanded(
                child: Text(
                  'Members scan this QR and select the meal they are receiving.',
                  style: TextStyle(color: MealUi.muted, fontSize: 11.r),
                ),
              ),
              IconButton(
                tooltip: 'Show meal QR',
                onPressed: _showMealQr,
                icon: Icon(Iconsax.arrow_right_3, size: 17.r),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mealRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.r, 10.r, 10.r, 10.r),
        child: Row(
          children: [
            Container(
              width: 34.r,
              height: 34.r,
              decoration: BoxDecoration(
                color: AppColors.brandAccent.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16.r, color: AppColors.brandAccent),
            ),
            SizedBox(width: 10.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.r, fontWeight: FontWeight.w700)),
                  SizedBox(height: 3.r),
                  Text(subtitle,
                      style: TextStyle(color: MealUi.muted, fontSize: 10.r)),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7.r, vertical: 4.r),
              decoration: BoxDecoration(
                color:
                    (badge == 'OFF' ? MealUi.negative : AppColors.brandAccent)
                        .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(5.r),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color:
                      badge == 'OFF' ? MealUi.negative : AppColors.brandAccent,
                  fontSize: 9.r,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: 6.r),
              Icon(Iconsax.arrow_right_3, size: 15.r, color: MealUi.muted),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showMealQr() async {
    try {
      final invite = await _repository.createMealInvite(_branchId!);
      if (!mounted) return;
      final payload = invite['qr_payload']?.toString();
      if (payload == null || payload.isEmpty) {
        throw Exception('QR was not created');
      }
      await showDailioQrSheet(
        context,
        title: 'Meal attendance QR',
        payload: payload,
        subtitle: context.read<PreferencesStorage>().activeBranchName,
        detail: 'Keep this QR at the counter. It is permanent and reusable.',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create meal QR: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

class _MealEditorSheet extends StatelessWidget {
  final String title;
  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController start;
  final TextEditingController end;
  final bool active;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _MealEditorSheet({
    required this.title,
    required this.code,
    required this.name,
    required this.start,
    required this.end,
    required this.active,
    required this.onActiveChanged,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: title,
      onCancel: onCancel,
      onSave: onSave,
      children: [
        _label('Identifier'),
        TextField(
          controller: code,
          style: TextStyle(fontSize: 13.r),
          decoration:
              MealUi.inputDecoration(hint: 'breakfast', icon: Iconsax.tag),
        ),
        SizedBox(height: 12.r),
        _label('Display name'),
        TextField(
          controller: name,
          style: TextStyle(fontSize: 13.r),
          decoration:
              MealUi.inputDecoration(hint: 'Breakfast', icon: Iconsax.text),
        ),
        SizedBox(height: 12.r),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: start,
                style: TextStyle(fontSize: 13.r),
                decoration: MealUi.inputDecoration(
                    label: 'Starts', icon: Iconsax.clock),
              ),
            ),
            SizedBox(width: 10.r),
            Expanded(
              child: TextField(
                controller: end,
                style: TextStyle(fontSize: 13.r),
                decoration:
                    MealUi.inputDecoration(label: 'Ends', icon: Iconsax.clock),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.r),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title:
              Text('Available for serving', style: TextStyle(fontSize: 13.r)),
          value: active,
          activeThumbColor: AppColors.brandAccent,
          onChanged: onActiveChanged,
        ),
      ],
    );
  }
}

class _EntitlementSheet extends StatelessWidget {
  final String title;
  final TextEditingController limit;
  final bool active;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _EntitlementSheet({
    required this.title,
    required this.limit,
    required this.active,
    required this.onActiveChanged,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: title,
      onCancel: onCancel,
      onSave: onSave,
      children: [
        TextField(
          controller: limit,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 13.r),
          decoration: MealUi.inputDecoration(
              label: 'Servings per day', icon: Iconsax.hashtag),
        ),
        SizedBox(height: 8.r),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text('Included in plan', style: TextStyle(fontSize: 13.r)),
          value: active,
          activeThumbColor: AppColors.brandAccent,
          onChanged: onActiveChanged,
        ),
        Text(
          'This meal access change is applied to active and future subscriptions.',
          style: TextStyle(color: MealUi.muted, fontSize: 10.r),
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _SheetFrame({
    required this.title,
    required this.children,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20.r,
          12.r,
          20.r,
          MediaQuery.viewInsetsOf(context).bottom + 20.r,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 34.r,
                  height: 4.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D0CE),
                    borderRadius: BorderRadius.circular(99.r),
                  ),
                ),
              ),
              SizedBox(height: 16.r),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 17.r,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onCancel,
                    icon: Icon(Iconsax.close_circle, size: 21.r),
                  ),
                ],
              ),
              SizedBox(height: 14.r),
              ...children,
              SizedBox(height: 18.r),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: onCancel, child: const Text('Cancel'))),
                  SizedBox(width: 10.r),
                  Expanded(
                      child: FilledButton(
                          onPressed: onSave, child: const Text('Save'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _label(String value) => Padding(
      padding: EdgeInsets.only(bottom: 6.r),
      child: Text(
        value,
        style: TextStyle(
          color: AppColors.brandDark,
          fontSize: 11.r,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
