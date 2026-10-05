// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/storage/json_cache_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/branch_time.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/app_shell_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_nav_badges.dart';
import '../controllers/attendance_repository.dart';
import '../attendance_error.dart';
import '../attendance_ui.dart';
import '../models/attendance_models.dart';
import '../../branch/controllers/members_repository.dart';
import '../../organization/controllers/organization_repository.dart';
import '../../meals/controllers/meals_repository.dart';
import '../../meals/widgets/meal_ui.dart';
import 'attendance_detail_page.dart';
import 'self_attendance_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  late final MealsRepository _mealsRepository;
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
  late final bool _canDelete;
  late final bool _canReadMeals;

  List<AttendanceSessionModel> _sessions = [];
  bool _isLoading = false;
  bool _isExporting = false;
  String? _error;
  Timer? _refreshTimer;
  String? _nextCursor;
  bool _isLoadingMore = false;
  String _section = 'attendance';
  bool _isMealLoading = false;
  String? _mealError;
  List<Map<String, dynamic>> _mealSlots = [];
  List<Map<String, dynamic>> _mealMembers = [];
  List<Map<String, dynamic>> _mealServings = [];

  @override
  void initState() {
    super.initState();
    _repository = context.read<AttendanceRepository>();
    _membersRepository = context.read<MembersRepository>();
    _orgRepository = context.read<OrganizationRepository>();
    _mealsRepository = MealsRepository(
      context.read<ApiClient>(),
      cache: context.read<JsonCacheStore?>(),
    );
    final prefs = context.read<PreferencesStorage>();
    _locationId = prefs.activeBranchId!;
    _orgId = prefs.activeOrganizationId!;
    _branchTimezone = prefs.activeBranchTimezone ?? 'Asia/Kolkata';
    _canCreateManual = prefs.hasPermission('ATTENDANCE_CREATE_ALL');
    _canCorrect = prefs.hasPermission('ATTENDANCE_UPDATE');
    _canDelete = prefs.hasPermission('ATTENDANCE_VOID') ||
        prefs.hasPermission('ATTENDANCE_DELETE');
    _canReadMeals = prefs.activeOrganizationType == 'FOOD_SERVICE' &&
        (prefs.hasPermission('MEAL_READ_BRANCH') ||
            prefs.hasPermission('MEAL_SERVE') ||
            prefs.hasPermission('MEAL_MANAGE'));

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      if (_section == 'meal') {
        _loadMealAttendance();
      } else {
        _loadSessions(_periods[_tabController.index]);
      }
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
    if (!_tabController.indexIsChanging && _section == 'attendance') {
      _loadSessions(_periods[_tabController.index]);
    }
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _orgRepository.getRoles(
        _orgId,
        branchId: _locationId,
        onFresh: (freshRoles) {
          if (mounted) setState(() => _roles = freshRoles);
        },
      );
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
        onFresh: (freshPage) {
          if (!mounted) return;
          if (period == 'today') {
            DailioNavBadgeController.setCount(
              'attendance',
              freshPage.sessions.length,
            );
          }
          setState(() {
            _sessions = freshPage.sessions;
            _nextCursor = freshPage.nextCursor;
            _error = null;
          });
        },
      );
      if (mounted) {
        if (period == 'today') {
          DailioNavBadgeController.setCount(
            'attendance',
            page.sessions.length,
          );
        }
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

  Future<void> _loadMealAttendance() async {
    if (_isMealLoading) return;
    setState(() {
      _isMealLoading = true;
      _mealError = null;
    });
    try {
      final today = BranchTime.now(_branchTimezone);
      final fromDate = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 29));
      String date(DateTime value) =>
          '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      final from = date(fromDate);
      final to = date(today);
      final results = await Future.wait([
        _mealsRepository.slots(_locationId),
        _mealsRepository.members(_locationId, ''),
        _mealsRepository.servings(_locationId, from: from, to: to, limit: 100),
      ]);
      if (!mounted) return;
      final servingBody = results[2] as Map<String, dynamic>;
      setState(() {
        _mealSlots = (results[0] as List<Map<String, dynamic>>)
            .where((slot) => slot['is_active'] == true)
            .toList();
        _mealMembers = results[1] as List<Map<String, dynamic>>;
        _mealServings = ((servingBody['data'] as List?) ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where((row) => row['status'] == 'CONFIRMED')
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _mealError = '$error');
    } finally {
      if (mounted) setState(() => _isMealLoading = false);
    }
  }

  void _selectSection(String value) {
    if (!_canReadMeals && value == 'meal') return;
    if (_section == value) return;
    setState(() => _section = value);
    if (value == 'meal') {
      _loadMealAttendance();
    } else {
      _loadSessions(_periods[_tabController.index]);
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
      appBar: DailioSimpleAppBar(
        menuItems: [
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
        onMenuSelected: (value) {
          if (value == 'manual') _openManualRecordModal();
          if (value == 'export') _exportAttendance();
        },
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(44.r),
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
          Padding(
            padding: EdgeInsets.fromLTRB(16.r, 10.r, 16.r, 2.r),
            child: DailioTabStrip<String>(
              tabs: _canReadMeals
                  ? const [
                      DailioTabItem(value: 'attendance', label: 'Attendance'),
                      DailioTabItem(value: 'meal', label: 'Meal attendance'),
                    ]
                  : const [
                      DailioTabItem(value: 'attendance', label: 'Attendance'),
                    ],
              selected: _section,
              onChanged: _selectSection,
            ),
          ),
          if (_section == 'attendance') _buildRoleFilters(),
          Expanded(
            child: _section == 'meal'
                ? _buildMealAttendanceBody()
                : _isLoading && _sessions.isEmpty
                    ? ShimmerLoader.compactList()
                    : _error != null && _sessions.isEmpty
                        ? Center(child: Text('Error: $_error'))
                        : _sessions.isEmpty
                            ? _buildEmptyState()
                            : TabBarView(
                                controller: _tabController,
                                children: _periods.map((period) {
                                  return RefreshIndicator(
                                    onRefresh: () => _loadSessions(period),
                                    child: NotificationListener<
                                        ScrollNotification>(
                                      onNotification: (notification) {
                                        if (notification.metrics.pixels >=
                                            notification
                                                    .metrics.maxScrollExtent -
                                                300) {
                                          _loadMoreSessions();
                                        }
                                        return false;
                                      },
                                      child: ListView.separated(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: EdgeInsets.only(
                                          top: 12.r,
                                          bottom: 92.r,
                                        ),
                                        itemCount: _sessions.length +
                                            (_isLoadingMore ? 1 : 0),
                                        separatorBuilder: (_, __) =>
                                            SizedBox(height: 8.r),
                                        itemBuilder: (context, index) {
                                          if (index >= _sessions.length) {
                                            return Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(12.r),
                                                child:
                                                    CircularProgressIndicator(),
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
        padding: EdgeInsets.only(bottom: 78.r),
        child: FloatingActionButton(
          heroTag: 'self_attendance_fab',
          tooltip: 'Self attendance',
          backgroundColor: AttendanceUi.accent,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SelfAttendancePage())),
          child: Icon(Iconsax.finger_scan, size: 27.r),
        ),
      ),
    );
  }

  Widget _buildMealAttendanceBody() {
    if (_isMealLoading && _mealMembers.isEmpty) {
      return ShimmerLoader.compactList();
    }
    if (_mealError != null && _mealMembers.isEmpty) {
      return Center(child: Text('Error: $_mealError'));
    }
    if (_mealMembers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMealAttendance,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 140.r),
            Center(child: Text('No active meal members yet.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMealAttendance,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 10.r, bottom: 92.r),
        itemCount: _mealMembers.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.r),
        itemBuilder: (_, index) =>
            _buildMealAttendanceCard(_mealMembers[index]),
      ),
    );
  }

  Widget _buildMealAttendanceCard(Map<String, dynamic> member) {
    final id = member['id']?.toString();
    final user = (member['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = user['name']?.toString() ?? 'Member';
    final image = user['avatar_url']?.toString();
    final rows =
        _mealServings.where((row) => row['member_id']?.toString() == id);
    final today = BranchTime.now(_branchTimezone);
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayRows = rows.where(
        (row) => row['local_date']?.toString().startsWith(todayKey) == true);
    final markedIds =
        todayRows.map((row) => row['meal_slot_id']?.toString()).toSet();
    final initials = name.isEmpty ? '?' : name[0].toUpperCase();
    final monthCount = rows.length;
    final todayCount = markedIds.length;
    final latestRow = rows.isEmpty ? null : rows.first;
    final latestPunch = latestRow?['served_at']?.toString();
    DateTime? latestInstant;
    if (latestPunch != null) latestInstant = DateTime.tryParse(latestPunch);
    final latestLocal = latestInstant == null
        ? null
        : BranchTime.toBranch(latestInstant, _branchTimezone);
    return DailioCompactTile(
      avatar: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 25.r,
            backgroundColor: MealUi.positive.withValues(alpha: .12),
            backgroundImage:
                image == null || image.isEmpty ? null : NetworkImage(image),
            child: image == null || image.isEmpty
                ? Text(initials,
                    style: TextStyle(
                        color: MealUi.positive,
                        fontSize: 16.r,
                        fontWeight: FontWeight.bold))
                : null,
          ),
          Positioned(
            right: (-4).r,
            bottom: (-3).r,
            child: Container(
              width: 20.r,
              height: 20.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MealUi.positive,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.r),
              ),
              child: Text(
                '$monthCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.r,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      title: name,
      titleBadge: member['member_number']?.toString(),
      subtitle:
          '$todayCount/${_mealSlots.length} today · $monthCount in 30 days',
      /* subtitleWidget: Row(
        children: [
          ..._mealSlots.take(4).map((slot) => MealSlotMark(
                label: slot['name']?.toString() ?? 'Meal',
                marked: markedIds.contains(slot['id']?.toString()),
                compact: true,
              )),
          Flexible(
            child: Text(
              '$todayCount/${_mealSlots.length} today · $monthCount in 30 days',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: MealUi.muted, fontSize: 10.r),
            ),
          ),
        ],
      ),
      trailing: _mealSlots.isEmpty ? '—' : '$todayCount/${_mealSlots.length}',
      */
      subtitleWidget: Text(
        latestLocal == null
            ? 'No meal attendance punched yet'
            : 'Last punched at ${DateFormat('hh:mm a').format(latestLocal)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: MealUi.muted, fontSize: 11.r),
      ),
      trailing: '',
      trailingWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            latestLocal == null
                ? 'No punches'
                : DateFormat('dd MMM').format(latestLocal),
            style: TextStyle(
              color: AppColors.brandDark,
              fontSize: 10.r,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.r),
          Text(
            '$todayCount/${_mealSlots.length} today',
            style: TextStyle(color: MealUi.muted, fontSize: 9.r),
          ),
        ],
      ),
      menuItems: const [],
      onMenuSelected: (_) {},
      onTap: null,
      subtitleColor: MealUi.muted,
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

  Future<void> _removeAttendance(AttendanceSessionModel session) async {
    final reason = await showReasonDialog(
      context,
      title: 'Remove attendance record?',
      message:
          'This hides the record from attendance lists and keeps its evidence and audit history. Enter a reason to continue.',
      confirmLabel: 'Remove record',
      hintText: 'Reason for removal',
      isDestructive: true,
      icon: Iconsax.trash,
    );
    if (reason == null || !mounted) return;
    try {
      await _repository.voidSession(_locationId, session.id, reason);
      if (!mounted) return;
      setState(() => _sessions.removeWhere((item) => item.id == session.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Attendance record removed.'),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(attendanceErrorMessage(error))),
        );
      }
    }
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
      onAvatarTap: session.memberId == null
          ? null
          : () => showDailioMemberProfileSheet(
                context,
                DailioMemberPreview(
                  memberId: session.memberId!,
                  name: session.memberName ?? 'Member',
                  role: roleLabel ?? 'Member',
                  avatarUrl: session.memberAvatar,
                  status: isOpen ? 'ACTIVE' : (isLate ? 'LATE' : 'COMPLETED'),
                ),
              ),
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
        if (_canDelete)
          const DailioMenuItem(
            value: 'delete',
            icon: Iconsax.trash,
            label: 'Delete record',
          ),
      ],
      onMenuSelected: (value) {
        if (value == 'details') _openDetail(session);
        if (value == 'correct') _openCorrectionModal(session);
        if (value == 'delete') _removeAttendance(session);
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
            padding: EdgeInsets.fromLTRB(16.r, 10.r, 8.r, 10.r),
            child: Row(
              children: [
                _buildAttendanceAvatar(session, statusColor, statusIcon),
                SizedBox(width: 10.r),
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
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.r)),
                          ),
                          if (roleLabel != null) ...[
                            SizedBox(width: 7.r),
                            Flexible(child: _buildRoleBadge(roleLabel)),
                          ],
                        ],
                      ),
                      SizedBox(height: 3.r),
                      Row(
                        children: [
                          Icon(statusIcon, size: 13.r, color: statusColor),
                          SizedBox(width: 5.r),
                          Flexible(
                            child: Text(
                              '$eventLabel ${DateFormat('hh:mm a').format(eventTime)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12.r,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.r),
                      Text(
                          '$dateLabel  •  $statusLabel  •  ${session.durationLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AttendanceUi.muted, fontSize: 10.r)),
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
                    if (_canDelete)
                      const DailioMenuItem(
                        value: 'delete',
                        icon: Iconsax.trash,
                        label: 'Delete record',
                      ),
                  ],
                  onSelected: (value) {
                    if (value == 'details') _openDetail(session);
                    if (value == 'correct') _openCorrectionModal(session);
                    if (value == 'delete') _removeAttendance(session);
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
      padding: EdgeInsets.symmetric(horizontal: 7.r, vertical: 3.r),
      decoration: BoxDecoration(
        color: AttendanceUi.accentTint,
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AttendanceUi.accent,
          fontSize: 9.r,
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
          radius: 25.r,
          backgroundColor: AttendanceUi.accentTint,
          backgroundImage:
              image == null || image.isEmpty ? null : NetworkImage(image),
          child: image == null || image.isEmpty
              ? Text(initials,
                  style: TextStyle(
                      color: AttendanceUi.accent,
                      fontSize: 16.r,
                      fontWeight: FontWeight.bold))
              : null,
        ),
        Positioned(
          right: (-2).r,
          bottom: (-2).r,
          child: Container(
            width: 18.r,
            height: 18.r,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.r),
            ),
            child: Icon(statusIcon, size: 9.r, color: Colors.white),
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
                        size: 48.r, color: Colors.grey.shade400),
                    SizedBox(height: 16.r),
                    Text('No attendance records found',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14.r)),
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
          left: 24.r,
          right: 24.r,
          top: 24.r,
          bottom: mq.viewInsets.bottom + 24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Correct Attendance',
                  style:
                      TextStyle(fontSize: 18.r, fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          SizedBox(height: 16.r),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(true),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Clock In',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: Text(_clockInTime?.format(context) ?? '--:--'),
                  ),
                ),
              ),
              SizedBox(width: 12.r),
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Clock Out',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: Text(_clockOutTime?.format(context) ?? '--:--'),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.r),
          DailioPickerField<String>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: 'Status',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
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
          SizedBox(height: 16.r),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Correction Reason*',
              hintText: 'e.g. Forgot to clock out, network issue',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(height: 24.r),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AttendanceUi.accent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.r),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.r))
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
      padding: EdgeInsets.fromLTRB(24.r, 24.r, 24.r, inset + 24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add manual attendance',
                    style:
                        TextStyle(fontSize: 18.r, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            Text(
              'This creates an ADMIN/MANUAL record and requires an audit reason. The server still enforces policy and one open session per member.',
              style: TextStyle(color: Colors.grey, fontSize: 12.r),
            ),
            SizedBox(height: 4.r),
            Text('Times use branch timezone: ${widget.branchTimezone}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.r)),
            SizedBox(height: 16.r),
            DailioPickerField<String>(
              initialValue: _memberId,
              decoration: InputDecoration(
                labelText: 'Member',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r)),
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
            SizedBox(height: 12.r),
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
            SizedBox(height: 12.r),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason*',
                hintText: 'e.g. Member forgot to punch at the gate',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
            SizedBox(height: 20.r),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: CircularProgressIndicator(strokeWidth: 2.r),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
        child: Text(value == null
            ? 'Select date and time'
            : DateFormat('dd MMM yyyy, hh:mm a').format(value)),
      ),
    );
  }
}
