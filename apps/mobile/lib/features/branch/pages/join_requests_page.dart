import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
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
  String? _actionRequestId;

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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await _repository.getPendingRequests(branchId);
      if (!mounted) return;
      setState(() => _requests = results);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is DioException &&
                error.response?.statusCode == 403
            ? 'You do not have permission to view join requests for this branch.'
            : 'We could not load join requests. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAction(JoinRequestModel request, bool approve) async {
    if (_actionRequestId != null) return;

    final name = request.user?.name.trim().isNotEmpty == true
        ? request.user!.name
        : 'this person';
    final confirmed = await showConfirmDialog(
      context,
      title: approve ? 'Approve request?' : 'Reject request?',
      message: approve
          ? '$name will become an active member of this branch.'
          : 'The join request from $name will be removed from the pending list.',
      confirmLabel: approve ? 'Approve' : 'Reject',
      isDestructive: !approve,
      icon: approve ? Iconsax.tick_circle : Iconsax.close_circle,
    );

    if (confirmed == true) {
      await _handleAction(request.id, approve);
    }
  }

  Future<void> _handleAction(String requestId, bool approve) async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null || branchId.isEmpty) return;

    setState(() => _actionRequestId = requestId);
    try {
      if (approve) {
        await _repository.approveRequest(branchId, requestId);
      } else {
        await _repository.rejectRequest(branchId, requestId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(approve
                  ? 'Member approved successfully.'
                  : 'Join request rejected.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      await _loadRequests();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is DioException && error.response?.statusCode == 403
                  ? 'You do not have permission to update this request.'
                  : 'We could not update this request. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _actionRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => Navigator.maybePop(context),
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh requests',
          ),
        ],
        onMenuSelected: (_) => _loadRequests(),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummary(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join requests',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDark)),
                SizedBox(height: 3),
                Text('Review people waiting to join this branch.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF858585))),
              ],
            ),
          ),
          if (!_isLoading && _errorMessage == null)
            _CountBadge(count: _requests.length),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return ShimmerLoader.compactList();

    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadRequests);
    }

    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 130),
            _EmptyJoinRequestsState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final request = _requests[index];
          final displayName = request.user?.name.trim() ?? '';
          final title = displayName.isEmpty ? 'Unknown user' : displayName;
          final subtitle = request.message?.trim().isNotEmpty == true
              ? request.message!.trim()
              : request.user?.email ?? 'Membership request';
          final actionInProgress = _actionRequestId == request.id;

          return Opacity(
            opacity: actionInProgress ? 0.55 : 1,
            child: DailioCompactTile(
              avatar: _RequestAvatar(
                name: title,
                isUpdating: actionInProgress,
              ),
              onAvatarTap: () => showDailioMemberProfileSheet(
                context,
                DailioMemberPreview(
                  memberId: '',
                  name: title,
                  role: 'Member',
                  status: request.status,
                  phone: request.user?.phone,
                  email: request.user?.email,
                ),
              ),
              title: title,
              titleBadge: 'Member',
              statusBadge: 'Pending',
              statusBadgeColor: AppColors.warning,
              subtitle: actionInProgress ? 'Updating request…' : subtitle,
              trailing: 'New request',
              menuItems: const [
                DailioMenuItem(
                  value: 'approve',
                  icon: Iconsax.tick_circle,
                  label: 'Approve request',
                ),
                DailioMenuItem(
                  value: 'reject',
                  icon: Iconsax.close_circle,
                  label: 'Reject request',
                ),
              ],
              onMenuSelected: (value) => _confirmAction(
                request,
                value == 'approve',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$count pending',
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RequestAvatar extends StatelessWidget {
  const _RequestAvatar({required this.name, required this.isUpdating});

  final String name;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: const Color(0xFFFFF7ED),
          foregroundColor: AppColors.brandAccent,
          child: Text(initial,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: isUpdating ? AppColors.warning : AppColors.brandAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              isUpdating ? Iconsax.refresh : Iconsax.clock,
              color: Colors.white,
              size: 8,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyJoinRequestsState extends StatelessWidget {
  const _EmptyJoinRequestsState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Iconsax.user_search, size: 42, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        const Text('No pending requests',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text('New member requests will appear here.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.warning_2, size: 42, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Iconsax.refresh, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
