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

  @override
  void initState() {
    super.initState();
    _repository = context.read<LocationRepository>();
    _search();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    try {
      final results =
          await _repository.discoverLocations(query: _searchController.text);
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

  Future<void> _joinLocation(LocationDiscoveryModel location) async {
    try {
      await _repository.joinLocation(location.id);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Find an Organization')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search organizations...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                )
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _locations.isEmpty
                    ? const Center(child: Text('No organizations found'))
                    : ListView.builder(
                        itemCount: _locations.length,
                        itemBuilder: (context, index) {
                          final loc = _locations[index];
                          return ListTile(
                            leading:
                                const CircleAvatar(child: Icon(Icons.business)),
                            title: Text(loc.organization.name),
                            subtitle: Text(loc.name),
                            trailing: ElevatedButton(
                              onPressed: () => _joinLocation(loc),
                              child: const Text('Join'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
