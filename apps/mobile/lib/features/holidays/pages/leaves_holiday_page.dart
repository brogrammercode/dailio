import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/branch_filter_tabs.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/holiday_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LeavesHolidayPage extends StatefulWidget {
  const LeavesHolidayPage({super.key});

  @override
  State<LeavesHolidayPage> createState() => _LeavesHolidayPageState();
}

class _LeavesHolidayPageState extends State<LeavesHolidayPage> {
  final _dateFormat = DateFormat('d MMM yyyy');
  String? _branchId;
  int _tab = 1;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _holidays = const [];

  bool get _canManage =>
      context.read<PreferencesStorage>().hasPermission('HOLIDAY_MANAGE');

  @override
  void initState() {
    super.initState();
    _branchId = context.read<PreferencesStorage>().activeBranchId;
    if (_branchId != null) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load({List<Map<String, dynamic>>? fresh}) async {
    final branchId = _branchId;
    if (branchId == null) return;
    if (fresh == null && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final holidays = await context.read<HolidayRepository>().listHolidays(
        branchId,
        onFresh: (value) {
          if (mounted) setState(() => _holidays = value);
        },
      );
      if (mounted) {
        setState(() {
          _holidays = holidays;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> holiday) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete holiday?',
      message: 'This holiday will be removed from this branch calendar.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Iconsax.trash,
    );
    if (!confirmed || !mounted || _branchId == null) return;
    try {
      await context.read<HolidayRepository>().deleteHoliday(
            _branchId!,
            holiday['id'].toString(),
          );
      await _load();
    } catch (error) {
      if (mounted) _message('Could not delete holiday: $error', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : null,
    ));
  }

  String _legacyDateRange(Map<String, dynamic> holiday) {
    final start = DateTime.tryParse(holiday['date']?.toString() ?? '');
    final end = DateTime.tryParse(holiday['end_date']?.toString() ?? '');
    if (start == null) return 'Date not available';
    final first = _dateFormat.format(start.toLocal());
    if (end == null ||
        end.year == start.year &&
            end.month == start.month &&
            end.day == start.day) {
      return first;
    }
    return '$first – ${_dateFormat.format(end.toLocal())}';
  }

  String _datesSummary(Map<String, dynamic> holiday) {
    final dates = ((holiday['dates'] as List?) ?? const [])
        .map((value) => DateTime.tryParse(value.toString()))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) {
      final legacy = DateTime.tryParse(holiday['date']?.toString() ?? '');
      if (legacy != null) return _legacyDateRange(holiday);
    }
    final recurringWeekdays =
        ((holiday['recurring_weekdays'] as List?) ?? const [])
            .map((value) => int.tryParse(value.toString()))
            .whereType<int>()
            .toList();
    final parts = <String>[];
    if (dates.isNotEmpty) {
      final labels = dates
          .take(4)
          .map((date) => _dateFormat.format(date.toLocal()))
          .toList();
      parts.add(labels.join(' · '));
      if (dates.length > labels.length) {
        parts.add('+${dates.length - labels.length} more');
      }
    }
    if (recurringWeekdays.isNotEmpty) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      parts.add(
          'Every ${recurringWeekdays.map((day) => names[day - 1]).join(', ')}');
    }
    return parts.isEmpty ? 'No dates configured' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(onBack: () => context.pop()),
      floatingActionButton: _tab == 1 && _canManage
          ? FloatingActionButton(
              backgroundColor: AppColors.brandAccent,
              foregroundColor: Colors.white,
              elevation: 4.r,
              onPressed: () async {
                await context.push(AppRoutes.createHoliday);
                if (mounted) _load();
              },
              child: Icon(Iconsax.add, size: 22.r),
            )
          : null,
      body: Column(
        children: [
          BranchFilterTabs(
            selectedBranchId: _branchId,
            centered: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.r),
            onChanged: (value) {
              if (value == null || value == 'none') return;
              setState(() => _branchId = value);
              _load();
            },
          ),
          DailioTabStrip<int>(
            centered: true,
            tabs: const [
              DailioTabItem(value: 0, label: 'Leaves'),
              DailioTabItem(value: 1, label: 'Holidays'),
            ],
            selected: _tab,
            onChanged: (value) => setState(() => _tab = value),
          ),
          Expanded(child: _tab == 0 ? _emptyLeaves() : _holidayBody()),
        ],
      ),
    );
  }

  Widget _emptyLeaves() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.calendar_remove, size: 34.r, color: Color(0xFFBDBDBD)),
            SizedBox(height: 10.r),
            Text('No leaves',
                style: TextStyle(fontSize: 14.r, fontWeight: FontWeight.w700)),
            SizedBox(height: 4.r),
            Text('Leave requests will appear here.',
                style: TextStyle(fontSize: 11.r, color: Colors.grey)),
          ],
        ),
      );

  Widget _holidayBody() {
    if (_loading) {
      return ShimmerLoader.compactList();
    }
    if (_error != null) {
      return Center(
          child: TextButton.icon(
        onPressed: _load,
        icon: const Icon(Iconsax.refresh),
        label: const Text('Retry'),
      ));
    }
    if (_holidays.isEmpty) {
      return Center(
          child: Text('No holidays configured',
              style: TextStyle(color: Colors.grey, fontSize: 12.r)));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(0, 12.r, 0, 100.r),
      itemCount: _holidays.length,
      separatorBuilder: (_, __) => SizedBox(height: 6.r),
      itemBuilder: (_, index) {
        final holiday = _holidays[index];
        return DailioCompactTile(
          avatar: CircleAvatar(
            radius: 22.r,
            backgroundColor: Color(0xFFFFF3E8),
            child: Icon(Iconsax.calendar_1,
                color: AppColors.brandAccent, size: 20.r),
          ),
          title: holiday['name']?.toString() ?? 'Holiday',
          titleBadge: holiday['is_recurring'] == true ||
                  ((holiday['recurring_weekdays'] as List?)?.isNotEmpty ??
                      false)
              ? 'Recurring'
              : null,
          subtitle: _datesSummary(holiday),
          trailing:
              ((holiday['recurring_weekdays'] as List?)?.isNotEmpty ?? false)
                  ? 'Weekly'
                  : holiday['is_recurring'] == true
                      ? 'Yearly'
                      : 'Holiday',
          menuItems: [
            if (_canManage)
              const DailioMenuItem(
                  value: 'edit', icon: Iconsax.edit_2, label: 'Edit'),
            if (_canManage)
              const DailioMenuItem(
                  value: 'delete',
                  icon: Iconsax.trash,
                  label: 'Delete',
                  destructive: true),
          ],
          onMenuSelected: (value) async {
            if (value == 'delete') await _delete(holiday);
            if (value == 'edit' && mounted) {
              await context.push(
                  '/home/settings/leaves-holidays/${holiday['id']}/edit',
                  extra: holiday);
              if (mounted) _load();
            }
          },
          onTap: _canManage
              ? () async {
                  await context.push(
                      '/home/settings/leaves-holidays/${holiday['id']}/edit',
                      extra: holiday);
                  if (mounted) _load();
                }
              : null,
        );
      },
    );
  }
}

