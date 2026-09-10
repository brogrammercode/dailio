import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class SubscriptionPlansPage extends StatelessWidget {
  const SubscriptionPlansPage({super.key});

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
                          Text('Subscription Plans', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

                // Catalog Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_offer, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Membership Plans Catalog', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const CircleAvatar(radius: 3, backgroundColor: Colors.green),
                                const SizedBox(width: 4),
                                Text('Live Sync', style: TextStyle(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Configure branch-level commercial pricing, access rules, and membership perks.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildStatBox('Active Tiers', '04', 'All branches', null)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildStatBox('Enrolled', '352', '+14% MoM', Colors.green)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildStatBox('Annual Run-rate', '₹14.2L', 'Projected', null)),
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
                      _buildTab('Annual Elite', true),
                      const SizedBox(width: 8),
                      _buildTab('Quarterly Pro', false),
                      const SizedBox(width: 8),
                      _buildTab('Monthly Flex', false),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Content Form
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(radius: 4, backgroundColor: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active & Publicly Available', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Members can purchase online and on-counter', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Switch(value: true, onChanged: (v) {}, activeColor: Colors.orange.shade800),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                      
                      Row(
                        children: [
                          const Text('Plan Display Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text('SKU: PLN-ANN-01', style: TextStyle(fontSize: 9, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTextField('Annual Elite Strength & Conditioning'),
                      const SizedBox(height: 24),

                      // Commercial Pricing
                      const Row(children: [Icon(Iconsax.wallet_money, size: 16, color: Colors.orange), SizedBox(width: 8), Text('Commercial Pricing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Base Fee', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 8), _buildTextField('₹ 24,000')])),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 8), _buildDropdown('INR (₹)', icon: Iconsax.lock)])),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Billing Frequency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildDropdown('Every 12 Months (Annual)', icon: Iconsax.arrow_down_1, isRightIcon: true),
                      const SizedBox(height: 16),
                      const Text('One-time Joining Fee', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField('₹ 1,500')),
                          const SizedBox(width: 12),
                          Expanded(flex: 3, child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(
                              children: [
                                const Text('GST 18%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                SizedBox(height: 24, child: Switch(value: true, onChanged: (v){}, activeColor: Colors.orange.shade800)),
                              ],
                            ),
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Duration & Access Rules
                      const Row(children: [Icon(Iconsax.clock, size: 16, color: Colors.orange), SizedBox(width: 8), Text('Duration & Access Rules', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Validity Duration', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 8), _buildTextField('365 Days')])),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Grace Period', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 8), _buildTextField('7 Days')])),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Permitted Time Window', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildDropdown('Full Day Access (05:30 AM - 11:00 PM)', icon: Iconsax.arrow_down_1, isRightIcon: true),
                      const SizedBox(height: 16),
                      const Text('Facility Entitlements', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildCheckboxRow('Main Branch - Indiranagar (Primary Home Base)', true),
                      _buildCheckboxRow('All-branch Cross Attendance Allowed', true),
                      _buildCheckboxRow('Off-peak only restriction', false),
                      const SizedBox(height: 16),

                      // Perks
                      const Text('Complimentary Perks Included', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _buildPerkChip('2 Guest Passes / mo', Iconsax.people),
                          _buildPerkChip('1 Free Trainer Consultation', Icons.fitness_center),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 14, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text('Add Perk', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Branch Matrix
                      const Row(children: [Icon(Iconsax.building_3, size: 16, color: Colors.orange), SizedBox(width: 8), Text('Branch Availability Matrix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _buildBranchMatrixChip('Indiranagar (Active)', true),
                          _buildBranchMatrixChip('Whitefield (Active)', true),
                          _buildBranchMatrixChip('Hebbal (Disabled)', false),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Last Updated
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Iconsax.clock, size: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(fontSize: 10, color: Colors.black),
                                  children: [
                                    TextSpan(text: 'Last updated by Organization Lead '),
                                    TextSpan(text: 'Marcus V.', style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: ' on 15 Feb 2025, 14:22 IST'),
                                  ]
                                )
                              ),
                            )
                          ],
                        ),
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
                      label: const Text('Save Subscription Plan Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      icon: const Icon(Iconsax.archive_minus, size: 16, color: Colors.red),
                      label: const Text('Archive Plan', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red.shade50,
                        side: BorderSide(color: Colors.red.shade100),
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

  Widget _buildStatBox(String title, String value, String subtitle, Color? subtitleColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue.shade50.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor ?? Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? Colors.orange.shade800 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (isActive) ...[const Icon(Iconsax.verify, size: 14, color: Colors.white), const SizedBox(width: 8)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildTextField(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildDropdown(String text, {required IconData icon, bool isRightIcon = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          if (!isRightIcon) ...[Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 8)],
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black))),
          if (isRightIcon) ...[const SizedBox(width: 8), Icon(icon, size: 14, color: Colors.grey)],
        ],
      ),
    );
  }

  Widget _buildCheckboxRow(String label, bool isChecked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: isChecked ? Colors.blue.shade50.withValues(alpha: 0.3) : Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: isChecked ? Colors.blue.shade100 : Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(isChecked ? Icons.check_box : Icons.check_box_outline_blank, color: isChecked ? Colors.orange.shade800 : Colors.grey, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildPerkChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.orange.shade800),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          const Icon(Icons.close, size: 12, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildBranchMatrixChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: isActive ? Colors.green.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: isActive ? Colors.green.shade100 : Colors.transparent)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? Iconsax.verify : Icons.block, size: 12, color: isActive ? Colors.green : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.green.shade700 : Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

