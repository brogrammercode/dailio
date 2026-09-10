import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // Branch Sync Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.building_3, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                const Expanded(child: Text('Resolution Fitness • Indiranagar...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 3, backgroundColor: Colors.green),
                      const SizedBox(width: 4),
                      Text('HQ Sync', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Marcus Vance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: () => context.push('/home/profile'),
                                icon: const Icon(Iconsax.edit, size: 14),
                                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.shield_tick, size: 12, color: Colors.orange),
                                SizedBox(width: 4),
                                Text('Owner', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('marcus@resolutionfit.com', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const Text('+91 98765 43210', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Iconsax.shield_security, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ACCESS', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text('Super Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: Colors.grey.shade300),
                      const SizedBox(width: 12),
                      const Icon(Iconsax.security_safe, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('2FA AUTH', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text('Hardware Key', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Organization Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Iconsax.weight, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Resolution Fitne...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Iconsax.verify, color: Colors.orange, size: 14),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Iconsax.setting_4, size: 14),
                                label: const Text('Edit Org', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 32),
                                ),
                              ),
                            ],
                          ),
                          const Text('?? dailio.app/resoluti...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 4, backgroundColor: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Enterprise Tier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Text(' - Annually', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                        child: const Text('? 99.98% SLA', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              const Text('MANAGEMENT & OPERATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                child: const Text('6 Modules', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Modules
          _buildModuleCard(
            icon: Iconsax.lock,
            title: 'Roles & Permissions',
            subtitle: '4 configured RBAC roles ac...',
            actionLabel: 'Configure',
            bottomWidget: Row(
              children: [
                _buildChip('Owner (1)', true),
                const SizedBox(width: 8),
                _buildChip('Branch Mgr (3)', false),
                const SizedBox(width: 8),
                _buildChip('Head Trainer (8)', false),
              ],
            ),
            onTap: () {},
          ),
          
          _buildModuleCard(
            icon: Iconsax.personalcard,
            iconColor: Colors.orange,
            iconBg: Colors.orange.shade50,
            title: 'Members & Admissions',
            subtitle: '350+ enrolled active athletes',
            actionLabel: 'Manage',
            isPrimaryAction: true,
            bottomWidget: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Iconsax.note_add, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  const Text('New Membership Inflow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                    child: const Text('4 Pending Requests', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            onTap: () => context.push(AppRoutes.members),
          ),

          // Branch Locations
          _buildModuleCard(
            icon: Iconsax.hierarchy,
            title: 'Branch Locations',
            subtitle: '3 Facilities Active',
            actionLabel: 'Locations',
            bottomWidget: Row(
              children: [
                _buildBranchStat('Indiranagar', '142 Live', true),
                const SizedBox(width: 8),
                _buildBranchStat('Whitefield', '98 Live', false),
                const SizedBox(width: 8),
                _buildBranchStat('Hebbal', '64 Live', false),
              ],
            ),
            onTap: () {},
          ),

          // Subscriptions
          _buildModuleCard(
            icon: Iconsax.card,
            title: 'Subscriptions',
            subtitle: 'Manage membership tiers, ...',
            badge: '4 Active Plans',
            actionLabel: 'Configure',
            bottomWidget: Row(
              children: [
                _buildChip('Annual Elite', true),
                const SizedBox(width: 8),
                _buildChip('Quarterly Pro', false),
                const SizedBox(width: 8),
                _buildChip('Monthly Flex', false),
              ],
            ),
            onTap: () {},
          ),

          // Shift Config
          _buildModuleCard(
            icon: Iconsax.clock,
            title: 'Shift Configuration',
            subtitle: 'Rosters, grace periods, dut...',
            badge: '3 Shifts',
            actionLabel: 'Configure',
            bottomWidget: Row(
              children: [
                _buildChip('¤ Morning (06:00-14:00)', true),
                const SizedBox(width: 8),
                _buildChip('Evening (14:00-22:00)', false),
              ],
            ),
            onTap: () {},
          ),

          // Payroll
          _buildModuleCard(
            icon: Iconsax.wallet_2,
            iconColor: Colors.orange,
            iconBg: Colors.orange.shade50,
            title: 'Payroll & Comp...',
            subtitle: 'Staff salary structures, wage...',
            badge: '?4.8L Disbursed',
            badgeColor: Colors.green.shade50,
            badgeTextColor: Colors.green,
            actionLabel: 'Manage',
            isPrimaryAction: true,
            bottomWidget: Row(
              children: [
                _buildChip('Monthly Payouts', true),
                const SizedBox(width: 8),
                _buildChip('Base + Incentive', false),
                const SizedBox(width: 8),
                _buildChip('Tax & Deductions', false),
              ],
            ),
            onTap: () {},
          ),

          const SizedBox(height: 24),
          const Text('WORKSPACE SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                _buildToggleRow(Iconsax.notification_bing, 'Push & Shift Alerts', 'Real-time gym floor pings enabled', true),
                const Divider(),
                _buildToggleRow(Iconsax.scan, 'Biometrics & Turnstiles', 'Optical sync • Enforced on punch', true),
                const Divider(),
                Row(
                  children: [
                    const Icon(Iconsax.document_code, size: 20, color: Colors.grey),
                    const SizedBox(width: 12),
                    const Text('Client Build', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                      child: const Text('v2.4.1-prod (r4182)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Iconsax.logout, color: Colors.red),
            label: const Text('Sign Out of Resolution HQ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.red.shade50,
              side: BorderSide(color: Colors.red.shade100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Tap once more to confirm termination of active kiosk sessions.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required IconData icon,
    Color iconColor = Colors.black,
    Color iconBg = const Color(0xFFF3F4F6),
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
    required String actionLabel,
    bool isPrimaryAction = false,
    required Widget bottomWidget,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: badgeColor ?? Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text(badge, style: TextStyle(fontSize: 10, color: badgeTextColor ?? Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                        ]
                      ],
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (isPrimaryAction)
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Text(actionLabel, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      const Icon(Iconsax.arrow_right_3, size: 14),
                    ],
                  ),
                )
              else
                OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Text(actionLabel, style: const TextStyle(fontSize: 12, color: Colors.black)),
                      const SizedBox(width: 4),
                      const Icon(Iconsax.arrow_right_3, size: 14, color: Colors.black),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: bottomWidget),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.orange.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isPrimary ? Colors.orange.shade200 : Colors.grey.shade200),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: isPrimary ? Colors.orange.shade800 : Colors.grey.shade700, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildBranchStat(String name, String stat, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(name, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(stat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 3, backgroundColor: isPrimary ? Colors.green : Colors.grey),
              const SizedBox(width: 4),
              Text(isPrimary ? 'Primary' : 'Secondary', style: TextStyle(fontSize: 8, color: isPrimary ? Colors.green : Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(IconData icon, String title, String subtitle, bool value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        Switch(value: value, onChanged: (v) {}, activeColor: Colors.orange),
      ],
    );
  }
}


