import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class RolesPermissionsPage extends StatelessWidget {
  const RolesPermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      
      body: Stack(
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
                        Text('Roles & Permissions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Granular RBAC matrix per atomic catalog', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 3, backgroundColor: Colors.green),
                        const SizedBox(width: 4),
                        Text('Live Sync', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),

              // Role Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRoleTab('Owner', 'Full ALL', Iconsax.shield_tick, false),
                    const SizedBox(width: 8),
                    _buildRoleTab('Admin', '8 Perms', Iconsax.shield_security, true),
                    const SizedBox(width: 8),
                    _buildRoleTab('Trainer', '3 Perms', Iconsax.activity, false),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Admin Scope Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.orange.shade50, Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.shield_search, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Text('Admin Operational Scope', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade300)),
                          child: const Row(
                            children: [
                              Icon(Iconsax.lock, size: 10, color: Colors.orange),
                              SizedBox(width: 4),
                              Text('RBAC-02', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Grants operational access across attendance verification, member admission, and shift management. Ownership transfer and irreversible deletion remain strictly restricted.', style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Iconsax.people, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text('8 active staff members', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        SizedBox(
                          width: 80, height: 24,
                          child: Stack(
                            children: [
                              const Positioned(right: 48, child: CircleAvatar(radius: 12, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=1'))),
                              const Positioned(right: 32, child: CircleAvatar(radius: 12, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=2'))),
                              const Positioned(right: 16, child: CircleAvatar(radius: 12, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'))),
                              Positioned(right: 0, child: CircleAvatar(radius: 12, backgroundColor: Colors.grey.shade200, child: const Text('+5', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                            ],
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Permissions Group: Attendance
              _buildPermissionGroup(
                title: 'Attendance & Workforce\nVerification',
                subtitle: 'Verification, shift limits, & logs',
                icon: Iconsax.user_tick,
                badge: '3/4\nEnabled',
                iconColor: Colors.red.shade800,
                iconBg: Colors.orange.shade50,
                children: [
                  _buildToggleRow('ATTENDANCE_READ_ALL', 'View biometric check-in history across all club facilities', true, hasInfo: true),
                  _buildToggleRow('ATTENDANCE_UPDATE', 'Manually override and resolve punch timestamp anomalies', true, hasInfo: true),
                  _buildToggleRow('SHIFT_MANAGE', 'Configure trainer rosters, duty hours, and coverage zones', true),
                  _buildToggleRow('ATTENDANCE_EXPORT', 'Download external forensic auditing exports', false, tag: 'CSV/PDF'),
                ],
              ),

              // Permissions Group: Members
              _buildPermissionGroup(
                title: 'Members & Admissions',
                subtitle: 'Onboarding, profiles & state limits',
                icon: Iconsax.personalcard,
                badge: '3/4 Enabled',
                iconColor: Colors.orange.shade800,
                iconBg: Colors.orange.shade50,
                children: [
                  _buildToggleRow('MEMBER_READ_ALL', 'Query client roster, membership tiers, and contact dossier', true),
                  _buildToggleRow('JOIN_REQUEST_APPROVE', 'Review pending digital applications and assign initial key fobs', true),
                  _buildToggleRow('MEMBER_SUSPEND', 'Temporarily freeze turnstile access due to policy infractions', true),
                  _buildToggleRow('MEMBER_DEACTIVATE', 'Permanently purge membership contract and audit profile', false, tag: 'High Impact', tagColor: Colors.red),
                ],
              ),

              // Permissions Group: Fees
              _buildPermissionGroup(
                title: 'Fees & Subscriptions',
                subtitle: 'POS charges, invoicing & refunds',
                icon: Iconsax.wallet_2,
                badge: '2/3 Enabled',
                iconColor: Colors.orange.shade800,
                iconBg: Colors.orange.shade50,
                children: [
                  _buildToggleRow('SUBSCRIPTION_CREATE', 'Setup recurring plans and assign personal training add-ons', true),
                  _buildToggleRow('PAYMENT_CREATE', 'Process walk-in session passes and locker key deposits', true),
                  _buildRestrictedToggleRow('PAYMENT_REFUND', 'Authorize ledger rollbacks and merchant account returns', 'Restricted to Owner'),
                ],
              ),
            ],
          ),

          // Bottom Bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.verify, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text('Policy Baseline: ', style: TextStyle(fontSize: 11)),
                      const Text('Strict', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('Ready to deploy changes', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Iconsax.save_2, size: 16),
                          label: const Text('Save Role Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Iconsax.refresh, size: 16),
                          label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRoleTab(String name, String count, IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.shade700 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.orange.shade700 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isActive ? Colors.white : Colors.grey),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.black)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: isActive ? Colors.orange.shade900 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Text(count, style: TextStyle(fontSize: 9, color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildPermissionGroup({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required Color iconColor,
    required Color iconBg,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade100)),
                child: Text(badge.replaceAll('\n', ' '), style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, String subtitle, bool value, {bool hasInfo = false, String? tag, Color? tagColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    if (hasInfo) ...[
                      const SizedBox(width: 4),
                      const Icon(Iconsax.info_circle, size: 12, color: Colors.grey),
                    ],
                    if (tag != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: (tagColor ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: (tagColor ?? Colors.grey).withOpacity(0.3))),
                        child: Text(tag, style: TextStyle(fontSize: 8, color: tagColor ?? Colors.grey.shade700, fontWeight: FontWeight.bold)),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {},
            activeColor: Colors.orange.shade700,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictedToggleRow(String title, String subtitle, String restrictionTag) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey.shade400)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          const Icon(Iconsax.lock, size: 10, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(restrictionTag, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Switch(
            value: false,
            onChanged: null, // Disabled
            trackColor: WidgetStateProperty.all(Colors.grey.shade200),
            thumbColor: WidgetStateProperty.all(Colors.grey.shade300),
          ),
        ],
      ),
    );
  }
}

