import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/storage/preferences_storage.dart';
import '../controllers/attendance_repository.dart';
import '../models/attendance_models.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> with SingleTickerProviderStateMixin {
  late final AttendanceRepository _repository;
  late final String _locationId;
  
  late TabController _tabController;
  final List<String> _periods = ['today', 'yesterday', 'this_week', 'this_month'];
  
  AttendanceSessionModel? _activeSession;
  List<AttendanceSessionModel> _sessions = [];
  bool _isLoading = false;
  bool _isClockLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AttendanceRepository>();
    _locationId = context.read<PreferencesStorage>().activeBranchId!;
    
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    _loadAll();
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

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final active = await _repository.getActiveSession(_locationId);
      final list = await _repository.getSessions(_locationId, _periods[_tabController.index]);
      setState(() {
        _activeSession = active;
        _sessions = list;
      });
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSessions(String period) async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getSessions(_locationId, period);
      setState(() {
        _sessions = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clockIn() async {
    setState(() => _isClockLoading = true);
    try {
      await _repository.clockIn(_locationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clocked in successfully')));
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        setState(() => _isClockLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _clockOut(String sessionId) async {
    setState(() => _isClockLoading = true);
    try {
      await _repository.clockOut(_locationId, sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clocked out successfully')));
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        setState(() => _isClockLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(icon: const Icon(Icons.campaign), onPressed: () {}), // Announcements stub
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Yesterday'),
            Tab(text: 'This Week'),
            Tab(text: 'This Month'),
          ],
        ),
      ),
      body: _isLoading && _sessions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _sessions.isEmpty
              ? Center(child: Text('Error: $_error'))
              : _sessions.isEmpty
                  ? const Center(child: Text('No attendance records.'))
                  : TabBarView(
                      controller: _tabController,
                      children: _periods.map((period) {
                        return ListView.builder(
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            final clockInStr = '${session.clockInServerTime.hour.toString().padLeft(2, '0')}:${session.clockInServerTime.minute.toString().padLeft(2, '0')}';
                            final clockOutStr = session.clockOutServerTime != null 
                              ? '${session.clockOutServerTime!.hour.toString().padLeft(2, '0')}:${session.clockOutServerTime!.minute.toString().padLeft(2, '0')}'
                              : 'Open';
                              
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.access_time)),
                              title: Text(session.memberName ?? '${session.clockInServerTime.year}-${session.clockInServerTime.month}-${session.clockInServerTime.day}'),
                              subtitle: Text('In: $clockInStr - Out: $clockOutStr\nDuration: ${session.durationLabel}'),
                              isThreeLine: true,
                              trailing: Chip(label: Text(session.derivedStatus ?? session.state)),
                            );
                          },
                        );
                      }).toList(),
                    ),
      floatingActionButton: _isClockLoading
          ? const FloatingActionButton(onPressed: null, child: CircularProgressIndicator(color: Colors.white))
          : FloatingActionButton.extended(
              onPressed: _activeSession == null ? _clockIn : () => _clockOut(_activeSession!.id),
              icon: Icon(_activeSession == null ? Icons.login : Iconsax.logout),
              label: Text(_activeSession == null ? 'Clock In' : 'Clock Out'),
            ),
    );
  }
}