class CreateHolidayPage extends StatefulWidget {
  final String? holidayId;
  final Map<String, dynamic>? initialHoliday;

  const CreateHolidayPage({super.key, this.holidayId, this.initialHoliday});

  @override
  State<CreateHolidayPage> createState() => _CreateHolidayPageState();
}

class _CreateHolidayPageState extends State<CreateHolidayPage> {
  late final TextEditingController _name;
  final List<DateTime> _dates = [];
  final Set<int> _recurringWeekdays = {};
  bool _recurring = false;
  bool _saving = false;

  bool get _editing => widget.holidayId != null;
  String? get _branchId => context.read<PreferencesStorage>().activeBranchId;

  @override
  void initState() {
    super.initState();
    final data = widget.initialHoliday;
    _name = TextEditingController(text: data?['name']?.toString() ?? '');
    final initialDates = ((data?['dates'] as List?) ?? const [])
        .map((value) => DateTime.tryParse(value.toString()))
        .whereType<DateTime>();
    _dates.addAll(
        initialDates.map((date) => DateTime(date.year, date.month, date.day)));
    if (_dates.isEmpty) {
      final start =
          DateTime.tryParse(data?['date']?.toString() ?? '')?.toLocal();
      final end =
          DateTime.tryParse(data?['end_date']?.toString() ?? '')?.toLocal();
      if (start != null) {
        for (var date = DateTime(start.year, start.month, start.day);
            date.isBefore((end ?? start).add(const Duration(days: 1)));
            date = date.add(const Duration(days: 1))) {
          _dates.add(date);
        }
      }
    }
    _recurringWeekdays.addAll(
        ((data?['recurring_weekdays'] as List?) ?? const [])
            .map((value) => int.tryParse(value.toString()))
            .whereType<int>()
            .where((day) => day >= 1 && day <= 7));
    _recurring = data?['is_recurring'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _dateValue(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  Future<void> _pickDate() async {
    final initial = _dates.isEmpty ? DateTime.now() : _dates.last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
              colorScheme:
                  const ColorScheme.light(primary: AppColors.brandAccent)),
          child: child!),
    );
    if (picked == null) return;
    setState(() {
      final date = DateTime(picked.year, picked.month, picked.day);
      if (!_dates.any((item) => item == date)) _dates.add(date);
      _dates.sort();
    });
  }

