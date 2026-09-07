import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/storage/preferences_storage.dart';
import '../controllers/members_repository.dart';
import '../models/member_model.dart';

class MemberDetailPage extends StatefulWidget {
  final String membershipId;

  const MemberDetailPage({super.key, required this.membershipId});

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  late final MembersRepository _repository;
  late final String _locationId;
  
  MemberModel? _member;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MembersRepository>();
    _locationId = context.read<PreferencesStorage>().activeBranchId!;
    _loadMember();
  }

  Future<void> _loadMember() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _repository.getMember(_locationId, widget.membershipId);
      final memberMap = result['member'] as Map<String, dynamic>;
      setState(() {
        _member = MemberModel.fromJson(memberMap);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performAction(String action) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action == 'suspend' ? 'Suspend' : 'Deactivate'} Member'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            }, 
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        if (action == 'suspend') {
          await _repository.suspendMember(_locationId, widget.membershipId, reasonController.text.trim());
        } else {
          await _repository.deactivateMember(_locationId, widget.membershipId, reasonController.text.trim());
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action successful')));
        }
        await _loadMember();
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Member Detail')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text('Error: $_error'))
          : _member == null
            ? const Center(child: Text('Member not found'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      child: Text(_member!.firstName.isNotEmpty ? _member!.firstName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(height: 16),
                    Text('${_member!.fullName} (${_member!.membershipNumber})', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Chip(label: Text(_member!.status)),
                    if (_member!.email != null && _member!.email!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_member!.email!, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Roles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    ..._member!.roles.map((r) => ListTile(title: Text(r.name), leading: const Icon(Icons.badge))),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => _performAction('suspend'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text('Suspend'),
                        ),
                        ElevatedButton(
                          onPressed: () => _performAction('deactivate'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Deactivate'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
    );
  }
}
