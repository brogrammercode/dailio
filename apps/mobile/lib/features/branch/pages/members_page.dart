import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      
      body: Stack(
        children: [
          ListView(
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
                        Text('Member Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Search, filter, and inspect members across roles and pending admission requests.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      icon: const Icon(Iconsax.document_download, size: 20),
                      onPressed: () {},
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Top Tabs
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.personalcard, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Active\nMembers', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: const Text('350+', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.user_add, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text('Join Requests', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                            child: const Row(
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: Colors.orange),
                                SizedBox(width: 4),
                                Text('4', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search member by name, ID, phone...',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  prefixIcon: const Icon(Iconsax.search_normal_1, size: 18, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All Roles', '354', true),
                    _buildFilterChip('Owners', '1', false),
                    _buildFilterChip('Admins', '2', false),
                    _buildFilterChip('Trainers', '8', false),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Member Cards
              _buildMemberCard(
                name: 'Marcus Vance',
                role: 'OWNER',
                roleBg: Colors.orange.shade50,
                roleColor: Colors.orange,
                subtitle: 'Lead Owner • Indiranagar',
                id: '#RFC-001',
                branch: 'Main Branch\nIndiranagar',
                status: 'Full\nClearance',
                statusColor: Colors.green,
                avatarBadgeIcon: Icons.star,
                avatarBadgeColor: Colors.orange.shade800,
              ),
              _buildMemberCard(
                name: 'Sarah Jenkins',
                role: 'ADMIN',
                roleBg: Colors.blue.shade50,
                roleColor: Colors.blue.shade800,
                subtitle: 'Shift Manager • Whitefield',
                id: '#RFC-014',
                branch: 'East Branch\nWhitefield',
                status: 'Morning\nShift',
                statusColor: Colors.grey.shade800,
                avatarBadgeIcon: Icons.shield,
                avatarBadgeColor: Colors.blue.shade800,
              ),
              _buildMemberCard(
                name: 'Arjun Mehta',
                role: 'TRAINER',
                roleBg: Colors.orange.shade50,
                roleColor: Colors.orange.shade800,
                subtitle: 'Head Strength Coach • Indir...',
                id: '#RFC-029',
                branchText: '16 Active Clients',
                status: 'Floor Active',
                statusColor: Colors.green,
                avatarBadgeIcon: Icons.fitness_center,
                avatarBadgeColor: Colors.orange.shade800,
                statusIcon: Iconsax.verify,
              ),
              _buildMemberCard(
                name: 'Devika Nair',
                role: 'GYMRAT',
                roleBg: Colors.grey.shade100,
                roleColor: Colors.grey.shade800,
                subtitle: 'Member • Indiranagar',
                id: '#RFC-108',
                status: 'Active Annual Plan (284d left)',
                statusColor: Colors.green,
                avatarBadgeIcon: Icons.bolt,
                avatarBadgeColor: Colors.grey.shade700,
                statusIcon: Iconsax.verify,
              ),
              _buildMemberCard(
                name: 'Rohan Sharma',
                role: 'GYMRAT',
                roleBg: Colors.grey.shade100,
                roleColor: Colors.grey.shade800,
                subtitle: 'Member • Whitefield',
                id: '#RFC-245',
                status: 'Fee Overdue • 6 Days',
                statusColor: Colors.red,
                avatarBadgeIcon: Icons.warning_amber,
                avatarBadgeColor: Colors.red,
                statusIcon: Iconsax.warning_2,
                isWarning: true,
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Iconsax.task_square, size: 16),
                      label: const Text('Review 4 Pending', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Iconsax.user_add, size: 16),
                      label: const Text('+ New Admission', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String count, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.orange.shade800 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isActive ? Colors.white : Colors.grey.shade800, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: isActive ? Colors.orange.shade900 : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: Text(count, style: TextStyle(fontSize: 10, color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildMemberCard({
    required String name,
    required String role,
    required Color roleBg,
    required Color roleColor,
    required String subtitle,
    required String id,
    String? branch,
    String? branchText,
    required String status,
    required Color statusColor,
    required IconData avatarBadgeIcon,
    required Color avatarBadgeColor,
    IconData? statusIcon,
    bool isWarning = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isWarning ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  const CircleAvatar(radius: 24, backgroundImage: NetworkImage('https://i.pravatar.cc/150')),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(radius: 8, backgroundColor: avatarBadgeColor, child: Icon(avatarBadgeIcon, size: 10, color: Colors.white)),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(role, style: TextStyle(fontSize: 9, color: roleColor, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Iconsax.setting_4, size: 14),
                label: const Text('Configure', style: TextStyle(fontSize: 12, color: Colors.black)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          Row(
            children: [
              Text('ID:', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              const SizedBox(width: 4),
              Text(id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              if (branch != null || branchText != null) ...[
                CircleAvatar(radius: 2, backgroundColor: Colors.grey.shade300),
                const SizedBox(width: 16),
                if (branch != null) ...[
                  const Icon(Iconsax.building, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(branch, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ] else ...[
                  Text(branchText!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const Spacer(),
              ] else ...[
                const Spacer(),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: isWarning ? Colors.red.shade50 : statusColor.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: isWarning ? Border.all(color: Colors.red.shade100) : null),
                child: Row(
                  children: [
                    if (statusIcon != null) ...[
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                    ] else ...[
                      CircleAvatar(radius: 3, backgroundColor: statusColor),
                      const SizedBox(width: 4),
                    ],
                    Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

