import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/shimmer_loader.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AdmissionRepository>();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null || branchId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _requests = [];
        _errorMessage = 'Select an active branch to view join requests.';
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await _repository.getPendingRequests(branchId);
      if (!mounted) return;
      setState(() {
        _requests = results;
        _errorMessage = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error is DioException &&
                  error.response?.statusCode == 403
              ? 'You do not have permission to view join requests for this branch.'
              : 'We could not load join requests. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(String requestId, bool approve) async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null || branchId.isEmpty) return;

    try {
      if (approve) {
        await _repository.approveRequest(branchId, requestId);
      } else {
        await _repository.rejectRequest(branchId, requestId);
      }
      await _loadRequests();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is DioException && error.response?.statusCode == 403
                  ? 'You do not have permission to update this request.'
                  : 'We could not update this request. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Requests')),
      body: _isLoading
          ? ShimmerLoader.list()
          : _errorMessage != null
              ? _ErrorState(
                  message: _errorMessage!,
                  onRetry: _loadRequests,
                )
              : _requests.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          _EmptyJoinRequestsState(),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final req = _requests[index];
                          final displayName = req.user?.name.trim() ?? '';
                          final initial = displayName.isEmpty
                              ? 'U'
                              : displayName.substring(0, 1).toUpperCase();
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFFFF7ED),
                              foregroundColor: const Color(0xFFB45309),
                              child: Text(initial),
                            ),
                            title: Text(
                              req.user?.name ?? 'Unknown User',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle:
                                Text(req.user?.email ?? 'No email available'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Reject request',
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () => _handleAction(req.id, false),
                                ),
                                IconButton(
                                  tooltip: 'Approve request',
                                  icon: const Icon(Iconsax.tick_circle,
                                      color: Colors.green),
                                  onPressed: () => _handleAction(req.id, true),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _EmptyJoinRequestsState extends StatelessWidget {
  const _EmptyJoinRequestsState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.group_outlined, size: 52, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        const Text(
          'No pending requests',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'New member requests will appear here.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
