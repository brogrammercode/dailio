import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/branch_discovery_model.dart';
// Note: Replace this with the actual cubit or bloc you use for joining, if any.
// If not, we'll just show a snackbar.

class OrgDetailPage extends StatefulWidget {
  final List<BranchDiscoveryModel> locations;

  const OrgDetailPage({
    super.key,
    required this.locations,
  });

  @override
  State<OrgDetailPage> createState() => _OrgDetailPageState();
}

class _OrgDetailPageState extends State<OrgDetailPage> {
  void _joinBranch(BranchDiscoveryModel loc) async {
    // Just a placeholder since the backend integration will be done by another agent
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Join request sent successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locations.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tenant Details')),
        body: const Center(child: Text('No branches available')),
      );
    }
    final primaryLoc = widget.locations.first;
    final org = primaryLoc.organization;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Tenant Details',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A))),
        leading: IconButton(
            icon: const Icon(Iconsax.arrow_left, color: Color(0xFF1A1A1A)),
            onPressed: () => context.pop()),
        actions: [
          IconButton(
              icon: const Icon(Icons.help_outline, color: Color(0xFF4B5563)),
              onPressed: () {}),
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/logo.png', width: 32, height: 32),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Membership Pass Banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.verified_user_outlined,
                        color: Color(0xFF92400E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Single Membership Pass',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A))),
                        Text(
                            'Join a home facility to clock sessions and acc...',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  const Icon(Icons.info_outline,
                      size: 16, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),

            // Org Header Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB))),
                        child: const Icon(Iconsax.building,
                            color: Color(0xFF9CA3AF), size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                    child: Text(org.name,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 4),
                                const Icon(Iconsax.tick_circle,
                                    size: 14, color: Color(0xFF22C55E)),
                                const SizedBox(width: 2),
                                const Text('Verified',
                                    style: TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                                'Strength, Conditioning & Athletic Training',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 14, color: Color(0xFF9CA3AF)),
                                  SizedBox(width: 4),
                                  Text('HQ Location',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text('Indiranagar 100ft Rd',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF4B5563),
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 14, color: Color(0xFF9CA3AF)),
                                  SizedBox(width: 4),
                                  Text('Founded',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text('Est. 2019',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF4B5563),
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Team Roster Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6))),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.people,
                          color: Color(0xFF92400E), size: 20),
                      const SizedBox(width: 8),
                      const Text('Team & Member Roster',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Text('350+ Active',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFE2E8F0),
                          child: Icon(Icons.person, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Marcus Vance',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text('Organization Owner',
                                  style: TextStyle(
                                      color: Color(0xFFB45309), fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB))),
                          child: const Text('Lead',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      _StatBox(title: '2', subtitle: 'Managers'),
                      SizedBox(width: 12),
                      _StatBox(title: '8', subtitle: 'Trainers'),
                      SizedBox(width: 12),
                      _StatBox(title: '340+', subtitle: 'Gymrats'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Branches
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Select a Branch to Join',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                  const Spacer(),
                  Text('${widget.locations.length} available',
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.locations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final loc = widget.locations[index];
                final isFirst = index == 0;
                final capacity = isFirst ? 0.85 : 0.60;

                return Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFF3F4F6))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text(loc.name,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A)))),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                children: [
                                  Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                          color: Color(0xFF16A34A),
                                          shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  const Text('Open',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF16A34A))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.near_me_outlined,
                                size: 12, color: Color(0xFF6B7280)),
                            SizedBox(width: 4),
                            Text('1.2 km away  Flagship Center',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Floor Load Capacity',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4B5563))),
                            Text('${(capacity * 100).toInt()}% Busy',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: capacity,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFB45309)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _InfoPill(
                                icon: Icons.location_on_outlined,
                                text: 'Punch + Geofence Policy'),
                            _InfoPill(
                                icon: Icons.access_time,
                                text: '12 Active Shifts'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF92400E),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            onPressed: () => _joinBranch(loc),
                            child: const Text('Request to Join Branch ',
                                style: TextStyle(fontWeight: FontWeight.w600)),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 16, color: Color(0xFF9CA3AF)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Membership Policy & Security Note',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4B5563))),
                        SizedBox(height: 4),
                        Text(
                          'Branch transfer or assignment requires Owner/Admin review per location capacity and verification protocol. Approvals are typically finalized within 4 working hours.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
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
      decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w500)),
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
        decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF3F4F6))),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

