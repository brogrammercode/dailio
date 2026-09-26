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
import '../../../core/widgets/app_shell_toast.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../controllers/attendance_repository.dart';
import '../attendance_error.dart';
import '../attendance_ui.dart';
import '../models/attendance_models.dart';
import '../../branch/controllers/members_repository.dart';
import '../../organization/controllers/organization_repository.dart';
import 'attendance_detail_page.dart';
import 'self_attendance_page.dart';

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
        });
        AppShellToastController.show(
          'Last activity · updated ${DateFormat('hh:mm a').format(BranchTime.now(_branchTimezone))}',
          icon: Iconsax.activity,
        );
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
      backgroundColor: AttendanceUi.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AttendanceUi.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Dailio',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          DailioOverflowMenu<String>(
            items: [
              if (_canCreateManual)
                const DailioMenuItem(
                  value: 'manual',
                  icon: Iconsax.add_circle,
                  label: 'Add attendance',
                ),
              const DailioMenuItem(
                value: 'export',
                icon: Iconsax.document_download,
                label: 'Export attendance',
              ),
            ],
            onSelected: (value) {
              if (value == 'manual') _openManualRecordModal();
              if (value == 'export') _exportAttendance();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) => DailioTabStrip<String>(
              tabs: const [
                DailioTabItem(value: 'today', label: 'Today'),
                DailioTabItem(value: 'yesterday', label: 'Yesterday'),
                DailioTabItem(value: 'this_week', label: 'This Week'),
                DailioTabItem(value: 'this_month', label: 'This Month'),
              ],
              selected: _periods[_tabController.index],
              onChanged: (period) =>
                  _tabController.animateTo(_periods.indexOf(period)),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
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
                                    padding: const EdgeInsets.only(
                                      top: 12,
                                      bottom: 92,
                                    ),
                                    itemCount: _sessions.length +
                                        (_isLoadingMore ? 1 : 0),
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 78),
        child: FloatingActionButton(
          heroTag: 'self_attendance_fab',
          tooltip: 'Self attendance',
          backgroundColor: AttendanceUi.accent,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SelfAttendancePage())),
          child: const Icon(Iconsax.finger_scan, size: 27),
        ),
      ),
    );
  }

  Widget _buildRoleFilters() => DailioTabStrip<String?>(
        tabs: [
          const DailioTabItem<String?>(value: null, label: 'All'),
          ..._roles.map(
            (role) => DailioTabItem<String?>(
              value: role['id']?.toString(),
              label: role['name']?.toString() ?? 'Role',
            ),
          ),
        ],
        selected: _selectedRoleId,
        onChanged: _onRoleSelected,
      );

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
    final branchTimezone = session.branchTimezone ?? _branchTimezone;
    final clockInWall =
        BranchTime.toBranch(session.clockInServerTime, branchTimezone);
    final clockOutWall = session.clockOutServerTime == null
        ? null
        : BranchTime.toBranch(session.clockOutServerTime!, branchTimezone);
    final isOpen = clockOutWall == null;
    final isLate = session.derivedStatus == 'LATE';
    final statusColor =
        isOpen || isLate ? AttendanceUi.accent : AttendanceUi.text;
    final statusIcon = isOpen
        ? Iconsax.login
        : isLate
            ? Iconsax.clock
            : Iconsax.verify;
    final eventTime = clockOutWall ?? clockInWall;
    final eventLabel = isOpen ? 'Clocked in at' : 'Clocked out at';
    final roleLabel = session.memberRoleName ?? session.shiftName;
    final statusLabel = isOpen
        ? 'In progress'
        : isLate
            ? 'Late'
            : 'Completed';

    return DailioCompactTile(
      avatar: _buildAttendanceAvatar(session, statusColor, statusIcon),
      title: session.memberName ?? 'You',
      titleBadge: roleLabel,
      subtitle:
          '$eventLabel ${DateFormat('hh:mm a').format(eventTime)} · $statusLabel',
      trailing: DateFormat('dd MMM').format(eventTime),
      subtitleColor: statusColor,
      onTap: () => _openDetail(session),
      onLongPress: _canCorrect ? () => _openCorrectionModal(session) : null,
      menuItems: [
        const DailioMenuItem(
          value: 'details',
          icon: Iconsax.document_text,
          label: 'View details',
        ),
        if (_canCorrect)
          const DailioMenuItem(
            value: 'correct',
            icon: Iconsax.edit_2,
            label: 'Correct record',
          ),
      ],
      onMenuSelected: (value) {
        if (value == 'details') _openDetail(session);
        if (value == 'correct') _openCorrectionModal(session);
      },
    );
  }

  // ignore: unused_element
  Widget _buildAttendanceCardLegacy(AttendanceSessionModel session) {
    final branchTimezone = session.branchTimezone ?? _branchTimezone;
    final clockInWall =
        BranchTime.toBranch(session.clockInServerTime, branchTimezone);
    final clockOutWall = session.clockOutServerTime == null
        ? null
        : BranchTime.toBranch(session.clockOutServerTime!, branchTimezone);
    final isOpen = clockOutWall == null;
    final isLate = session.derivedStatus == 'LATE';
    final statusColor =
        isOpen || isLate ? AttendanceUi.accent : AttendanceUi.text;
    final statusIcon = isOpen
        ? Iconsax.login
        : isLate
            ? Iconsax.clock
            : Iconsax.verify;
    final eventTime = clockOutWall ?? clockInWall;
    final eventLabel = isOpen ? 'Clocked in at' : 'Clocked out at';
    final dateLabel = DateFormat('dd MMM').format(eventTime);
    final statusLabel = isOpen
        ? 'In progress'
        : isLate
            ? 'Late'
            : 'Completed';

    final roleLabel = session.memberRoleName ?? session.shiftName;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openDetail(session),
        onLongPress: _canCorrect ? () => _openCorrectionModal(session) : null,
        child: Ink(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                _buildAttendanceAvatar(session, statusColor, statusIcon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(session.memberName ?? 'You',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                          if (roleLabel != null) ...[
                            const SizedBox(width: 7),
                            Flexible(child: _buildRoleBadge(roleLabel)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '$eventLabel ${DateFormat('hh:mm a').format(eventTime)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          '$dateLabel  •  $statusLabel  •  ${session.durationLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AttendanceUi.muted, fontSize: 10)),
                    ],
                  ),
                ),
                DailioOverflowMenu<String>(
                  items: [
                    const DailioMenuItem(
                      value: 'details',
                      icon: Iconsax.document_text,
                      label: 'View details',
                    ),
                    if (_canCorrect)
                      const DailioMenuItem(
                        value: 'correct',
                        icon: Iconsax.edit_2,
                        label: 'Correct record',
                      ),
                  ],
                  onSelected: (value) {
                    if (value == 'details') _openDetail(session);
                    if (value == 'correct') _openCorrectionModal(session);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AttendanceUi.accentTint,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AttendanceUi.accent,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAttendanceAvatar(
      AttendanceSessionModel session, Color statusColor, IconData statusIcon) {
    final image = session.memberAvatar;
    final initials = session.memberName?.isNotEmpty == true
        ? session.memberName![0].toUpperCase()
        : '?';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AttendanceUi.accentTint,
          backgroundImage:
              image == null || image.isEmpty ? null : NetworkImage(image),
          child: image == null || image.isEmpty
              ? Text(initials,
                  style: const TextStyle(
                      color: AttendanceUi.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold))
              : null,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(statusIcon, size: 9, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _openDetail(AttendanceSessionModel session) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AttendanceDetailPage(sessionId: session.id)));
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
              backgroundColor: AttendanceUi.accent,
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
