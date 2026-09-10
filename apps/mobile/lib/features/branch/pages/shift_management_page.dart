import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class ShiftManagementPage extends StatelessWidget {
  const ShiftManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 150),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: IconButton(
                        icon: const Icon(Iconsax.arrow_left, size: 20),
                        onPressed: () => context.pop(),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shift Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: Colors.green),
                              SizedBox(width: 4),
                              Text('Main Branch - Indiranagar', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const Icon(Iconsax.message_question, size: 20, color: Colors.grey),
                    const SizedBox(width: 12),
                    const CircleAvatar(radius: 14, backgroundColor: Colors.black, child: Text('D', style: TextStyle(color: Colors.white, fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 24),

                // Overview Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(radius: 4, backgroundColor: Colors.green),
                          const SizedBox(width: 8),
                          const Text('LIVE BRANCH OPERATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Iconsax.verify, size: 10, color: Colors.green),
                                const SizedBox(width: 4),
                                Text('99.2% Punctuality', style: TextStyle(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Workforce Shifts & Rosters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Indiranagar Central Studio • Cycle Q2', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildStatBox('Active Shifts', '3', null)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildStatBox('Rostered Staff', '28', null)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildStatBox('Floor Coverage', '18.5h', null)),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Horizontal Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTab('Morning Shift', Iconsax.sun_1, true),
                      const SizedBox(width: 8),
                      _buildTab('Evening Shift', Iconsax.moon, false),
                      const SizedBox(width: 8),
                      _buildTab('General Duty', Iconsax.clock, false),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Shift Details Form
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Morning Shift Regular', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                      child: Text('Active', style: TextStyle(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text('Code: SFT-MOR-01 • 22 Assigned', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Switch(value: true, onChanged: (v) {}, activeColor: Colors.orange.shade800),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Shift Label', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildTextField('Morning Shift Regular', Iconsax.building_4),
                      const SizedBox(height: 24),

                      // Time Slot
                      Row(
                        children: [
                          const Icon(Iconsax.clock, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Operating Time Slot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text('8h 00m Total Duration', style: TextStyle(fontSize: 9, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Shift Start', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 8), _buildTextField('06:00 AM', Iconsax.clock)])),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Shift End', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 8), _buildTextField('02:00 PM', Iconsax.timer_1)])),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Grace Window
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Iconsax.timer_1, size: 14, color: Colors.orange),
                                const SizedBox(width: 8),
                                const Text('Arrival Grace Window', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text('15 Mins', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Stack(
                              children: [
                                Container(height: 4, decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(2))),
                                Container(height: 4, width: 80, decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(2))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Punches recorded up to 06:15 AM marked on-time\nwithout penalties.', style: TextStyle(fontSize: 10, color: Colors.blue.shade800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Early Departure', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  const Text('15 Mins Tol.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  const Text('Valid past 01:45 PM', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Half-Day Limit', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  const Text('4h Minimum', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  const Text('Requires 240 mins', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Breaks & Roster Rules
                      const Row(children: [Icon(Iconsax.cup, size: 16, color: Colors.grey), SizedBox(width: 8), Text('Breaks & Roster Rules', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mandated Rest Break', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('Deducted automatically from shift time', style: TextStyle(fontSize: 9, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                            child: const Text('30 mins', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Auto-close Incomplete Shifts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('Applies to unpunched check-outs', style: TextStyle(fontSize: 9, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                            child: const Text('After 10h', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Recurrence Pattern
                      Row(
                        children: [
                          const Icon(Iconsax.calendar, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text('Recurrence Pattern', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('6 Days Operating', style: TextStyle(fontSize: 9, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDayChip('M', true),
                          _buildDayChip('T', true),
                          _buildDayChip('W', true),
                          _buildDayChip('T', true),
                          _buildDayChip('F', true),
                          _buildDayChip('S', true),
                          _buildDayChip('S', false),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Sunday tagged as weekly standard rest window.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 24),

                      // Geofence & Compliance Audit
                      const Row(children: [Icon(Iconsax.shield_tick, size: 16, color: Colors.orange), SizedBox(width: 8), Text('Geofence & Compliance Audit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 16),
                      _buildCheckboxRow('Geofence Boundary Required', 'Radius 50m around Main Branch Indiranagar', true, Iconsax.location),
                      _buildCheckboxRow('Mandatory Live Selfie Punch', 'Biometric anti-spoof verification enabled', true, Iconsax.camera),
                      _buildCheckboxRow('Permit Sister Branches', 'Allows punch at Koramangala & Whitefield', false, Iconsax.hierarchy),
                      const SizedBox(height: 24),

                      // Assigned Personnel
                      Row(
                        children: [
                          const Icon(Iconsax.people, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Assigned Personnel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          const Text('Manage Shift Roster', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                          const Icon(Iconsax.arrow_right_3, size: 12, color: Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 100, height: 24,
                            child: Stack(
                              children: [
                                const Positioned(left: 0, child: CircleAvatar(radius: 12, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=1'))),
                                const Positioned(left: 16, child: CircleAvatar(radius: 12, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=2'))),
                                const Positioned(left: 32, child: CircleAvatar(radius: 12, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'))),
                                Positioned(left: 48, child: CircleAvatar(radius: 12, backgroundColor: Colors.orange.shade800, child: const Text('+19', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)))),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('22 Scheduled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text('Devika, Arjun & 20 more', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),

            // Bottom Bar
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.9), blurRadius: 10, spreadRadius: 10)],
                ),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Iconsax.save_2, size: 18),
                      label: const Text('Save Shift Parameters', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Iconsax.copy, size: 16, color: Colors.black),
                      label: const Text('Duplicate to Other Branches', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade300),
                        minimumSize: const Size(double.infinity, 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String value, String? subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? Colors.orange.shade800 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isActive ? Colors.white : Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey.shade700)),
          if (isActive) ...[const SizedBox(width: 8), const CircleAvatar(radius: 3, backgroundColor: Colors.white)],
        ],
      ),
    );
  }

  Widget _buildTextField(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDayChip(String letter, bool isActive) {
    return Container(
      width: 36, height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.shade800 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(letter, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey.shade500)),
    );
  }

  Widget _buildCheckboxRow(String title, String subtitle, bool isChecked, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
          Icon(isChecked ? Icons.check_box : Icons.check_box_outline_blank, color: isChecked ? Colors.orange.shade800 : Colors.grey, size: 18),
        ],
      ),
    );
  }
}
