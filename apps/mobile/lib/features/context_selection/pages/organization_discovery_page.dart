import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/branch_repository.dart';
import '../models/branch_discovery_model.dart';

class OrganizationDiscoveryPage extends StatefulWidget {
  const OrganizationDiscoveryPage({super.key});

  @override
  State<OrganizationDiscoveryPage> createState() =>
      _OrganizationDiscoveryPageState();
}

class _OrganizationDiscoveryPageState extends State<OrganizationDiscoveryPage> {
  final _searchController = TextEditingController();
  late final BranchRepository _repository;
  List<BranchDiscoveryModel> _locations = [];
  bool _isLoading = false;
  int _selectedFilter = 0;
  final List<String> _filters = const [
    'Near You',
    'Popular',
    'Fitness & Gyms',
    'Corporate'
  ];

  @override
  void initState() {
    super.initState();
    _repository = context.read<BranchRepository>();
    _search();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    try {
      final results =
          await _repository.discoverBranches(query: _searchController.text);
      setState(() => _locations = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ignore: unused_element
  Future<void> _joinBranch(BranchDiscoveryModel location) async {
    try {
      await _repository.joinBranch(location.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Join request sent!')));
        context.go('/pending-join');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<BranchDiscoveryModel>> grouped = {};
    for (final loc in _locations) {
      grouped.putIfAbsent(loc.organizationId, () => []).add(loc);
    }
    final orgList = grouped.entries.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DAILIO MULTI-TENANT',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0)),
            Text('Explore Tenants',
                style: TextStyle(
                    fontSize: 22,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
          ],
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/logo.png'),
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.help_outline, color: Color(0xFF4B5563)),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.notifications_none,
                  color: Color(0xFF4B5563)),
              onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Location banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.near_me_outlined,
                    size: 20, color: Color(0xFF92400E)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detected Location',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500)),
                      Text('Indiranagar, Bengaluru',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A))),
                    ],
                  ),
                ),
                Row(
                  children: const [
                    Text('Change',
                        style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Icon(Icons.keyboard_arrow_down,
                        size: 16, color: Color(0xFF92400E)),
                  ],
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search orgs, tags, or cities...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(height: 16),
          // Filter chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedFilter;
                return ActionChip(
                  label: Text(_filters[index],
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w500)),
                  backgroundColor:
                      isSelected ? const Color(0xFF3D1F00) : Colors.white,
                  side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : const Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  onPressed: () => setState(() => _selectedFilter = index),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                    child: Text('Premier Organizations',
                        style: TextStyle(
                            fontSize: 22,
                            letterSpacing: -0.5,
                            fontWeight: FontWeight.bold))),
                Text('${orgList.length} Active   Radius < 8km',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Org cards
          Expanded(
            child: _isLoading
                ? ShimmerLoader.list()
                : orgList.isEmpty
                    ? const Center(child: Text('No organizations found'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: orgList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final orgEntry = orgList[index];
                          final locs = orgEntry.value;
                          final orgName = locs.first.organization.name;
                          // Alternate button style like mockup
                          final isPrimary = index % 2 == 0;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFFE5E7EB)),
                                        ),
                                        child: const Icon(Iconsax.building,
                                            color: Color(0xFF9CA3AF), size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(orgName,
                                                      style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.verified,
                                                    size: 16,
                                                    color: Color(0xFFB45309)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                // Rating Pill
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFFEF3C7),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4)),
                                                  child: Row(
                                                    children: const [
                                                      Icon(Icons.star_outline,
                                                          size: 12,
                                                          color: Color(
                                                              0xFFB45309)),
                                                      SizedBox(width: 2),
                                                      Text('4.9',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                  0xFF1A1A1A))),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Location
                                                const Icon(
                                                    Icons.location_on_outlined,
                                                    size: 12,
                                                    color: Color(0xFF9CA3AF)),
                                                const SizedBox(width: 2),
                                                const Text('100ft Rd  1.2 km',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Color(0xFF6B7280))),
                                                const SizedBox(width: 8),
                                                // Branches Pill
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFEFF6FF),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4)),
                                                  child: Text(
                                                      '${locs.length} Branch${locs.length > 1 ? 'es' : ''}',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(
                                                              0xFF1E40AF))),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      // Accepting requests pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Row(
                                          children: [
                                            Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                    color: Color(0xFF16A34A),
                                                    shape: BoxShape.circle)),
                                            const SizedBox(width: 4),
                                            const Text(
                                                'Accepting Join Requests',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF16A34A),
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      const Text('Est. 2019',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF9CA3AF),
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 40,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: isPrimary
                                            ? const Color(0xFF92400E)
                                            : const Color(0xFFE0E7FF),
                                        foregroundColor: isPrimary
                                            ? Colors.white
                                            : const Color(0xFF1E40AF),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => context.push(
                                          '/org-detail/${orgEntry.key}',
                                          extra: orgEntry.value),
                                      child: const Text('View Org & Branches ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Bottom Create Banner (matching mockup)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB45309),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Iconsax.building,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Looking to set up your own organizati...',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A))),
                          SizedBox(height: 2),
                          Text(
                              'Manage branches, schedules, and audit punch-ins seamlessly.',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF4B5563))),
                        ],
                      ),
                    ),
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
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => context.push('/create-gym'),
                    child: const Text('Create an Organization ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
/*      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (i) => setState(() => _bottomNavIndex = i),
        selectedItemColor: const Color(0xFF3D1F00),
        unselectedItemColor: const Color(0xFF9CA3AF),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view), label: 'Workspace'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),*/
    );
  }
}

