import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../router/route_names.dart';
import '../storage/preferences_storage.dart';
import 'dailio_streak_card.dart';
import '../../features/attendance/controllers/streak_repository.dart';

/// The minimum member information needed by the shared profile surface.
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

/// Opens the app-wide profile surface used anywhere a member avatar is tapped.
Future<void> showDailioMemberProfileSheet(
  BuildContext context,
  DailioMemberPreview member,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close profile',
    barrierColor: const Color(0xCC000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => _DailioMemberProfileSurface(
      member: member,
      parentContext: context,
    ),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _DailioMemberProfileSurface extends StatelessWidget {
  final DailioMemberPreview member;
  final BuildContext parentContext;

  const _DailioMemberProfileSurface({
    required this.member,
    required this.parentContext,
  });

  bool get _hasPhone => member.phone?.trim().isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final avatarSize = (size.width * 0.64).clamp(210.0, 330.0);
    return Material(
      color: const Color(0xFF0B0E12),
      child: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _zoomableAvatar(avatarSize),
                    const SizedBox(height: 30),
                    Text(
                      member.name.trim().isEmpty ? 'Member' : member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_pretty(member.role)} · ${_pretty(member.status)}',
                      style: const TextStyle(
                        color: Color(0xFFA7ADB5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _primaryActions(context),
                    const SizedBox(height: 20),
                    _secondaryActions(context),
                    _streakCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Iconsax.arrow_left_2, color: Color(0xFFE9ECEF)),
          ),
          Expanded(
            child: Text(
              member.name.trim().isEmpty ? 'Member' : member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFDDE1E5),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.of(context).pop();
              parentContext.push(AppRoutes.notifications);
            },
            icon: const Icon(Iconsax.notification, color: Color(0xFF9BA2AA)),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: () => _showMore(context),
            icon: const Icon(Iconsax.more, color: Color(0xFF9BA2AA)),
          ),
        ],
      ),
    );
  }

  Widget _zoomableAvatar(double size) {
    final hasImage = member.avatarUrl?.trim().isNotEmpty == true;
    final initials = member.name.trim().isEmpty
        ? '?'
        : member.name.trim().substring(0, 1).toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(80),
          child: hasImage
              ? Image.network(
                  member.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _initialsAvatar(initials),
                )
              : _initialsAvatar(initials),
        ),
      ),
    );
  }

  Widget _initialsAvatar(String initials) {
    return ColoredBox(
      color: const Color(0xFF242A31),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _primaryActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _profileAction(
          icon: Iconsax.message,
          label: 'WhatsApp',
          enabled: _hasPhone,
          onTap: _openWhatsApp,
        ),
        _profileAction(
          icon: Iconsax.share,
          label: 'Share profile',
          onTap: _shareProfile,
        ),
        _profileAction(
          icon: Iconsax.copy,
          label: 'Copy link',
          onTap: _copyProfileLink,
        ),
        _profileAction(
          icon: Iconsax.scan_barcode,
          label: 'QR code',
          onTap: () => _showQr(context),
        ),
      ],
    );
  }

  Widget _secondaryActions(BuildContext context) {
    final canOpenInfo = member.memberId.isNotEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _subtleAction(
          icon: Iconsax.call,
          label: 'Call',
          enabled: _hasPhone,
          onTap: _call,
        ),
        const SizedBox(width: 10),
        _subtleAction(
          icon: Iconsax.info_circle,
          label: 'Info',
          enabled: canOpenInfo,
          onTap: canOpenInfo
              ? () {
                  Navigator.of(context).pop();
                  parentContext.push(
                    AppRoutes.memberDetail.replaceAll(
                      ':memberId',
                      member.memberId,
                    ),
                  );
                }
              : null,
        ),
      ],
    );
  }

  Widget _streakCard() {
    final preferences = parentContext.read<PreferencesStorage>();
    final branchId = preferences.activeBranchId;
    if (branchId == null) return const SizedBox.shrink();
    return DailioStreakCard(
      dark: true,
      future: parentContext.read<StreakRepository>().getMemberStreak(
            branchId,
            member.memberId,
          ),
    );
  }

  Widget _profileAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final color = enabled ? const Color(0xFFE5E8EB) : const Color(0xFF626970);
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF343A42)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subtleAction({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor:
            enabled ? const Color(0xFFDDE1E5) : const Color(0xFF626970),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final phone = _whatsAppPhone(member.phone);
    if (phone == null) return;
    final uri = Uri.parse('https://wa.me/$phone');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && parentContext.mounted) {
      _message('Unable to open WhatsApp.');
    }
  }

  Future<void> _call() async {
    if (!_hasPhone) return;
    final uri = Uri(scheme: 'tel', path: member.phone!.trim());
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && parentContext.mounted) {
      _message('Unable to open the phone app.');
    }
  }

  Future<void> _shareProfile() async {
    final identity = member.membershipNumber?.trim().isNotEmpty == true
        ? member.membershipNumber!.trim()
        : member.memberId;
    await Share.share(
        'Dailio member profile: ${member.name}\nMember ID: $identity');
  }

  Future<void> _copyProfileLink() async {
    await Clipboard.setData(
      ClipboardData(text: 'dailio://member/${member.memberId}'),
    );
    if (parentContext.mounted) _message('Profile link copied.');
  }

  void _showQr(BuildContext context) {
    final identity = member.membershipNumber?.trim().isNotEmpty == true
        ? member.membershipNumber!.trim()
        : member.memberId;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(member.name),
        content: QrImageView(
          data: 'dailio://member/$identity',
          size: 220,
          errorCorrectionLevel: QrErrorCorrectLevel.H,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171B20),
      builder: (_) => SafeArea(
        child: ListTile(
          leading: const Icon(Iconsax.close_circle, color: Colors.white70),
          title: const Text('Close profile',
              style: TextStyle(color: Colors.white)),
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(parentContext)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  String? _whatsAppPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length == 10) digits = '91$digits';
    return digits.length >= 10 ? digits : null;
  }

  String _pretty(String value) {
    final normalized = value.replaceAll('_', ' ').toLowerCase();
    return normalized.isEmpty
        ? value
        : '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }
}
