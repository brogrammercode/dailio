import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../controllers/location_repository.dart';
import '../models/location_discovery_model.dart';

class OrganizationDiscoveryPage extends StatefulWidget {
  const OrganizationDiscoveryPage({super.key});

  @override
  State<OrganizationDiscoveryPage> createState() =>
      _OrganizationDiscoveryPageState();
}

class _OrganizationDiscoveryPageState extends State<OrganizationDiscoveryPage> {
  final _searchController = TextEditingController();
  late final LocationRepository _repository;
  List<LocationDiscoveryModel> _locations = [];
  bool _isLoading = false;
  int _selectedFilter = 0;
  final List<String> _filters = const ['Near You', 'Popular', 'Fitness & Gyms', 'Corporate'];
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository = context.read<LocationRepository>();
    _search();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    try {
      final results = await _repository.discoverLocations(query: _searchController.text);
      setState(() => _locations = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ignore: unused_element
  Future<void> _joinLocation(LocationDiscoveryModel location) async {
    try {
      await _repository.joinLocation(location.id);
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
    final Map<String, List<LocationDiscoveryModel>> grouped = {};
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
            Text('DAILIO MULTI-TENANT', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            Text('Explore Tenants', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          ],
        ),
        leading: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF3D1F00), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Location banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.explore, size: 18, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                const Expanded(child: Text('San Francisco, CA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                Text('Change', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
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
                  label: Text(_filters[index], style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1A1A1A), fontWeight: FontWeight.w500)),
                  backgroundColor: isSelected ? const Color(0xFF3D1F00) : Colors.white,
                  side: BorderSide(color: isSelected ? Colors.transparent : const Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                const Expanded(child: Text('Premier Organizations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Text('${orgList.length} Active   Radius < 8km', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Org cards
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : orgList.isEmpty
                    ? const Center(child: Text('No organizations found'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: orgList.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final orgEntry = orgList[index];
                          final locs = orgEntry.value;
                          final orgName = locs.first.organization.name;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 60, height: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.business, color: Color(0xFF9CA3AF), size: 32),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(orgName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                                                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            const Row(
                                              children: [
                                                Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                                                SizedBox(width: 4),
                                                Text('4.9', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                                SizedBox(width: 8),
                                                Text('•  2.5 km away', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                                              child: Text('${locs.length} Branch${locs.length > 1 ? 'es' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      const Text('Accepting Join Requests', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                      const Spacer(),
                                      const Text('Est. 2019', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3D1F00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      onPressed: () => context.push('/org-detail/${orgEntry.key}', extra: orgEntry.value),
                                      child: const Text('View Org & Branches →', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Bottom Create Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFFEF3C7),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFB45309).withAlpha(30), shape: BoxShape.circle),
                  child: const Icon(Icons.add_business, color: Color(0xFFB45309), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Own a facility?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                      Text('Set up your workspace in minutes', style: TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/create-gym'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFB45309), backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Create an Organization 🚀', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (i) => setState(() => _bottomNavIndex = i),
        selectedItemColor: const Color(0xFF3D1F00),
        unselectedItemColor: const Color(0xFF9CA3AF),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Workspace'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),
    );
  }
}
