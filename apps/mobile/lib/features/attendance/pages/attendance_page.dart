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
                              return ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _sessions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _buildAttendanceCard(_sessions[index]);
                                },
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

  Widget _buildAttendanceCard(AttendanceSessionModel session) {
    final clockInStr =
        '${session.clockInServerTime.hour.toString().padLeft(2, '0')}:${session.clockInServerTime.minute.toString().padLeft(2, '0')}';
    final clockOutStr = session.clockOutServerTime != null
        ? '${session.clockOutServerTime!.hour.toString().padLeft(2, '0')}:${session.clockOutServerTime!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    final statusColor = session.derivedStatus == 'PRESENT'
        ? Colors.green
        : session.derivedStatus == 'LATE'
            ? Colors.orange
            : session.derivedStatus == 'ABSENT'
                ? Colors.red
                : Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      session.memberName?.isNotEmpty == true
                          ? session.memberName![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    session.memberName ?? 'Unknown Member',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(session.derivedStatus ?? session.state,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeCol('CLOCK IN', clockInStr),
              _buildTimeCol('CLOCK OUT', clockOutStr),
              _buildTimeCol('DURATION', session.durationLabel,
                  valueColor: const Color(0xFF8D490B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCol(String label, String time,
      {Color valueColor = Colors.black}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(time,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.document_text_1, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No attendance records found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }
}
