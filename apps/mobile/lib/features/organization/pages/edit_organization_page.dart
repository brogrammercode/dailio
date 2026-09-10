import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class EditOrganizationPage extends StatelessWidget {
  const EditOrganizationPage({super.key});

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
                        Text('Edit Organization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Update organization legal identity, fiscal preferences & branches', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Audit Trail Pill
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                      child: const Icon(Iconsax.shield_tick, color: Colors.green, size: 16),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AUDIT TRAIL ACTIVE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text('Auto-synced 2 mins ago across 3 branches', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Healthy', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tabs
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.building_3, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Org Details', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.shop, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Branches & Locations\n(3)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Emblem
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Club Emblem', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('PNG, SVG or WEBP up to 2MB', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Iconsax.verify, size: 12, color: Colors.green),
                              SizedBox(width: 4),
                              Text('512 x 512 Retina ready', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                            ],
                          )
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Iconsax.cloud_plus, size: 14),
                      label: const Text('Replace', style: TextStyle(color: Colors.black)),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form
              _buildFormSection(
                title: 'Organization Legal / Brand Name',
                badge: 'REQUIRED',
                badgeColor: Colors.orange.shade50,
                badgeTextColor: Colors.orange,
                child: _buildTextField('Resolution Fitness Club', Iconsax.building_4),
              ),
              _buildFormSection(
                title: 'Public Workspace URL',
                badge: 'Verified & Claimed',
                badgeIcon: Iconsax.verify,
                badgeColor: Colors.green.shade50,
                badgeTextColor: Colors.green,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: const Row(
                        children: [
                          Text('dailio.app/', style: TextStyle(color: Colors.grey)),
                          Text('resolution-fit', style: TextStyle(fontWeight: FontWeight.bold)),
                          Spacer(),
                          Icon(Iconsax.verify, color: Colors.green, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Used for member invites, QR punch terminals & geofence access.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              _buildFormSection(
                title: 'Official Contact Email',
                child: _buildTextField('admin@resolutionfit.com', Iconsax.sms),
              ),
              _buildFormSection(
                title: 'Official Contact Phone',
                child: _buildTextField('+91 98765 43210', Iconsax.call),
              ),
              _buildFormSection(
                title: 'Default Currency',
                child: _buildDropdownField('? INR - Indian Rupee (?)', Iconsax.money_2),
              ),
              _buildFormSection(
                title: 'Default Timezone',
                child: _buildDropdownField('Asia/Kolkata (IST +05:30)', Iconsax.clock),
              ),
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
                    label: const Text('Update Organization Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFormSection({required String title, String? badge, Color? badgeColor, Color? badgeTextColor, IconData? badgeIcon, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      if (badgeIcon != null) ...[Icon(badgeIcon, size: 10, color: badgeTextColor), const SizedBox(width: 4)],
                      Text(badge, style: TextStyle(fontSize: 9, color: badgeTextColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
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

  Widget _buildDropdownField(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
          const Icon(Iconsax.arrow_down_1, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}

