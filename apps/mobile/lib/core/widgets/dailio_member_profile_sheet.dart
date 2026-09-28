import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../router/route_names.dart';
import '../storage/preferences_storage.dart';
import '../theme/app_colors.dart';

/// The minimum member information needed to open the WhatsApp-style profile
/// actions sheet. Keeping this separate from a feature model makes the sheet
/// reusable from attendance, fees, payments and directory surfaces.
class DailioMemberPreview {
  final String memberId;
  final String name;
  final String role;
  final String status;
  final String? avatarUrl;
  final String? phone;
  final String? email;
  final String? membershipNumber;
  final String? subscriptionLabel;

  const DailioMemberPreview({
    required this.memberId,
    required this.name,
    this.role = 'Member',
    this.status = 'ACTIVE',
    this.avatarUrl,
    this.phone,
    this.email,
    this.membershipNumber,
    this.subscriptionLabel,
  });
}

Future<void> showDailioMemberProfileSheet(
  BuildContext context,
  DailioMemberPreview member,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _DailioMemberProfileSheet(
      member: member,
      parentContext: context,
    ),
  );
}

class _DailioMemberProfileSheet extends StatelessWidget {
  final DailioMemberPreview member;
  final BuildContext parentContext;

  const _DailioMemberProfileSheet({
    required this.member,
    required this.parentContext,
  });

  bool get _hasPhone => member.phone?.trim().isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    final preferences = parentContext.read<PreferencesStorage>();
    final canOpenInfo = member.memberId.isNotEmpty &&
        preferences.hasPermission('MEMBER_READ_ALL');
    final statusColor = _statusColor(member.status);

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7D7D7),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _avatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name.trim().isEmpty ? 'Member' : member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.brandDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _badge(member.role, AppColors.brandAccent),
                            const SizedBox(width: 6),
                            _badge(_pretty(member.status), statusColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Iconsax.close_circle, size: 22),
                    color: AppColors.brandDark,
                  ),
                ],
              ),
              if (member.subscriptionLabel != null &&
                  member.subscriptionLabel!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _metaRow(Iconsax.card, member.subscriptionLabel!),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _action(
                      context,
                      icon: Iconsax.call,
                      label: 'Call',
                      enabled: _hasPhone,
                      onPressed: _call,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _action(
                      context,
                      icon: Iconsax.info_circle,
                      label: 'Info',
                      enabled: canOpenInfo,
                      onPressed: canOpenInfo
                          ? () {
                              Navigator.of(context).pop();
                              parentContext.push(AppRoutes.memberDetail
                                  .replaceAll(':memberId', member.memberId));
                            }
                          : null,
                    ),
                  ),
                ],
              ),
              if (!_hasPhone || !canOpenInfo) ...[
                const SizedBox(height: 10),
                Text(
                  !_hasPhone
                      ? 'No phone number is available for this member.'
                      : 'Member details require member directory permission.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    final hasImage = member.avatarUrl?.trim().isNotEmpty == true;
    final initials = member.name.trim().isEmpty
        ? '?'
        : member.name.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 29,
      backgroundColor: AppColors.brandAccent.withValues(alpha: 0.12),
      backgroundImage: hasImage ? NetworkImage(member.avatarUrl!) : null,
      child: hasImage
          ? null
          : Text(
              initials,
              style: const TextStyle(
                color: AppColors.brandAccent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _metaRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brandAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.brandDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback? onPressed,
  }) {
    final color = enabled ? AppColors.brandDark : const Color(0xFFAAAAAA);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
            color: enabled ? const Color(0xFFE1D6CB) : const Color(0xFFEAEAEA)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _call() async {
    if (!_hasPhone) return;
    final uri = Uri(scheme: 'tel', path: member.phone!.trim());
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && parentContext.mounted) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone app.')),
      );
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppColors.success;
      case 'SUSPENDED':
        return AppColors.warning;
      case 'INACTIVE':
      case 'DEACTIVATED':
        return AppColors.error;
      default:
        return AppColors.brandAccent;
    }
  }

  String _pretty(String value) {
    final normalized = value.replaceAll('_', ' ').toLowerCase();
    return normalized.isEmpty
        ? value
        : '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }
}
