// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/attendance_repository.dart';
import '../models/attendance_models.dart';
import '../../organization/controllers/organization_repository.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  late final AttendanceRepository _repository;
  late final OrganizationRepository _orgRepository;
  late final String _locationId;
  late final String _orgId;

  late TabController _tabController;
  final List<String> _periods = [
    'today',
    'yesterday',
    'this_week',
    'this_month'
  ];

  List<Map<String, dynamic>> _roles = [];
  String? _selectedRoleId;

  List<AttendanceSessionModel> _sessions = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AttendanceRepository>();
    _orgRepository = context.read<OrganizationRepository>();
    final prefs = context.read<PreferencesStorage>();
    _locationId = prefs.activeBranchId!;
    _orgId = prefs.activeOrganizationId!;

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);

    _loadRoles().then((_) => _loadSessions(_periods[_tabController.index]));
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      _loadSessions(_periods[_tabController.index]);
    }
  }

  Future<void> _loadRoles() async {
    try {
      final roles =
          await _orgRepository.getRoles(_orgId, branchId: _locationId);
      if (mounted) {
        setState(() {
          _roles = roles;
        });
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _loadSessions(String period) async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getSessions(
        _locationId,
        period,
        roleId: _selectedRoleId,
      );
      if (mounted) {
        setState(() {
          _sessions = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onRoleSelected(String? roleId) {
    setState(() {
      _selectedRoleId = roleId;
    });
    _loadSessions(_periods[_tabController.index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Attendance',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
              icon: const Icon(Iconsax.document_download), onPressed: () {}),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: const Color(0xFF8D490B),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8D490B),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Yesterday'),
            Tab(text: 'This Week'),
            Tab(text: 'This Month'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildCyclePerformance(),
          _buildRoleFilters(),
          Expanded(
            child: _isLoading && _sessions.isEmpty
                ? ShimmerLoader.list()
                : _error != null && _sessions.isEmpty
                    ? Center(child: Text('Error: $_error'))
                    : _sessions.isEmpty
                        ? _buildEmptyState()
                        : TabBarView(
                            controller: _tabController,
                            children: _periods.map((period) {
                              return RefreshIndicator(
                                onRefresh: () => _loadSessions(period),
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _sessions.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return _buildAttendanceCard(
                                        _sessions[index]);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildRoleChip('All Roles', null),
            const SizedBox(width: 8),
            ..._roles.map((r) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildRoleChip(r['name'], r['id']),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String label, String? roleId) {
    final isSelected = _selectedRoleId == roleId;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onRoleSelected(roleId),
      selectedColor: const Color(0xFF8D490B).withValues(alpha: 0.1),
      labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF8D490B) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color:
                  isSelected ? const Color(0xFF8D490B) : Colors.grey.shade300)),
      backgroundColor: Colors.white,
      showCheckmark: false,
    );
  }

  Widget _buildCyclePerformance() {
    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;

    for (var s in _sessions) {
      if (s.derivedStatus == 'PRESENT') {
        presentCount++;
      } else if (s.derivedStatus == 'LATE')
        lateCount++;
      else if (s.derivedStatus == 'ABSENT') absentCount++;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Iconsax.activity, size: 16, color: Color(0xFF8D490B)),
                  SizedBox(width: 8),
                  Text('Cycle Performance',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('Current Period',
                    style: const TextStyle(
                        color: Color(0xFF8D490B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Present', presentCount.toString(),
                    Colors.green.shade600, Iconsax.tick_circle),
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              Expanded(
                child: _buildStatItem('Late', lateCount.toString(),
                    Colors.orange.shade600, Iconsax.clock),
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              Expanded(
                child: _buildStatItem('Absent', absentCount.toString(),
                    Colors.red.shade600, Iconsax.close_circle),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _openCorrectionModal(AttendanceSessionModel session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CorrectionModal(
        session: session,
        repository: _repository,
        locationId: _locationId,
        onSuccess: () => _loadSessions(_periods[_tabController.index]),
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceSessionModel session) {
    final bool isCompleted = session.state == 'CLOSED';
    final bool isLate = session.derivedStatus == 'LATE';
    final Color barColor = isLate
        ? Colors.orange
        : (isCompleted ? Colors.green.shade600 : Colors.green.shade300);
    final Color bgColor = isLate ? Colors.orange.shade50 : Colors.green.shade50;

    final clockInTime = DateFormat('hh:mm a').format(session.clockInServerTime);
    final clockOutTime = session.clockOutServerTime != null
        ? DateFormat('hh:mm a').format(session.clockOutServerTime!)
        : '--:--';

    final now = DateTime.now();
    final isToday = session.clockInServerTime.day == now.day &&
        session.clockInServerTime.month == now.month &&
        session.clockInServerTime.year == now.year;
    final dateStr = isToday
        ? 'Today \u2022 '
        : DateFormat("EEEE \u2022 dd MMM yyyy")
            .format(session.clockInServerTime);

    return InkWell(
        onTap: () => _openCorrectionModal(session),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                    width: 4,
                    decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(16)))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (session.memberAvatar != null &&
                                session.memberAvatar!.isNotEmpty)
                              CircleAvatar(
                                radius: 12,
                                backgroundImage:
                                    NetworkImage(session.memberAvatar!),
                              )
                            else
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.blue.shade50,
                                child: Text(
                                  session.memberName?.isNotEmpty == true
                                      ? session.memberName![0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              session.memberName ?? 'Unknown Member',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(dateStr,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                const SizedBox(width: 6),
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: barColor,
                                        shape: BoxShape.circle)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Icon(isLate ? Iconsax.clock : Iconsax.verify,
                                      size: 12, color: barColor),
                                  const SizedBox(width: 4),
                                  Text(
                                      '${session.derivedStatus ?? session.state} \u2022 ${isCompleted ? 'Completed' : 'In Progress'}',
                                      style: TextStyle(
                                          color: barColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Regular Shift',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTimeCol('CLOCK IN', clockInTime),
                              _buildTimeCol('CLOCK OUT', clockOutTime),
                              _buildTimeCol('LOGGED', session.durationLabel,
                                  valueColor: const Color(0xFF8D490B)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPill(Iconsax.camera, 'Selfie Verified',
                                Colors.blue.shade700, Colors.blue.shade50),
                            _buildPill(Iconsax.location, 'HQ',
                                Colors.blue.shade700, Colors.blue.shade50),
                            _buildPill(Iconsax.shield_tick, 'Zero Anomaly',
                                Colors.blue.shade700, Colors.blue.shade50),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey.shade200, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'Shift Activity Log (${isCompleted ? '2' : '1'} events)',
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            Icon(Iconsax.arrow_down_1,
                                size: 14, color: Colors.grey.shade500),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildLogEvent(
                            Colors.green.shade600, clockInTime, 'Clocked in'),
                        if (isCompleted)
                          _buildLogEvent(Colors.grey.shade600, clockOutTime,
                              'Clocked out'),
                        if (!isCompleted)
                          _buildLogEvent(const Color(0xFF8D490B), 'Active',
                              'Duty in progress'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildTimeCol(String label, String time,
      {Color valueColor = Colors.black}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(time,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildPill(IconData icon, String text, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLogEvent(Color dotColor, String time, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(time,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: time == 'Active' ? dotColor : Colors.black87)),
          const SizedBox(width: 8),
          Text(desc,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () => _loadSessions(_periods[_tabController.index]),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.document_text_1,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No attendance records found',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CorrectionModal extends StatefulWidget {
  final AttendanceSessionModel session;
  final AttendanceRepository repository;
  final String locationId;
  final VoidCallback onSuccess;

  const _CorrectionModal({
    required this.session,
    required this.repository,
    required this.locationId,
    required this.onSuccess,
  });

  @override
  State<_CorrectionModal> createState() => _CorrectionModalState();
}

class _CorrectionModalState extends State<_CorrectionModal> {
  final _reasonCtrl = TextEditingController();
  bool _isLoading = false;

  TimeOfDay? _clockInTime;
  TimeOfDay? _clockOutTime;
  String _status = 'PRESENT';

  @override
  void initState() {
    super.initState();
    _clockInTime = TimeOfDay.fromDateTime(widget.session.clockInServerTime);
    if (widget.session.clockOutServerTime != null) {
      _clockOutTime =
          TimeOfDay.fromDateTime(widget.session.clockOutServerTime!);
    }
    _status = widget.session.derivedStatus ?? 'PRESENT';
  }

  Future<void> _pickTime(bool isClockIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isClockIn ? _clockInTime : _clockOutTime) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isClockIn) {
          _clockInTime = picked;
        } else {
          _clockOutTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reason is required')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final now = widget.session.clockInServerTime;
      final inTime = _clockInTime != null
          ? DateTime(now.year, now.month, now.day, _clockInTime!.hour,
                  _clockInTime!.minute)
              .toUtc()
              .toIso8601String()
          : null;
      final outTime = _clockOutTime != null
          ? DateTime(now.year, now.month, now.day, _clockOutTime!.hour,
                  _clockOutTime!.minute)
              .toUtc()
              .toIso8601String()
          : null;

      await widget.repository
          .correctSession(widget.locationId, widget.session.id, {
        'correction_reason': _reasonCtrl.text.trim(),
        'derived_status': _status,
        if (inTime != null) 'clock_in_at': inTime,
        if (outTime != null) 'clock_out_at': outTime,
      });

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24, bottom: mq.viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Correct Attendance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(true),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Clock In',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_clockInTime?.format(context) ?? '--:--'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Clock Out',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_clockOutTime?.format(context) ?? '--:--'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: 'Status',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              'PRESENT',
              'LATE',
              'LEFT_EARLY',
              'HALF_DAY',
              'ABSENT',
              'ON_LEAVE',
              'HOLIDAY'
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _status = val);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Correction Reason*',
              hintText: 'e.g. Forgot to clock out, network issue',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save Changes',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
