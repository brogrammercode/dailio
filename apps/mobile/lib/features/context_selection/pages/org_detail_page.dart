import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../models/location_discovery_model.dart';
import '../controllers/location_repository.dart';

class OrgDetailPage extends StatefulWidget {
  final List<LocationDiscoveryModel> locations;
  const OrgDetailPage({super.key, required this.locations});

  @override
  State<OrgDetailPage> createState() => _OrgDetailPageState();
}

class _OrgDetailPageState extends State<OrgDetailPage> {
  final List<double> _capacities = [0.85, 0.60, 0.40];
  final List<String> _statuses = ['Open', 'Moderate', 'Open Enrollment'];

  Future<void> _joinLocation(LocationDiscoveryModel location) async {
    try {
      final repository = context.read<LocationRepository>();
      await repository.joinLocation(location.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join request sent!')));
        context.go('/pending-join');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgName = widget.locations.isNotEmpty ? widget.locations.first.organization.name : 'Unknown Organization';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF3D1F00),
              child: Text('D', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Membership banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withAlpha(30), shape: BoxShape.circle),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Single Membership Pass', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                        SizedBox(height: 4),
                        Text('Join a home facility to clock sessions and access all branches.', style: TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Org header card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.business, size: 40, color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: Text(orgName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                                SizedBox(width: 4),
                                Text('Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Strength, Conditioning & Athletic Training', style: TextStyle(color: Color(0xFF6B7280)), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _InfoPill(icon: Icons.location_on_outlined, text: 'HQ: San Francisco'),
                          SizedBox(width: 12),
                          _InfoPill(icon: Icons.calendar_today_outlined, text: 'Est. 2019'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Team & Member Roster
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Team & Member Roster', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                        child: const Text('350+ Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE5E7EB), child: Icon(Icons.person, color: Color(0xFF9CA3AF))),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Alex Thompson', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Facility Director', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF3D1F00), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Lead', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      _StatBox(title: '2', subtitle: 'Managers'),
                      SizedBox(width: 12),
                      _StatBox(title: '8', subtitle: 'Trainers'),
                      SizedBox(width: 12),
                      _StatBox(title: '340+', subtitle: 'Members'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Branches
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Select a Branch to Join', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF3D1F00), borderRadius: BorderRadius.circular(12)),
                    child: Text('${widget.locations.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.locations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final loc = widget.locations[index];
                final capacity = _capacities[index % _capacities.length];
                final status = _statuses[index % _statuses.length];
                
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(loc.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'Open' ? const Color(0xFFDCFCE7) : status == 'Moderate' ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: status == 'Open' ? const Color(0xFF16A34A) : status == 'Moderate' ? const Color(0xFFD97706) : const Color(0xFF2563EB))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('1.2 km away • Flagship Center', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: capacity,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('${(capacity * 100).toInt()}% Busy', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                              child: const Text('Punch + Geofence Policy', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                              child: const Text('12 Active Shifts', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3D1F00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: () => _joinLocation(loc),
                            child: const Text('Request to Join Branch →', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Membership Policy & Security Note: All join requests are subject to approval by the facility administrator. Your location data is only accessed during clock-in.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StatBox({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF3F4F6))),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
