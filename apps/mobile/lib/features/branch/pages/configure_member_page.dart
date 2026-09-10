import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class ConfigureMemberPage extends StatelessWidget {
  const ConfigureMemberPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
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
                          Text('Configure Member', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Member #RFC-108 • Devika Nair', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade100)),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 4, backgroundColor: Colors.green),
                          const SizedBox(width: 6),
                          Text('Active\nMember', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 24),

                // Profile Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              const CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=5')),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: CircleAvatar(radius: 8, backgroundColor: Colors.orange.shade600, child: const Icon(Icons.bolt, size: 10, color: Colors.white)),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Devika Nair', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('ID | RFC - 108', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Row(children: [Icon(Iconsax.sms, size: 12, color: Colors.grey), SizedBox(width: 4), Text('devika.nair@example.com', style: TextStyle(fontSize: 11, color: Colors.grey))]),
                                const SizedBox(height: 2),
                                const Row(children: [Icon(Iconsax.call, size: 12, color: Colors.grey), SizedBox(width: 4), Text('+91 98450 11223', style: TextStyle(fontSize: 11, color: Colors.grey))]),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Iconsax.calendar_1, size: 18, color: Colors.orange.shade400),
                                  const SizedBox(width: 8),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('JOINED', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      Text('14 Jan 2024', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: Colors.orange.shade600, shape: BoxShape.circle),
                                    child: const Icon(Icons.local_fire_department, size: 14, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('STREAK', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      Text('24 Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Role & Facility Access
                _buildSectionCard(
                  title: 'Role & Facility Access',
                  icon: Iconsax.building_4,
                  badge: 'Access Level: Member',
                  children: [
                    _buildLabel('Primary Role'),
                    _buildDropdown('Member / Gymrat'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('Assigned Branch Facility'),
                        const Row(
                          children: [
                            Icon(Icons.swap_horiz, size: 12, color: Colors.orange),
                            SizedBox(width: 4),
                            Text('Transfer Branch', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown('Main Branch - Downtown Indiranagar', icon: Iconsax.location),
                  ],
                ),

                // Assigned Work / Training Shift
                _buildSectionCard(
                  title: 'Assigned Work /\nTraining Shift',
                  icon: Iconsax.clock,
                  badge: 'Morning (06:00 AM - ...',
                  badgeColor: Colors.orange.shade50,
                  badgeTextColor: Colors.orange.shade800,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('Select Rostered Shift'),
                        const Text('Weekly Off: Sun', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown('Morning Shift - 06:00 AM to 02:00 PM', icon: Iconsax.clock),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Iconsax.info_circle, size: 14, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Grace period: 15 mins. • Weekly off: Sunday • Geofence active', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        )
                      ],
                    )
                  ],
                ),

                // Subscription
                _buildSectionCard(
                  title: 'Assign / Change\nSubscription',
                  icon: Iconsax.card,
                  badge: 'Paid (Full ₹0\nDue)',
                  badgeColor: Colors.green.shade50,
                  badgeTextColor: Colors.green.shade700,
                  children: [
                    _buildLabel('Selected Membership Plan'),
                    _buildDropdown('Annual Elite Strength - ₹24,000/yr', icon: Iconsax.monitor),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('START DATE'), _buildDropdown('01 Jan 2025', icon: Iconsax.calendar_1)])),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('EXPIRY DATE'), _buildDropdown('31 Dec 2026', icon: Iconsax.calendar_2)])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        Container(height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
                        Container(height: 4, width: 200, decoration: BoxDecoration(color: Colors.orange.shade600, borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Auto-Renew Subscription', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('Bill linked card upon plan expiry', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        Switch(value: true, onChanged: (v) {}, activeColor: Colors.orange.shade600),
                      ],
                    )
                  ],
                ),

                // Policy Overrides
                _buildSectionCard(
                  title: 'Policy Overrides',
                  icon: Iconsax.shield_tick,
                  badge: 'Audit-Enforced',
                  children: [
                    _buildToggleRow('Exempt from Geofence', 'Allow clock-in outside the Indiranagar radius', false),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                    _buildToggleRow('Selfie Clock-in Mandatory', 'Require facial capture at gate kiosk or mobile', true),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                    _buildToggleRow('Multi-Branch Clock-in', 'Permit cross-attendance at sister clubs', false),
                  ],
                ),

                // Admin Controls
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Iconsax.setting_2, color: Colors.orange, size: 18)),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Administrative\nControls', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          const Icon(Iconsax.user_add, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          const Text('Assign Additional\nRole', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                        child: const Row(
                          children: [
                            Icon(Iconsax.receipt_item, size: 16, color: Colors.orange),
                            SizedBox(width: 12),
                            Text('Issue Fine / Fee Adjustment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Spacer(),
                            Icon(Iconsax.arrow_right_3, size: 14, color: Colors.grey),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                // Payroll
                _buildSectionCard(
                  title: 'Employee\nCompensation & Payroll',
                  icon: Iconsax.wallet_2,
                  badge: 'Eligible for Payroll\nPayouts',
                  badgeColor: Colors.green.shade50,
                  badgeTextColor: Colors.green.shade700,
                  children: [
                    _buildToggleRow('Employee Eligible for Salary (Staff Member)', 'Activate payroll disbursements and direct bank\ntransfers', true),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        children: [
                          _buildPayrollRow(Iconsax.note_text, 'Base Monthly Salary', '₹45,000 / month', Colors.black),
                          const SizedBox(height: 12),
                          _buildPayrollRow(Iconsax.info_circle, 'Allowances & Incentives', '+₹5,000 / PT Session', Colors.orange.shade800),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Iconsax.bank, size: 14, color: Colors.grey),
                              const SizedBox(width: 8),
                              const Text('Payout Bank Account', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const Spacer(),
                              const Text('HDFC •••• 4821', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Iconsax.verify, size: 12, color: Colors.green),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                      child: const Row(
                        children: [
                          Icon(Iconsax.setting_4, size: 16, color: Colors.orange),
                          SizedBox(width: 12),
                          Text('Configure Salary Structure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Spacer(),
                          Icon(Iconsax.arrow_right_3, size: 14, color: Colors.grey),
                        ],
                      ),
                    )
                  ],
                ),

                // Danger Zone
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.shade50.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade100)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Iconsax.warning_2, size: 14, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('DANGER ZONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Iconsax.minus_cirlce, size: 14),
                              label: const Text('Suspend Access', style: TextStyle(fontSize: 11, color: Colors.black)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.white,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Iconsax.close_circle, size: 14),
                              label: const Text('Deactivate', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
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
              ],
            ),

            // Bottom Bar
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Iconsax.save_2, size: 18),
                  label: const Text('Save Member Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required String badge, Color? badgeColor, Color? badgeTextColor, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.orange, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: badgeColor ?? Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                child: Text(badge, style: TextStyle(fontSize: 9, color: badgeTextColor ?? Colors.grey.shade600, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDropdown(String value, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 8)],
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
          const Icon(Iconsax.arrow_down_1, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, String subtitle, bool value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        Switch(value: value, onChanged: (v) {}, activeColor: Colors.orange.shade600),
      ],
    );
  }

  Widget _buildPayrollRow(IconData icon, String title, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}

