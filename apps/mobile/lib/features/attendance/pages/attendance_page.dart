// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/services.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/utils/branch_time.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/attendance_repository.dart';
import '../attendance_error.dart';
import '../models/attendance_models.dart';
import '../../branch/controllers/members_repository.dart';
import '../../organization/controllers/organization_repository.dart';
import 'attendance_detail_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  late final AttendanceRepository _repository;
  late final MembersRepository _membersRepository;
  late final OrganizationRepository _orgRepository;
  late final String _locationId;
  late final String _orgId;
  late final String _branchTimezone;

  late TabController _tabController;
  final List<String> _periods = [
    'today',
    'yesterday',
    'this_week',
    'this_month'
  ];

  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _members = [];
  String? _selectedRoleId;
  late final bool _canCreateManual;
  late final bool _canCorrect;

  List<AttendanceSessionModel> _sessions = [];
  bool _isLoading = false;
  bool _isExporting = false;
  String? _error;
  DateTime? _lastSyncedAt;
  Timer? _refreshTimer;
  String? _nextCursor;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AttendanceRepository>();
    _membersRepository = context.read<MembersRepository>();
    _orgRepository = context.read<OrganizationRepository>();
    final prefs = context.read<PreferencesStorage>();
    _locationId = prefs.activeBranchId!;
    _orgId = prefs.activeOrganizationId!;
    _branchTimezone = prefs.activeBranchTimezone ?? 'Asia/Kolkata';
    _canCreateManual = prefs.hasPermission('ATTENDANCE_CREATE_ALL');
    _canCorrect = prefs.hasPermission('ATTENDANCE_UPDATE');

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _loadSessions(_periods[_tabController.index]);
    });

    _loadRoles();
    _loadMembers();
    _loadSessions(_periods[_tabController.index]);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _refreshTimer?.cancel();
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

  Future<void> _loadMembers() async {
    if (!_canCreateManual) return;
    try {
      final response = await _membersRepository.listMembers(
        _locationId,
        status: 'ACTIVE',
        page: 1,
        limit: 100,
      );
      final members = ((response['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((member) => Map<String, dynamic>.from(member))
          .toList();
      if (mounted) setState(() => _members = members);
    } catch (_) {
      // The manual-entry action remains hidden if the member directory cannot
      // be loaded; the API remains the final authorization boundary.
    }
  }

  Future<void> _loadSessions(String period) async {
    setState(() => _isLoading = true);
    _nextCursor = null;
    try {
      final page = await _repository.getSessionPage(
        _locationId,
        period,
        roleId: _selectedRoleId,
      );
      if (mounted) {
        setState(() {
          _sessions = page.sessions;
          _nextCursor = page.nextCursor;
          _error = null;
          _lastSyncedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = attendanceErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreSessions() async {
    final cursor = _nextCursor;
    if (_isLoadingMore || cursor == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _repository.getSessionPage(
        _locationId,
        _periods[_tabController.index],
        roleId: _selectedRoleId,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _sessions = [..._sessions, ...page.sessions];
        _nextCursor = page.nextCursor;
        _lastSyncedAt = DateTime.now();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(attendanceErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onRoleSelected(String? roleId) {
    setState(() {
      _selectedRoleId = roleId;
    });
    _loadSessions(_periods[_tabController.index]);
  }

  Future<void> _exportAttendance() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final csv = await _repository.exportSessions(
        _locationId,
        _periods[_tabController.index],
        roleId: _selectedRoleId,
      );
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Attendance CSV copied. You can paste it into Sheets or Excel.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(attendanceErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _openManualRecordModal() {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No active members are available for a manual record.'),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualRecordModal(
        members: _members,
        repository: _repository,
        locationId: _locationId,
        branchTimezone: _branchTimezone,
        onSuccess: () => _loadSessions(_periods[_tabController.index]),
      ),
    );
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
          if (_canCreateManual)
            IconButton(
              tooltip: 'Add manual attendance record',
              icon: const Icon(Iconsax.add_circle),
              onPressed: _openManualRecordModal,
            ),
          IconButton(
              tooltip: 'Export attendance',
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Iconsax.document_download),
              onPressed: _isExporting ? null : _exportAttendance),
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
          if (_lastSyncedAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Text(
                    'Live activity \u2022 updated ${DateFormat('hh:mm:ss a').format(_lastSyncedAt!)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification.metrics.pixels >=
                                        notification.metrics.maxScrollExtent -
                                            300) {
                                      _loadMoreSessions();
                                    }
                                    return false;
                                  },
                                  child: ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _sessions.length +
                                        (_isLoadingMore ? 1 : 0),
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      if (index >= _sessions.length) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }
                                      return _buildAttendanceCard(
                                          _sessions[index]);
                                    },
                                  ),
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

    final branchTimezone = session.branchTimezone ?? _branchTimezone;
    final clockInWall = BranchTime.toBranch(
      session.clockInServerTime,
      branchTimezone,
    );
    final clockOutWall = session.clockOutServerTime == null
        ? null
        : BranchTime.toBranch(session.clockOutServerTime!, branchTimezone);
    final clockInTime = DateFormat('hh:mm a').format(clockInWall);
    final clockOutTime = clockOutWall != null
        ? DateFormat('hh:mm a').format(clockOutWall)
        : '--:--';
    final loggedTime = isCompleted
        ? session.durationLabel
        : _liveDurationLabel(session.clockInServerTime);

    final now = BranchTime.now(branchTimezone);
    final isToday = clockInWall.day == now.day &&
        clockInWall.month == now.month &&
        clockInWall.year == now.year;
    final dateStr = isToday
        ? 'Today \u2022 '
        : DateFormat("EEEE \u2022 dd MMM yyyy").format(clockInWall);

    return InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AttendanceDetailPage(sessionId: session.id))),
        onLongPress: _canCorrect ? () => _openCorrectionModal(session) : null,
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
                        Text(session.shiftName ?? 'No shift assigned',
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
                              _buildTimeCol('LOGGED', loggedTime,
                                  valueColor: const Color(0xFF8D490B)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (session.hasSelfieEvidence)
                              _buildPill(Iconsax.camera, 'Selfie evidence',
                                  Colors.blue.shade700, Colors.blue.shade50),
                            if (session.hasLocationEvidence)
                              _buildPill(Iconsax.location, 'Location evidence',
                                  Colors.blue.shade700, Colors.blue.shade50),
                            if (session.evidence.isEmpty)
                              _buildPill(
                                  Iconsax.info_circle,
                                  'No evidence recorded',
                                  Colors.grey.shade700,
                                  Colors.grey.shade100),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey.shade200, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'Server timeline (${session.timeline.length} events)',
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            Icon(Iconsax.arrow_down_1,
                                size: 14, color: Colors.grey.shade500),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...session.timeline.map((event) => _buildLogEvent(
                              _timelineColor(event.type),
                              _time(event.at, branchTimezone),
                              _timelineLabel(event.type),
                            )),
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

  String _liveDurationLabel(DateTime clockIn) {
    final minutes = DateTime.now()
        .difference(clockIn)
        .inMinutes
        .clamp(0, 60 * 24 * 30)
        .toInt();
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return hours > 0 ? '${hours}h ${remainingMinutes}m' : '${minutes}m';
  }

  Color _timelineColor(String type) {
    if (type.contains('CLOCK_IN')) return Colors.green.shade600;
    if (type.contains('CLOCK_OUT')) return Colors.grey.shade600;
    if (type.contains('CORRECTION')) return Colors.orange.shade700;
    if (type.contains('SELFIE') || type.contains('LOCATION')) {
      return Colors.blue.shade700;
    }
    return Colors.indigo.shade600;
  }

  String _timelineLabel(String type) => type
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  String _time(DateTime value, [String? timezone]) => DateFormat('hh:mm a')
      .format(BranchTime.toBranch(value, timezone ?? _branchTimezone));

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
    final branchTimezone = widget.session.branchTimezone ?? 'Asia/Kolkata';
    final clockInWall =
        BranchTime.toBranch(widget.session.clockInServerTime, branchTimezone);
    _clockInTime = TimeOfDay.fromDateTime(clockInWall);
    if (widget.session.clockOutServerTime != null) {
      _clockOutTime = TimeOfDay.fromDateTime(BranchTime.toBranch(
          widget.session.clockOutServerTime!, branchTimezone));
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
      final branchTimezone = widget.session.branchTimezone ?? 'Asia/Kolkata';
      final clockInWall = BranchTime.toBranch(now, branchTimezone);
      final clockOutWall = widget.session.clockOutServerTime == null
          ? clockInWall
          : BranchTime.toBranch(
              widget.session.clockOutServerTime!, branchTimezone);
      final inTime = _clockInTime != null
          ? BranchTime.wallTimeToUtc(
                  DateTime(clockInWall.year, clockInWall.month, clockInWall.day,
                      _clockInTime!.hour, _clockInTime!.minute),
                  branchTimezone)
              .toIso8601String()
          : null;
      final outTime = _clockOutTime != null
          ? BranchTime.wallTimeToUtc(
                  DateTime(
                      clockOutWall.year,
                      clockOutWall.month,
                      clockOutWall.day,
                      _clockOutTime!.hour,
                      _clockOutTime!.minute),
                  branchTimezone)
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
            .showSnackBar(SnackBar(content: Text(attendanceErrorMessage(e))));
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

class _ManualRecordModal extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final AttendanceRepository repository;
  final String locationId;
  final String branchTimezone;
  final VoidCallback onSuccess;

  const _ManualRecordModal({
    required this.members,
    required this.repository,
    required this.locationId,
    required this.branchTimezone,
    required this.onSuccess,
  });

  @override
  State<_ManualRecordModal> createState() => _ManualRecordModalState();
}

class _ManualRecordModalState extends State<_ManualRecordModal> {
  final _reasonCtrl = TextEditingController();
  late String _memberId;
  late DateTime _clockIn;
  DateTime? _clockOut;
  bool _recordClockOut = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _memberId = widget.members.first['id'].toString();
    final now = BranchTime.now(widget.branchTimezone);
    _clockIn = BranchTime.wallFields(now.subtract(const Duration(hours: 1)));
    _clockOut = BranchTime.wallFields(now);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _memberName(Map<String, dynamic> member) {
    final user = member['user'];
    if (user is Map && user['name'] != null) return user['name'].toString();
    return member['name']?.toString() ?? 'Member';
  }

  Future<void> _pickDateTime({required bool clockOut}) async {
    final current = clockOut ? (_clockOut ?? _clockIn) : _clockIn;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (clockOut) {
        _clockOut = value;
      } else {
        _clockIn = value;
      }
    });
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a reason of at least 5 characters.'),
      ));
      return;
    }
    if (_recordClockOut && _clockOut != null && _clockOut!.isBefore(_clockIn)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Clock-out must be after clock-in.'),
      ));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final clockInUtc =
          BranchTime.wallTimeToUtc(_clockIn, widget.branchTimezone);
      final clockOutUtc = _recordClockOut && _clockOut != null
          ? BranchTime.wallTimeToUtc(_clockOut!, widget.branchTimezone)
          : null;
      await widget.repository.createManualSession(
        widget.locationId,
        memberId: _memberId,
        clockInAt: clockInUtc,
        clockOutAt: clockOutUtc,
        reason: reason,
      );
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(attendanceErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, inset + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add manual attendance',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const Text(
              'This creates an ADMIN/MANUAL record and requires an audit reason. The server still enforces policy and one open session per member.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text('Times use branch timezone: ${widget.branchTimezone}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _memberId,
              decoration: InputDecoration(
                labelText: 'Member',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: widget.members
                  .map((member) => DropdownMenuItem<String>(
                        value: member['id'].toString(),
                        child: Text(_memberName(member)),
                      ))
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value != null) setState(() => _memberId = value);
                    },
            ),
            const SizedBox(height: 12),
            _dateTimeField(
                'Clock in', _clockIn, () => _pickDateTime(clockOut: false)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Record clock-out now'),
              value: _recordClockOut,
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _recordClockOut = value),
            ),
            if (_recordClockOut)
              _dateTimeField(
                  'Clock out', _clockOut, () => _pickDateTime(clockOut: true)),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason*',
                hintText: 'e.g. Member forgot to punch at the gate',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create manual record'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimeField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(value == null
            ? 'Select date and time'
            : DateFormat('dd MMM yyyy, hh:mm a').format(value)),
      ),
    );
  }
}
