import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class SelfAttendancePage extends StatefulWidget {
  const SelfAttendancePage({super.key});

  @override
  State<SelfAttendancePage> createState() => _SelfAttendancePageState();
}

class _SelfAttendancePageState extends State<SelfAttendancePage>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0 = Today, 1 = Attendance Record
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _selectedTab = _tabController.index);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          _selectedTab == 0 ? _buildTodayBottomActions() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Dailio ',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('ATTENDANCE',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('Main Branch - Indiranagar',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Iconsax.refresh, size: 10, color: Colors.grey.shade400)
            ],
          )
        ],
      ),
      actions: [
        IconButton(
            icon: const Icon(Iconsax.notification, color: Colors.black),
            onPressed: () {}),
        const Padding(
          padding: EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.black,
            child: Text('D',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF8D490B),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF8D490B),
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Today'),
          Tab(text: 'Attendance Record'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // TODAY TAB
  // ---------------------------------------------------------
  Widget _buildTodayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLivePulseCard(),
          const SizedBox(height: 16),
          _buildActiveSessionCard(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildShiftTimeline(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLivePulseCard() {
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(_currentTime);
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
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF8D490B), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Text('LIVE SHIFT PULSE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4B5563))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('IST (UTC+5:30)',
                    style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeStr,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                      color: Colors.black)),
              Row(
                children: [
                  const Icon(Iconsax.verify,
                      color: Color(0xFF8D490B), size: 14),
                  const SizedBox(width: 4),
                  const Text('Synced',
                      style: TextStyle(
                          color: Color(0xFF8D490B),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 4),
          Text('$dateStr • Asia/Kolkata',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.tick_circle,
                    color: Colors.green.shade700, size: 14),
                const SizedBox(width: 6),
                Text('Active Session: 02h 14m',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Punch Button
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF8D490B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF8D490B),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF8D490B).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8))
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fingerprint, color: Colors.white, size: 48),
                  SizedBox(height: 8),
                  Text('PUNCH',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text('Tap to Confirm Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Clocked in at 06:28 AM • Morning Strength',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),

          const SizedBox(height: 24),
          _buildVerificationPill(Iconsax.location,
              'Main Branch Geofence Verified', '12m beacon', Colors.green),
          const SizedBox(height: 8),
          _buildVerificationPill(Iconsax.user_tick,
              'Live Selfie & Liveness Checked', null, Colors.green,
              hasAvatar: true),
          const SizedBox(height: 8),
          _buildVerificationPill(
              Icons.phone_android,
              'SM-G998B • Zero Mock Location',
              'Secured',
              const Color(0xFF4F46E5),
              isBlue: true),
        ],
      ),
    );
  }

  Widget _buildVerificationPill(
      IconData icon, String title, String? trailing, Color color,
      {bool hasAvatar = false, bool isBlue = false}) {
    final bgColor = isBlue ? const Color(0xFFEEF2FF) : Colors.green.shade50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87))),
          if (trailing != null)
            Text(trailing,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          if (hasAvatar)
            const CircleAvatar(
                radius: 8,
                backgroundImage:
                    NetworkImage('https://i.pravatar.cc/150?img=32')),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
            child: _buildStatBox('Expected', '6.0', 'hrs', '06:00 - 12:00')),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatBox('Elapsed', '02h', '14m', '37% Shift',
                valueColor: const Color(0xFF8D490B),
                subtitleColor: Colors.green.shade700)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatBox('Punctuality', '+4', 'min', 'On-Time',
                valueColor: Colors.green.shade700,
                subtitleColor: Colors.green.shade700)),
      ],
    );
  }

  Widget _buildStatBox(String title, String val1, String val2, String subtitle,
      {Color? valueColor, Color? subtitleColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(val1,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.black,
                      height: 1)),
              const SizedBox(width: 2),
              Text(' $val2',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.black,
                      height: 1.2)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor ?? Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildShiftTimeline() {
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
              const Row(
                children: [
                  Icon(Iconsax.clock, size: 16),
                  SizedBox(width: 8),
                  Text('Shift Timeline',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('4 Checkpoints',
                  style: TextStyle(
                      color: const Color(0xFF8D490B),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _buildTimelineItem(
              Iconsax.login_1,
              'Clocked In',
              '06:28 AM',
              'Front Turnstile • Biometric & Selfie Verified\n12.9716° N, 77.6412° E',
              Colors.green.shade700,
              isFirst: true),
          _buildTimelineItem(
              Iconsax.location,
              'Floor Check-in',
              '07:15 AM',
              'Strength & Conditioning Zone B • Beacon Scan',
              const Color(0xFF8D490B)),
          _buildTimelineItem(
              Iconsax.cup,
              'Hydration Break',
              '08:30 AM',
              'Pantry Lounge Terminal • 10 min break recorded',
              Colors.blueGrey),
          _buildTimelineItem(
              Icons.radio_button_checked,
              'Active Duty',
              'Now',
              'Gym Floor Zone A • Roster duty in progress',
              Colors.green.shade700,
              isLast: true),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
      IconData icon, String title, String time, String desc, Color color,
      {bool isFirst = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isLast
                        ? Colors.transparent
                        : color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: isLast ? Border.all(color: color, width: 2) : null,
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isLast ? color : Colors.black87)),
                      const SizedBox(width: 8),
                      Text(time,
                          style: TextStyle(
                              color: isLast ? color : Colors.grey.shade500,
                              fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          height: 1.4)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTodayBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Iconsax.cup, size: 16),
              label: const Text('Record Break',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Iconsax.logout, size: 16),
              label: const Text('Clock Out',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // HISTORY TAB
  // ---------------------------------------------------------
  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Attendance History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Personal logs & verification timeline',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(Iconsax.export,
                        size: 12, color: Colors.orange.shade800),
                    const SizedBox(width: 4),
                    Text('Export',
                        style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          _buildCyclePerformance(),
          const SizedBox(height: 16),
          _buildFilterTabs(),
          const SizedBox(height: 16),
          _buildFilterChips(),
          const SizedBox(height: 16),
          _buildHistoryCardToday(),
          const SizedBox(height: 16),
          _buildHistoryCardCompleted(),
          const SizedBox(height: 16),
          _buildHistoryCardLate(),
          const SizedBox(height: 16),
          _buildHistoryCardMissing(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCyclePerformance() {
    return Container(
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
                child: const Text('March 2025',
                    style: TextStyle(
                        color: Color(0xFF8D490B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCycleStat('Total', '24', 'Days', null)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildCycleStat(
                      'Present', '22', '91.6%', Colors.green.shade50)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildCycleStat(
                      'Late', '2', '8.4%', Colors.orange.shade50)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildCycleStat('Rate', '96%', '~+2%', Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.orange.shade700,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 92,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const Expanded(flex: 8, child: SizedBox()),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCycleStat(String title, String val, String sub, Color? bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: bgColor ?? Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(val,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, height: 1)),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Expanded(
              child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFF8D490B), width: 2))),
            child: const Text('This Week',
                style: TextStyle(
                    color: Color(0xFF8D490B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          )),
          Expanded(
              child: Container(
            alignment: Alignment.center,
            child: Text('This Month',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          )),
          Expanded(
              child: Container(
            alignment: Alignment.center,
            child: Text('Custom',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          )),
          Container(
            width: 40,
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(8)),
                border: Border(left: BorderSide(color: Colors.grey.shade200))),
            child: const Icon(Icons.tune, size: 16, color: Colors.black87),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _buildChip('All Statuses', '5', true),
        const SizedBox(width: 8),
        _buildChip('Present', '4', false, color: Colors.green),
        const SizedBox(width: 8),
        _buildChip('Late', '1', false, color: Colors.orange.shade700),
      ],
    );
  }

  Widget _buildChip(String label, String count, bool active, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: active ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: active ? Colors.black : Colors.grey.shade300)),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  color: active ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
                color: active ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4)),
            child: Text(count,
                style: TextStyle(
                    color: active ? Colors.white : Colors.grey.shade600,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryCardToday() {
    return Container(
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
                  color: Colors.green.shade600,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(16))),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Today • 02 Mar 2025',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(Iconsax.verify,
                                  size: 12, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text('Present • In Progress',
                                  style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Morning Shift (06:30 AM - 01:00 PM)',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimeCol('CLOCK IN', '06:28 AM'),
                        _buildTimeCol('CLOCK OUT', '--:--'),
                        _buildTimeCol('LOGGED', '2h 14m',
                            valueColor: const Color(0xFF8D490B)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildSmallPill(Icons.camera_alt_outlined,
                            'Selfie Verified', Colors.blueGrey),
                        const SizedBox(width: 8),
                        _buildSmallPill(Icons.location_on_outlined,
                            'Indiranagar HQ', Colors.blueGrey),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSmallPill(
                        Icons.shield_outlined, 'Zero Anomaly', Colors.blueGrey),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Shift Activity Log (3 events)',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                        Icon(Icons.keyboard_arrow_down,
                            size: 16, color: Colors.grey.shade500),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildActivityRow('06:28 AM',
                        'Punched in at Main Turnstile', Colors.green),
                    const SizedBox(height: 8),
                    _buildActivityRow('08:30 AM', 'Morning Break started (15m)',
                        Colors.blueGrey),
                    const SizedBox(height: 8),
                    _buildActivityRow('Active', 'Floor 2 Zone B Workstation',
                        const Color(0xFF8D490B)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(String time, String desc, Color color) {
    return Row(
      children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(time,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(desc,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11))),
      ],
    );
  }

  Widget _buildHistoryCardCompleted() {
    return Container(
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
                    color: Colors.green.shade100,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saturday • 01 Mar 2025',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Row(
                          children: [
                            Icon(Iconsax.verify,
                                size: 12, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text('Present • Completed',
                                style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Morning Shift Regular',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimeCol('CLOCK IN', '06:30 AM'),
                        _buildTimeCol('CLOCK OUT', '12:45 PM'),
                        _buildTimeCol('TOTAL', '6h 15m'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildSmallPill(Icons.camera_alt_outlined,
                            'Selfie + Geo', Colors.blueGrey),
                        const SizedBox(width: 8),
                        _buildSmallPill(Icons.check, 'Shift Fulfilled',
                            Colors.green.shade700),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.history,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text('06:30 Clock In → 10:00 Break → 12:45 Clock Out',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle,
                            size: 12, color: Colors.green.shade600),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCardLate() {
    return Container(
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
                    color: const Color(0xFF8D490B),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Friday • 28 Feb 2025',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(Iconsax.clock,
                                  size: 12, color: Colors.orange.shade800),
                              const SizedBox(width: 4),
                              Text('Late (+22m)',
                                  style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Roster: 06:30 AM Call',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimeCol('CLOCK IN', '06:52 AM',
                            valueColor: const Color(0xFF8D490B)),
                        _buildTimeCol('CLOCK OUT', '01:10 PM'),
                        _buildTimeCol('TOTAL', '6h 18m'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: Colors.orange.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Grace Period Exceeded',
                                    style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                    'Shift scheduled 06:30 AM. Punch registered 06:52 AM. Approved by Operations Admin.',
                                    style: TextStyle(
                                        color: Colors.orange.shade900,
                                        fontSize: 10)),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCardMissing() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.help_outline,
                          color: Colors.orange.shade800, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Missing a Punch?',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Raise an attendance discrepancy request.',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 11)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Colors.grey.shade300)),
                      child: const Text('Request',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildSmallPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
