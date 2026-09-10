import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      
      body: Stack(
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
                        Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Update personal identity, contact details, & notifications.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Avatar
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200, width: 2)),
                          child: const CircleAvatar(radius: 40, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11')),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.orange.shade600,
                              child: const Icon(Iconsax.camera, size: 14, color: Colors.white),
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Change photo', style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                    const Text('JPG or PNG • Max 5MB', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Google Verified
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade100)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Iconsax.shield_tick, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Google Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              SizedBox(width: 4),
                              Icon(Iconsax.verify, size: 14, color: Colors.green),
                            ],
                          ),
                          Text('marcus@resolutionfit.com', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                      child: const Icon(Iconsax.lock, size: 16, color: Colors.grey),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Member Identity
              _buildSectionTitle('Member Identity', badge: 'REQUIRED', badgeColor: Colors.orange.shade50, badgeTextColor: Colors.orange),
              const SizedBox(height: 12),
              _buildLabel('Full Name'),
              _buildTextField('Marcus Vance', Iconsax.user),
              const SizedBox(height: 16),
              _buildLabel('Phone Number'),
              _buildTextFieldWithBadge('+91 98765 43210', Iconsax.call, 'Verified', Colors.green.shade50, Colors.green),
              const SizedBox(height: 16),
              _buildLabel('Designation & Operational Title'),
              _buildTextField('Head of Operations & Organization Owner', Iconsax.award),
              const SizedBox(height: 32),

              // Emergency Contact
              _buildSectionTitle('Emergency Contact', badge: 'SAFETY CONTACT', badgeColor: Colors.transparent, badgeTextColor: Colors.grey),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildLabel('Contact Person'),
                    _buildTextFieldNoIcon('Sarah Vance'),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildLabel('Relationship'),
                    _buildTextFieldNoIcon('Spouse'),
                  ])),
                ],
              ),
              const SizedBox(height: 16),
              _buildLabel('Emergency Phone'),
              _buildTextField('+91 98111 22334', Iconsax.call),
              const SizedBox(height: 32),

              // Bio
              _buildSectionTitle('Member Notes / Bio', badge: 'Indiranagar HQ', badgeColor: Colors.grey.shade100, badgeTextColor: Colors.grey.shade600),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                child: const Text('Lead strength & conditioning director at Indiranagar location.', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 32),

              // Notifications
              const Text('Notification & Privacy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Text('Select operational updates dispatched to your registered devices.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 16),
              _buildNotificationToggle(Iconsax.receipt, 'Punch confirmation alerts', 'Instant receipt on geotagged shifts', true, Colors.orange.shade50),
              const SizedBox(height: 12),
              _buildNotificationToggle(Iconsax.user_add, 'Join request alerts', 'Real-time alerts for prospective team addit...', true, Colors.orange.shade50),
              const SizedBox(height: 12),
              _buildNotificationToggle(Iconsax.clock, 'Shift & schedule updates', 'Roster swaps and time-slot revisions', true, Colors.orange.shade50),
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
                    label: const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 0),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Discard Changes', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required String badge, required Color badgeColor, required Color badgeTextColor}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
          child: Text(badge, style: TextStyle(fontSize: 9, color: badgeTextColor, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    );
  }

  Widget _buildTextField(String value, IconData icon) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildTextFieldNoIcon(String value) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildTextFieldWithBadge(String value, IconData icon, String badgeText, Color badgeBg, Color badgeColor) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: badgeColor.withOpacity(0.3))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.verify, size: 12, color: badgeColor),
                const SizedBox(width: 4),
                Text(badgeText, style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildNotificationToggle(IconData icon, String title, String subtitle, bool value, Color iconBg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.orange.shade800, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Checkbox(
            value: value,
            onChanged: (v) {},
            activeColor: Colors.orange.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }
}