  Future<void> _chooseTemplate() async {
    final template = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HolidayTemplateSheet(),
    );
    if (template == null) return;
    final start = DateTime.parse(template['date']!);
    final end = template['end_date'] == null
        ? start
        : DateTime.parse(template['end_date']!);
    setState(() {
      _name.text = template['name']!;
      _dates
        ..clear()
        ..addAll([
          for (var date = start;
              !date.isAfter(end);
              date = date.add(const Duration(days: 1)))
            date,
        ]);
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        (_dates.isEmpty && _recurringWeekdays.isEmpty) ||
        _branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a name and at least one date or weekday.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'dates': _dates.map(_dateValue).toList(),
        'recurring_weekdays': _recurringWeekdays.toList()..sort(),
        'is_recurring': _recurring,
      };
      final repo = context.read<HolidayRepository>();
      if (_editing) {
        await repo.updateHoliday(_branchId!, widget.holidayId!, data);
      } else {
        await repo.createHoliday(_branchId!, data);
      }
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save holiday: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(onBack: () => context.pop()),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.r, 18.r, 20.r, 32.r),
          children: [
            Text(_editing ? 'Edit holiday' : 'New holiday',
                style: TextStyle(fontSize: 20.r, fontWeight: FontWeight.w800)),
            SizedBox(height: 4.r),
            Text('Keep the branch calendar clear and accurate.',
                style: TextStyle(fontSize: 12.r, color: Colors.grey)),
            SizedBox(height: 24.r),
            _label('Holiday name'),
            _textField(_name, 'e.g. Republic Day', Iconsax.text),
            SizedBox(height: 16.r),
            _label('Dates'),
            _datePickerField(),
            if (_dates.isNotEmpty) ...[
              SizedBox(height: 8.r),
              Wrap(
                spacing: 6.r,
                runSpacing: 6.r,
                children: _dates
                    .map((date) => InputChip(
                          label: Text(DateFormat('d MMM yyyy').format(date)),
                          labelStyle: TextStyle(fontSize: 11.r),
                          onDeleted: () => setState(() => _dates.remove(date)),
                          deleteIcon: Icon(Iconsax.close_circle, size: 15.r),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            SizedBox(height: 16.r),
            _label('Weekly recurring days (optional)'),
            _weekdayPicker(),
            SizedBox(height: 12.r),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _recurring,
              onChanged: (value) => setState(() => _recurring = value),
              activeThumbColor: AppColors.brandAccent,
              title: Text('Repeats every year',
                  style:
                      TextStyle(fontSize: 13.r, fontWeight: FontWeight.w600)),
              subtitle: Text('Repeat the selected dates every year.',
                  style: TextStyle(fontSize: 11.r, color: Colors.grey)),
            ),
            SizedBox(height: 12.r),
            OutlinedButton.icon(
                onPressed: _chooseTemplate,
                icon: Icon(Iconsax.magicpen, size: 17.r),
                label: const Text('Pick from template')),
            SizedBox(height: 22.r),
            SizedBox(
                height: 46.r,
                child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r))),
                    child: _saving
                        ? SizedBox(
                            width: 18.r,
                            height: 18.r,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.r, color: Colors.white))
                        : Text(_editing ? 'Save changes' : 'Create holiday'))),
          ],
        ),
      ),
    );
  }

  Widget _label(String value) => Padding(
      padding: EdgeInsets.only(bottom: 8.r),
      child: Text(value,
          style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w500)));
  Widget _textField(
          TextEditingController controller, String hint, IconData icon) =>
      TextField(
          controller: controller,
          style: TextStyle(fontSize: 13.r),
          decoration: _decoration(hint, icon));
  Widget _datePickerField() => InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(10.r),
      child: InputDecorator(
          decoration: _decoration('Add one or more dates', Iconsax.calendar_1)
              .copyWith(suffixIcon: Icon(Iconsax.arrow_down_1, size: 17.r)),
          child: Text('Add one or more dates',
              style: TextStyle(fontSize: 13.r, color: Colors.grey))));
  Widget _weekdayPicker() => Wrap(
        spacing: 6.r,
        runSpacing: 6.r,
        children: List.generate(7, (index) {
          final day = index + 1;
          const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final selected = _recurringWeekdays.contains(day);
          return FilterChip(
            label: Text(labels[index]),
            selected: selected,
            onSelected: (value) => setState(() {
              if (value) {
                _recurringWeekdays.add(day);
              } else {
                _recurringWeekdays.remove(day);
              }
            }),
            selectedColor: const Color(0xFFFFE2CC),
            checkmarkColor: AppColors.brandAccent,
            labelStyle: TextStyle(
              fontSize: 11.r,
              color: selected ? AppColors.brandDark : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            visualDensity: VisualDensity.compact,
          );
        }),
      );
  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.r, color: Colors.grey),
      prefixIcon: Icon(icon, size: 16.r, color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(vertical: 13.r, horizontal: 14.r),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.orange.shade400, width: 1.5.r)));
}

