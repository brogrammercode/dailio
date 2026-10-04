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
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      final results = await _repository.getPendingRequests(
        branchId,
        onFresh: (freshRequests) {
          if (mounted) setState(() => _requests = freshRequests);
        },
      );
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
      padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 8.r),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join requests',
                    style: TextStyle(
                        fontSize: 18.r,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDark)),
                SizedBox(height: 3.r),
                Text('Review people waiting to join this branch.',
                    style: TextStyle(fontSize: 12.r, color: Color(0xFF858585))),
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
          children: [
            SizedBox(height: 130.r),
            _EmptyJoinRequestsState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: EdgeInsets.only(top: 8.r, bottom: 28.r),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.r),
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
      padding: EdgeInsets.symmetric(horizontal: 9.r, vertical: 5.r),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7.r),
      ),
      child: Text(
        '$count pending',
        style: TextStyle(
          color: AppColors.warning,
          fontSize: 10.r,
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
          radius: 23.r,
          backgroundColor: const Color(0xFFFFF7ED),
          foregroundColor: AppColors.brandAccent,
          child: Text(initial,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Positioned(
          right: (-1).r,
          bottom: (-1).r,
          child: Container(
            width: 15.r,
            height: 15.r,
            decoration: BoxDecoration(
              color: isUpdating ? AppColors.warning : AppColors.brandAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.r),
            ),
            child: Icon(
              isUpdating ? Iconsax.refresh : Iconsax.clock,
              color: Colors.white,
              size: 8.r,
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
        Icon(Iconsax.user_search, size: 42.r, color: Colors.grey.shade400),
        SizedBox(height: 12.r),
        Text('No pending requests',
            style: TextStyle(fontSize: 16.r, fontWeight: FontWeight.w700)),
        SizedBox(height: 5.r),
        Text('New member requests will appear here.',
            style: TextStyle(fontSize: 12.r, color: Colors.grey.shade600)),
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
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.warning_2, size: 42.r, color: Colors.grey.shade500),
            SizedBox(height: 12.r),
            Text(message,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13.r)),
            SizedBox(height: 14.r),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: Icon(Iconsax.refresh, size: 16.r),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
