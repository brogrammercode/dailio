import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class PayrollManagementPage extends StatelessWidget {
  const PayrollManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
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
                      Text('Payroll & Salary Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

            // Top Tabs
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.wallet_2, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Salary Structure', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.receipt_item, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Payroll Runs', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Roles (14)', false),
                  const SizedBox(width: 8),
                  _buildFilterChip('Admins (3)', false),
                  const SizedBox(width: 8),
                  _buildFilterChip('Trainers (8)', true),
                  const SizedBox(width: 8),
                  _buildFilterChip('Operations (3)', false),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Header
            Row(
              children: [
                const Expanded(
                  child: Text('Active Compensation\nProfiles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Indiranagar\nUnit', style: TextStyle(fontSize: 10, color: Colors.black)),
                ),
                const SizedBox(width: 12),
                const Icon(Iconsax.setting_4, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                const Text('Formulas\nActive', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Employees
            _buildEmployeeCard(
              name: 'Arjun Mehta',
              id: '#RFC-029',
              role: 'Lead Coach & Personal Trainer',
              avatarIdx: 1,
              baseSalary: '₹55,000',
              varComm: '₹600/session',
              varCommLabel: 'Variable PT Comm.',
              allowances: '₹5,000',
              allowancesType: '(Fit & Med)',
              account: 'HDFC •••• 4821',
              revisedDate: 'Revised 12 Jan 2025',
              isVerified: true,
            ),
            _buildEmployeeCard(
              name: 'Sarah Jenkins',
              id: '#RFC-014',
              role: 'Shift Operations Admin',
              avatarIdx: 4,
              baseSalary: '₹42,000',
              varComm: '₹350/hr',
              varCommLabel: 'Overtime Tier',
              allowances: '₹3,500',
              allowancesType: '(Desk Shift)',
              account: 'ICICI •••• 9923',
              revisedDate: 'Direct Deposit Linked',
              isVerified: true,
              isDirectDeposit: true,
            ),
            _buildEmployeeCard(
              name: 'Karan Sharma',
              id: '#RFC-044',
              role: 'Senior Floor Trainer',
              avatarIdx: 3,
              baseSalary: '₹38,000',
              varComm: '₹450/session',
              varCommLabel: 'Variable Comm.',
              allowances: '₹2,000',
              allowancesType: '(Commute)',
              account: 'SBI •••• 1209',
              revisedDate: 'Standard Tier',
              isVerified: true,
              isStandardTier: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.shade100 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.black : Colors.grey.shade800)),
    );
  }

  Widget _buildEmployeeCard({
    required String name,
    required String id,
    required String role,
    required int avatarIdx,
    required String baseSalary,
    required String varComm,
    required String varCommLabel,
    required String allowances,
    required String allowancesType,
    required String account,
    required String revisedDate,
    required bool isVerified,
    bool isDirectDeposit = false,
    bool isStandardTier = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=$avatarIdx')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text(id, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const Spacer(),
                        if (isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade100)),
                            child: Row(
                              children: [
                                const Icon(Iconsax.verify, size: 10, color: Colors.green),
                                const SizedBox(width: 4),
                                Text('Verified', style: TextStyle(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(role, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Base Salary', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(baseSalary, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Padding(padding: EdgeInsets.only(bottom: 2), child: Text('/mo', style: TextStyle(fontSize: 10, color: Colors.grey))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Fixed Allowances', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text(allowances, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text(allowancesType, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(varCommLabel, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(varComm.split('/')[0], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                          Padding(padding: const EdgeInsets.only(bottom: 1), child: Text('/' + varComm.split('/')[1], style: const TextStyle(fontSize: 10, color: Colors.grey))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Disbursal Account', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Iconsax.bank, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(account, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          Row(
            children: [
              Icon(isDirectDeposit ? Iconsax.lock : (isStandardTier ? Iconsax.verify : Iconsax.clock), size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(revisedDate, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Iconsax.edit, size: 14),
                label: const Text('Edit Structure', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}


