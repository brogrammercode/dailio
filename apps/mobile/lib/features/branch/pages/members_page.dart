import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/preferences_storage.dart';
import '../controllers/members_repository.dart';
import '../models/member_model.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late final MembersRepository _repository;
  late final String _locationId;
  
  List<MemberModel> _members = [];
  bool _isLoading = false;
  String? _error;
  
  final TextEditingController _searchController = TextEditingController();
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MembersRepository>();
    _locationId = context.read<PreferencesStorage>().activeBranchId!;
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _repository.listMembers(_locationId, search: _searchController.text, status: _statusFilter);
      final data = results['data'] as List? ?? [];
      setState(() {
        _members = data.map((e) => MemberModel.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showNewAdmissionModal() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController(text: '+91 ');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('New Admission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (firstNameController.text.trim().isEmpty) return;
                  Navigator.pop(modalContext);
                  setState(() => _isLoading = true);
                  try {
                    await _repository.createAssistedAdmission(
                      _locationId,
                      firstName: firstNameController.text.trim(),
                      lastName: lastNameController.text.trim(),
                      email: emailController.text.trim(),
                      phone: phoneController.text.trim(),
                    );
                    _loadMembers();
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Submit'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members Directory'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members...',
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loadMembers,
                ),
              ),
              onSubmitted: (_) => _loadMembers(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'ACTIVE'),
                const SizedBox(width: 8),
                _buildFilterChip('Suspended', 'SUSPENDED'),
                const SizedBox(width: 8),
                _buildFilterChip('Inactive', 'INACTIVE'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _members.isEmpty
                        ? const Center(child: Text('No members found.'))
                        : ListView.builder(
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              final member = _members[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(member.firstName.isNotEmpty ? member.firstName[0].toUpperCase() : '?'),
                                ),
                                title: Text('${member.fullName} (${member.membershipNumber})'),
                                subtitle: Text('${member.roles.map((r) => r.name).join(', ')} • ${member.status}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.go('/home/branch/members/${member.id}'),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewAdmissionModal,
        tooltip: 'New Admission',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _statusFilter == value,
      onSelected: (selected) {
        if (selected) {
          setState(() => _statusFilter = value);
          _loadMembers();
        }
      },
    );
  }
}