class _HolidayTemplateSheet extends StatelessWidget {
  const _HolidayTemplateSheet();

  static const templates = <Map<String, String>>[
    {'name': "New Year's Day", 'date': '2026-01-01'},
    {'name': 'Makar Sankranti', 'date': '2026-01-14'},
    {'name': 'Vasant Panchami', 'date': '2026-01-23'},
    {'name': 'Karpoori Thakur Jayanti', 'date': '2026-01-24'},
    {'name': 'Republic Day', 'date': '2026-01-26'},
    {'name': 'Sant Ravidas Jayanti', 'date': '2026-02-01'},
    {'name': 'Shab-e-Barat', 'date': '2026-02-04'},
    {'name': 'Mahashivratri', 'date': '2026-02-15'},
    {'name': 'Holika Dahan', 'date': '2026-03-02'},
    {'name': 'Holi', 'date': '2026-03-03', 'end_date': '2026-03-04'},
    {'name': 'Last Friday of Ramzan', 'date': '2026-03-13'},
    {'name': 'Eid-ul-Fitr', 'date': '2026-03-21', 'end_date': '2026-03-22'},
    {'name': 'Bihar Day', 'date': '2026-03-22'},
    {'name': 'Samrat Ashok Ashtami', 'date': '2026-03-26'},
    {'name': 'Ram Navami', 'date': '2026-03-27'},
    {'name': 'Mahavir Jayanti', 'date': '2026-03-31'},
    {'name': 'Good Friday', 'date': '2026-04-03'},
    {'name': 'Dr. B. R. Ambedkar Jayanti', 'date': '2026-04-14'},
    {'name': 'Veer Kunwar Singh Jayanti', 'date': '2026-04-23'},
    {'name': 'Janaki Navami', 'date': '2026-04-25'},
    {'name': 'May Day / Labour Day', 'date': '2026-05-01'},
    {'name': 'Buddha Purnima', 'date': '2026-05-01'},
    {
      'name': 'Eid-ul-Zuha / Bakrid',
      'date': '2026-05-28',
      'end_date': '2026-05-29'
    },
    {'name': 'Anugrah Narayan Singh Jayanti', 'date': '2026-06-18'},
    {'name': 'Muharram', 'date': '2026-06-26', 'end_date': '2026-06-27'},
    {'name': 'Kabir Jayanti', 'date': '2026-06-29'},
    {'name': 'Chehallum', 'date': '2026-08-04'},
    {'name': 'Independence Day', 'date': '2026-08-15'},
    {'name': 'Last Shravan Monday', 'date': '2026-08-24'},
    {
      'name': "Milad-un-Nabi / Prophet Muhammad's Birthday",
      'date': '2026-08-26'
    },
    {'name': 'Raksha Bandhan', 'date': '2026-08-28'},
    {'name': 'Shri Krishna Janmashtami', 'date': '2026-09-04'},
    {'name': 'Hartalika Teej', 'date': '2026-09-14'},
    {'name': 'Vishwakarma Puja', 'date': '2026-09-17'},
    {'name': 'Anant Chaturdashi', 'date': '2026-09-25'},
    {'name': 'Mahatma Gandhi Jayanti', 'date': '2026-10-02'},
    {'name': 'Jivitputrika Vrat', 'date': '2026-10-04'},
    {'name': 'Durga Puja Kalash Sthapana', 'date': '2026-10-11'},
    {'name': 'Jayaprakash Narayan Jayanti', 'date': '2026-10-11'},
    {'name': 'Durga Puja', 'date': '2026-10-17', 'end_date': '2026-10-20'},
    {'name': 'Durga Puja Ekadashi', 'date': '2026-10-21'},
    {'name': 'Shri Krishna Singh Jayanti', 'date': '2026-10-21'},
    {'name': 'Diwali', 'date': '2026-11-08'},
    {'name': 'Chitragupt Puja / Bhai Dooj', 'date': '2026-11-10'},
    {'name': 'Chhath Puja – Kharna', 'date': '2026-11-14'},
    {'name': 'Chhath Puja', 'date': '2026-11-15', 'end_date': '2026-11-16'},
    {'name': 'Dr. Rajendra Prasad Jayanti', 'date': '2026-12-03'},
    {'name': 'Christmas Eve', 'date': '2026-12-24'},
    {'name': 'Christmas Day', 'date': '2026-12-25'},
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: EdgeInsets.fromLTRB(16.r, 4.r, 16.r, 16.r),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Holiday templates',
                    style:
                        TextStyle(fontSize: 16.r, fontWeight: FontWeight.w800)),
                SizedBox(height: 8.r),
                Flexible(
                    child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: templates.length,
                        separatorBuilder: (_, __) => Divider(height: 1.r),
                        itemBuilder: (_, index) {
                          final item = templates[index];
                          return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: Icon(Iconsax.calendar_1,
                                  size: 18.r, color: AppColors.brandAccent),
                              title: Text(item['name']!,
                                  style: TextStyle(
                                      fontSize: 13.r,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(item['date']!,
                                  style: TextStyle(
                                      fontSize: 11.r, color: Colors.grey)),
                              onTap: () => Navigator.pop(context, item));
                        }))
              ])));
}
