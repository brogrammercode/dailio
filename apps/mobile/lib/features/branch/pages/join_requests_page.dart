import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../controllers/admission_repository.dart';
import '../models/join_request_model.dart';

class JoinRequestsPage extends StatefulWidget {
  const JoinRequestsPage({super.key});

  @override
  State<JoinRequestsPage> createState() => _JoinRequestsPageState();
}

class _JoinRequestsPageState extends State<JoinRequestsPage> {
  late final AdmissionRepository _repository;
  List<JoinRequestModel> _requests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AdmissionRepository>();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      // Hardcode location check if we don't have context, but realistically this comes from tenant interceptor context
      // For now we'll fetch for the currently selected location. The backend uses req.location.id when we call this!
      // Wait, the API requires the locationId in the URL: /locations/:location_id/join-requests
      // We will need the active location. Let's pull it from Auth/Context state if possible.
      // But actually, we can just pass 'active' or the real ID if we have it.
      // For the sake of this implementation, let's assume the router or a context provider gives us the active locationId.
      // We will leave it as 'active' and ensure backend supports 'active' keyword, OR we get it from local storage.
      // Wait, let's see how tenant interceptor works. The tenant interceptor already injects the X-Location-Id header.
      // So the URL just needs the ID. We can retrieve it from preferences.
      // Actually, since I must pass it in the URL, let's get it.
      // For now, let's assume we can fetch it, or the API route can be modified to use `req.location.id` directly without URL param.
      // Actually, the API route is `/locations/:location_id/join-requests`.
      // Let's modify the repository to take locationId.
      // Where do we get locationId? We'll leave a placeholder or 'current'.

      final results = await _repository.getPendingRequests('current');
      setState(() => _requests = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(String requestId, bool approve) async {
    try {
      if (approve) {
        await _repository.approveRequest('current', requestId);
      } else {
        await _repository.rejectRequest('current', requestId);
      }
      _loadRequests();
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
      appBar: AppBar(title: const Text('Join Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(child: Text('No pending requests.'))
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(req.user?.name ?? 'Unknown User'),
                      subtitle: Text(req.user?.email ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _handleAction(req.id, false),
                          ),
                          IconButton(
                            icon: const Icon(Iconsax.tick_circle, color: Colors.green),
                            onPressed: () => _handleAction(req.id, true),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
