import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';
import '../../../core/notifications/notification_runtime.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_notification_button.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final ApiClient _api;
  late final JsonCacheStore _cache;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _markingAll = false;
  int _loadGeneration = 0;
  String? _error;
  final Map<String, String> _resolvedImages = {};

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _cache = context.read<JsonCacheStore>();
    NotificationRuntime.setInboxRefresh(_load);
    _load(markAllRead: true);
  }

  @override
  void dispose() {
    NotificationRuntime.setInboxRefresh(null);
    super.dispose();
  }

  Future<void> _load({bool markAllRead = false}) async {
    final loadGeneration = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _cache.load<List<Map<String, dynamic>>>(
        key: _cache.scopedKey('notifications'),
        scope: 'user',
        fetch: () async => (await _api.dio.get('/notifications')).data,
        decode: (payload) => ((payload as Map)['data'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
        onFresh: (freshItems) {
          if (loadGeneration != _loadGeneration || markAllRead) return;
          _updateUnreadCount(freshItems);
          if (mounted) setState(() => _items = freshItems);
          unawaited(_resolveRelatedImages(freshItems));
        },
      );
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
      _updateUnreadCount(_items);
      // The list is paginated; the server count is the source of truth for
      // the app-bar badge and avoids under-counting when more than one page
      // of notifications is unread.
      unawaited(NotificationBadgeController.refresh(_api));
      unawaited(_resolveRelatedImages(data));
      if (markAllRead && _items.any((item) => item['read_at'] == null)) {
        // Invalidate any cache refresh that was started before read-all. Its
        // response may still contain the unread rows we are about to clear.
        ++_loadGeneration;
        await _markAllRead();
        // The cached payload was read before the server-side read-all mutation.
        // Fetch once more so the page is immediately backed by the current inbox,
        // including notifications that arrived while it was opening.
        if (mounted) await _load();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
      _updateUnreadCount(_items);
      unawaited(NotificationBadgeController.refresh(_api));
    }
  }

  void _updateUnreadCount(List<Map<String, dynamic>> items) {
    NotificationBadgeController.setCount(
        items.where((item) => item['read_at'] == null).length);
  }

  Future<void> _markRead(int index) async {
    final item = _items[index];
    if (item['read_at'] != null) return;
    try {
      await _api.dio.patch('/notifications/${item['id']}/read');
      await _cache.clearKey(_cache.scopedKey('notifications'));
      if (mounted) {
        setState(() => _items[index] = {
              ...item,
              'read_at': DateTime.now().toIso8601String()
            });
      }
      _updateUnreadCount(_items);
    } catch (_) {
      // Keep the inbox usable if a read receipt is temporarily offline.
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _api.dio.post('/notifications/read-all');
      await _cache.clearKey(_cache.scopedKey('notifications'));
      if (mounted) {
        setState(() {
          _items = _items
              .map((item) =>
                  {...item, 'read_at': DateTime.now().toIso8601String()})
              .toList();
        });
      }
      NotificationBadgeController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark notifications read.')),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: const [
          DailioMenuItem(
            value: 'mark_all',
            icon: Iconsax.tick_square,
            label: 'Mark all as read',
          ),
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh',
          ),
        ],
        onMenuSelected: (value) {
          if (value == 'mark_all') _markAllRead();
          if (value == 'refresh') _load();
        },
      ),
      body: _loading
          ? const _NotificationSkeleton()
          : _error != null
              ? _NotificationMessage(
                  icon: Iconsax.cloud_cross,
                  message: 'Could not load notifications',
                  action: _load,
                )
              : _items.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.only(top: 170),
                        children: const [
                          _NotificationEmpty(),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) => _buildItem(index),
                      ),
                    ),
    );
  }

  Widget _buildItem(int index) {
    final item = _items[index];
    final data = _notificationMap(item['data']);
    final actor =
        _notificationMap(item['actor']) ?? _notificationMap(data?['actor']);
    final actorName = actor?['name']?.toString() ??
        data?['actor_name']?.toString() ??
        data?['actorName']?.toString();
    final actorAvatar = _imageUrl(actor?['avatar_url']) ??
        _imageUrl(actor?['avatarUrl']) ??
        _imageUrl(data?['actor_avatar_url']) ??
        _imageUrl(data?['actorAvatarUrl']);
    final actorMemberId = actor?['member_id']?.toString() ??
        actor?['memberId']?.toString() ??
        data?['actor_member_id']?.toString() ??
        data?['actorMemberId']?.toString();
    final relatedImage = _relatedImageUrl(item, data);
    final unread = item['read_at'] == null;
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return InkWell(
      onTap: () => _markRead(index),
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        decoration: BoxDecoration(
          color: unread ? const Color(0xFFFFF8F1) : Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationLeading(
              actorAvatar: actorAvatar,
              actorName: actorName,
              actorMemberId: actorMemberId,
              unread: unread,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? 'Notification',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (created != null)
                        Text(
                          DateFormat('dd MMM, hh:mm a')
                              .format(created.toLocal()),
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 10),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['body']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (relatedImage != null) ...[
              const SizedBox(width: 8),
              _NotificationImage(url: relatedImage),
            ],
            if (unread) ...[
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Icon(Iconsax.record_circle,
                    size: 10, color: AppColors.brandAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Map<String, dynamic>? _notificationMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _imageUrl(dynamic value) {
    final url = value?.toString().trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return url;
  }

  String? _relatedImageUrl(
      Map<String, dynamic> item, Map<String, dynamic>? data) {
    final cached = _resolvedImages[item['id']?.toString()];
    if (cached != null) return cached;
    final values = [
      item['image_url'],
      item['imageUrl'],
      item['thumbnail_url'],
      item['thumbnailUrl'],
      item['media_url'],
      item['mediaUrl'],
      data?['image_url'],
      data?['imageUrl'],
      data?['thumbnail_url'],
      data?['thumbnailUrl'],
      data?['media_url'],
      data?['mediaUrl'],
    ];
    for (final value in values) {
      final url = _imageUrl(value);
      if (url != null) return url;
    }
    return null;
  }

  Future<void> _resolveRelatedImages(List<Map<String, dynamic>> items) async {
    final requests = <Future<void>>[];
    for (final item in items) {
      final data = _notificationMap(item['data']);
      final storageKey = data?['media_storage_key']?.toString();
      final announcementId =
          data?['entity_id']?.toString() ?? item['entity_id']?.toString();
      final organizationId = data?['organization_id']?.toString();
      final itemId = item['id']?.toString();
      if (storageKey == null ||
          announcementId == null ||
          organizationId == null ||
          itemId == null ||
          _resolvedImages.containsKey(itemId)) {
        continue;
      }
      requests.add(() async {
        try {
          final response = await _api.dio.get(
            '/organizations/$organizationId/announcements/media-url',
            queryParameters: {
              'storage_key': storageKey,
              'announcement_id': announcementId,
            },
          );
          final url = _imageUrl(response.data['data']['url']);
          if (url != null) _resolvedImages[itemId] = url;
        } catch (_) {}
      }());
    }
    if (requests.isNotEmpty) {
      await Future.wait(requests);
      if (mounted) setState(() {});
    }
  }
}

class _NotificationLeading extends StatelessWidget {
  final String? actorAvatar;
  final String? actorName;
  final String? actorMemberId;
  final bool unread;

  const _NotificationLeading({
    required this.actorAvatar,
    required this.actorName,
    required this.actorMemberId,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackColor = unread
        ? AppColors.brandAccent.withValues(alpha: .12)
        : const Color(0xFFF4F4F4);
    final iconColor = unread ? AppColors.brandAccent : Colors.grey.shade600;
    final leading = SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (actorAvatar == null)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: fallbackColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                unread ? Iconsax.notification_bing : Iconsax.notification,
                size: 17,
                color: iconColor,
              ),
            )
          else
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: actorAvatar!,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 34,
                  height: 34,
                  color: fallbackColor,
                  child: Icon(Iconsax.user, size: 17, color: iconColor),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 34,
                  height: 34,
                  color: fallbackColor,
                  alignment: Alignment.center,
                  child: Text(
                    _initial(actorName),
                    style: TextStyle(
                        color: iconColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          if (actorAvatar != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: unread ? AppColors.brandAccent : Colors.grey.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  unread ? Iconsax.notification_bing : Iconsax.notification,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
    if (actorMemberId == null || actorMemberId!.isEmpty) return leading;
    return InkWell(
      onTap: () => showDailioMemberProfileSheet(
        context,
        DailioMemberPreview(
          memberId: actorMemberId!,
          name: actorName ?? 'Member',
          avatarUrl: actorAvatar,
        ),
      ),
      customBorder: const CircleBorder(),
      child: leading,
    );
  }

  String _initial(String? name) {
    final value = name?.trim() ?? '';
    return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
  }
}

class _NotificationImage extends StatelessWidget {
  final String url;
  const _NotificationImage({required this.url});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 52,
            height: 52,
            color: const Color(0xFFF1F1F1),
            child: const Icon(Iconsax.image, size: 17, color: Colors.grey),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 52,
            height: 52,
            color: const Color(0xFFF1F1F1),
            child: const Icon(Iconsax.image, size: 17, color: Colors.grey),
          ),
        ),
      );
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: 7,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          child: Row(
            children: [
              CircleAvatar(radius: 17, backgroundColor: Color(0xFFF1F1F1)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NotificationSkeletonLine(width: 150),
                    SizedBox(height: 8),
                    _NotificationSkeletonLine(width: double.infinity),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _NotificationSkeletonLine extends StatelessWidget {
  final double width;
  const _NotificationSkeletonLine({required this.width});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 10,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(6),
        ),
      );
}

class _NotificationEmpty extends StatelessWidget {
  const _NotificationEmpty();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(Iconsax.notification_status,
              size: 28, color: Colors.grey.shade500),
          const SizedBox(height: 10),
          const Text('You are all caught up.'),
        ],
      );
}

class _NotificationMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback action;
  const _NotificationMessage({
    required this.icon,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.brandAccent, size: 28),
            const SizedBox(height: 8),
            Text(message),
            TextButton.icon(
              onPressed: action,
              icon: const Icon(Iconsax.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}
