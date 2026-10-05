import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/media/cloudinary_media_upload.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/json_cache_store.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_nav_badges.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../feeds/pages/feed_pages.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  late final ApiClient _api;
  late final JsonCacheStore _cache;
  late final PreferencesStorage _preferences;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _feeds = [];
  int _selectedTab = 0;
  bool _loading = true;
  bool _feedsLoading = true;
  String? _error;
  final Set<String> _reacting = <String>{};
  int _feedRefreshToken = 0;

  bool get _canPublish => _preferences.hasPermission('ANNOUNCEMENT_CREATE');
  bool get _canCreateFeed => _preferences.hasPermission('FEED_CREATE');

  bool get _canPostToSelectedFeed {
    if (_selectedTab == 0 || _selectedTab - 1 >= _feeds.length) return false;
    final feed = _feeds[_selectedTab - 1];
    final canManage = _preferences.hasPermission('FEED_MODERATE') ||
        _preferences.hasPermission('FEED_UPDATE');
    return _preferences.hasPermission('FEED_POST') &&
        (feed['participants_can_post'] == true || canManage);
  }

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _cache = context.read<JsonCacheStore>();
    _preferences = context.read<PreferencesStorage>();
    _load();
    _loadFeeds();
  }

  String get _cacheKey =>
      'announcements:${_preferences.activeOrganizationId}:${_preferences.activeBranchId}';

  Future<void> _load() async {
    final organizationId = _preferences.activeOrganizationId;
    if (organizationId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No active organization';
        });
      }
      return;
    }
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final result = await _cache.load<List<Map<String, dynamic>>>(
        key: _cache.scopedKey(_cacheKey),
        scope: 'branch:${_preferences.activeBranchId}',
        fetch: () async =>
            (await _api.dio.get('/organizations/$organizationId/announcements'))
                .data,
        decode: _decodeList,
        onFresh: (fresh) {
          _updateTodayBadge(fresh);
          if (mounted) setState(() => _items = fresh);
        },
      );
      if (mounted) {
        setState(() {
          _items = result;
          _loading = false;
        });
      }
      _updateTodayBadge(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  String get _feedsCacheKey =>
      'feeds:${_preferences.activeOrganizationId}:${_preferences.activeBranchId}';

  Future<void> _loadFeeds() async {
    final organizationId = _preferences.activeOrganizationId;
    if (organizationId == null) return;
    try {
      final value = await _cache.load<List<Map<String, dynamic>>>(
        key: _cache.scopedKey(_feedsCacheKey),
        scope: 'branch:${_preferences.activeBranchId}',
        fetch: () async =>
            (await _api.dio.get('/organizations/$organizationId/feeds')).data,
        decode: _decodeList,
        onFresh: (fresh) {
          if (mounted) setState(() => _feeds = fresh);
        },
      );
      if (mounted) {
        setState(() {
          _feeds = value;
          _feedsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _feedsLoading = false);
    }
  }

  List<Map<String, dynamic>> _decodeList(dynamic payload) {
    final data = payload is Map ? payload['data'] : payload;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _updateTodayBadge(List<Map<String, dynamic>> items) {
    final today = DateTime.now();
    final count = items.where((item) {
      final created =
          DateTime.tryParse(item['created_at']?.toString() ?? '')?.toLocal();
      return created != null &&
          created.year == today.year &&
          created.month == today.month &&
          created.day == today.day;
    }).length;
    DailioNavBadgeController.setCount('announcements', count);
  }

  Future<void> _openAnnouncementComposer() async {
    final result = await context.push(AppRoutes.announcementCreate);
    if (result == true) {
      await _cache.clearKey(_cache.scopedKey(_cacheKey));
      await _load();
    }
  }

  Future<void> _openPostComposer() async {
    if (_selectedTab == 0 || _selectedTab - 1 >= _feeds.length) return;
    final feedId = _feeds[_selectedTab - 1]['id']?.toString();
    if (feedId == null || feedId.isEmpty) return;
    final result = await context
        .push(AppRoutes.feedPostCreate.replaceFirst(':feedId', feedId));
    if (result == true) {
      await _cache.clearKey(_cache.scopedKey(
          'feed-posts:${_preferences.activeOrganizationId}:${_preferences.activeBranchId}:$feedId'));
      if (mounted) setState(() => _feedRefreshToken++);
    }
  }

  Future<void> _react(Map<String, dynamic> item) async {
    final organizationId = _preferences.activeOrganizationId;
    final id = item['id']?.toString();
    if (organizationId == null || id == null || _reacting.contains(id)) return;
    final index = _items.indexWhere((entry) => entry['id']?.toString() == id);
    if (index < 0) return;
    final previous = Map<String, dynamic>.from(_items[index]);
    final wasLiked = item['my_reaction'] == 'LIKE';
    final currentReactions =
        (item['_count'] is Map ? item['_count']['reactions'] : 0) as num? ?? 0;
    final next = Map<String, dynamic>.from(item)
      ..['my_reaction'] = wasLiked ? null : 'LIKE'
      ..['_count'] = {
        ...((item['_count'] is Map)
            ? Map<String, dynamic>.from(item['_count'] as Map)
            : <String, dynamic>{}),
        'reactions': wasLiked
            ? (currentReactions - 1).clamp(0, double.infinity)
            : currentReactions + 1,
      };
    setState(() {
      _reacting.add(id);
      _items[index] = next;
    });
    try {
      if (wasLiked) {
        await _api.dio.delete(
            '/organizations/$organizationId/announcements/$id/reaction');
      } else {
        await _api.dio.put(
            '/organizations/$organizationId/announcements/$id/reaction',
            data: {'reaction': 'LIKE'});
      }
      await _cache.clearKey(_cache.scopedKey(_cacheKey));
      unawaited(_load());
    } catch (_) {
      if (mounted) setState(() => _items[index] = previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update reaction.')));
      }
    } finally {
      if (mounted) setState(() => _reacting.remove(id));
    }
  }

  Widget _buildTabs() {
    return Container(
      height: 45.r,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tab('Announcement', 0),
                      ..._feeds.asMap().entries.map((entry) => _tab(
                            entry.value['name']?.toString() ??
                                'Feed ${entry.key + 1}',
                            entry.key + 1,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_canCreateFeed)
            SizedBox(
              width: 42.r,
              height: 45.r,
              child: IconButton(
                tooltip: 'New feed',
                onPressed: () async {
                  final created = await context.push(AppRoutes.feedCreate);
                  if (created == true) {
                    await _cache.clearKey(_cache.scopedKey(_feedsCacheKey));
                    await _loadFeeds();
                  }
                },
                icon: Icon(Iconsax.add, size: 19.r),
                color: AppColors.brandAccent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index) {
    final selected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        height: 45.r,
        margin: EdgeInsets.only(right: 20.r),
        padding: EdgeInsets.symmetric(horizontal: 1.r),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.brandAccent : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13.r)),
      ),
    );
  }

  Widget _announcementBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(children: const [_EmptyAnnouncements()])
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 100.r),
              itemCount: _items.length,
              separatorBuilder: (_, __) => SizedBox(height: 18.r),
              itemBuilder: (_, index) => _AnnouncementCard(
                item: _items[index],
                onReact: () => _react(_items[index]),
                onOpen: () => context.push(AppRoutes.announcementDetail
                    .replaceFirst(
                        ':announcementId', _items[index]['id'].toString())),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        menuItems: [
          if (_canPublish)
            const DailioMenuItem(
                value: 'compose',
                icon: Iconsax.edit_2,
                label: 'New announcement'),
          const DailioMenuItem(
              value: 'refresh', icon: Iconsax.refresh, label: 'Refresh'),
        ],
        onMenuSelected: (value) {
          if (value == 'refresh') _load();
          if (value == 'compose') _openAnnouncementComposer();
        },
      ),
      body: Column(children: [
        _buildTabs(),
        Expanded(
          child: _selectedTab == 0
              ? (_loading
                  ? const _AnnouncementSkeleton()
                  : _error != null && _items.isEmpty
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : _announcementBody())
              : (_feedsLoading && _feeds.isEmpty
                  ? const FeedTimelineSkeleton()
                  : _selectedTab - 1 < _feeds.length
                      ? FeedTimeline(
                          key: ValueKey(
                              'feed-${_feeds[_selectedTab - 1]['id']}-$_feedRefreshToken'),
                          feed: _feeds[_selectedTab - 1])
                      : const _EmptyAnnouncements()),
        ),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _selectedTab == 0 && _canPublish
          ? Padding(
              padding: EdgeInsets.only(bottom: 78.r),
              child: FloatingActionButton(
                heroTag: 'announcement_create_fab',
                tooltip: 'New announcement',
                backgroundColor: AppColors.brandAccent,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                onPressed: _openAnnouncementComposer,
                child: Icon(Iconsax.add, size: 27.r),
              ),
            )
          : _canPostToSelectedFeed
              ? Padding(
                  padding: EdgeInsets.only(bottom: 78.r),
                  child: FloatingActionButton(
                    heroTag: 'feed_post_create_fab',
                    tooltip: 'New post',
                    backgroundColor: AppColors.brandAccent,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    onPressed: _openPostComposer,
                    child: Icon(Iconsax.add, size: 27.r),
                  ),
                )
              : null,
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onReact;
  final VoidCallback onOpen;

  const _AnnouncementCard(
      {required this.item, required this.onReact, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final actor = item['actor'] is Map
        ? Map<String, dynamic>.from(item['actor'])
        : <String, dynamic>{};
    final name = actor['name']?.toString() ?? 'Dailio';
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '');
    final reactions =
        (item['_count'] is Map ? item['_count']['reactions'] : null) as num? ??
            0;
    final comments =
        (item['_count'] is Map ? item['_count']['comments'] : null) as num? ??
            0;
    final commentPreview =
        (item['comments'] is List ? item['comments'] as List : const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
    final memberId = _memberId(actor);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18.r),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Avatar(
            url: actor['avatar_url']?.toString(),
            name: name,
            size: 36.r,
            onTap: memberId == null
                ? null
                : () => showDailioMemberProfileSheet(
                      context,
                      DailioMemberPreview(
                        memberId: memberId,
                        name: name,
                        avatarUrl: actor['avatar_url']?.toString(),
                      ),
                    ),
          ),
          SizedBox(width: 9.r),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14.r)),
                Text(_dateLabel(created),
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 11.r)),
              ])),
          if (item['priority'] != null && (item['priority'] as num) > 0)
            _Chip(label: 'Important', color: AppColors.brandAccent),
          SizedBox(width: 2.r),
          IconButton(
              onPressed: onOpen,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(width: 28.r, height: 28.r),
              icon: Icon(Iconsax.more, size: 18.r)),
        ]),
        SizedBox(height: 8.r),
        Text(item['title']?.toString() ?? 'Announcement',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.r)),
        SizedBox(height: 4.r),
        _ContentPreview(item: item),
        SizedBox(height: 7.r),
        Row(children: [
          InkWell(
              onTap: onReact,
              child: Row(children: [
                Icon(
                    item['my_reaction'] == 'LIKE'
                        ? Iconsax.heart5
                        : Iconsax.heart,
                    size: 20.r,
                    color: item['my_reaction'] == 'LIKE'
                        ? AppColors.brandAccent
                        : Colors.black87),
                SizedBox(width: 5.r),
                Text('$reactions', style: TextStyle(fontSize: 12.r)),
              ])),
          SizedBox(width: 18.r),
          InkWell(
              onTap: onOpen,
              child: Row(children: [
                Icon(Iconsax.message_text, size: 19.r),
                SizedBox(width: 5.r),
                Text('$comments', style: TextStyle(fontSize: 12.r))
              ])),
          const Spacer(),
          Text('View details',
              style: TextStyle(
                  color: AppColors.brandAccent,
                  fontSize: 12.r,
                  fontWeight: FontWeight.w600)),
        ]),
        if (commentPreview.isNotEmpty) ...[
          SizedBox(height: 10.r),
          ...commentPreview.map((comment) => _CommentPreview(comment: comment)),
        ],
        SizedBox(height: 12.r),
        Divider(height: 1.r, color: Colors.grey.shade200),
      ]),
    );
  }
}

class _ContentPreview extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ContentPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    final content =
        item['content'] is List ? item['content'] as List : const [];
    if (content.isEmpty) {
      return Text(item['body']?.toString() ?? '',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade800, height: 1.35));
    }
    final visibleContent = <dynamic>[...content.take(4)];
    // Keep announcement cards compact, but never hide a media block merely
    // because formatting blocks appeared before it.
    visibleContent.addAll(content.skip(4).where((raw) {
      if (raw is! Map) return false;
      final type = raw['type']?.toString();
      return type == 'image' || type == 'slide';
    }));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: visibleContent.map((raw) {
          final block =
              raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          final type = block['type']?.toString();
          if (type == 'divider') return Divider(color: Colors.grey.shade300);
          if (type == 'image' || type == 'slide') {
            return _MediaPlaceholder(
                storageKey: block['storage_key']?.toString(),
                announcementId: item['id']?.toString(),
                mediaUrl: block['media_url']?.toString(),
                format: block['format']?.toString(),
                alt: block['alt']?.toString());
          }
          final marks =
              (block['marks'] as List?)?.map((e) => e.toString()).toSet() ?? {};
          return Padding(
              padding: EdgeInsets.only(bottom: 4.r),
              child: Text(block['text']?.toString() ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: type == 'heading' ? 16.r : 14.r,
                      fontWeight: type == 'heading' || marks.contains('bold')
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontStyle: marks.contains('italic')
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: type == 'quote'
                          ? Colors.grey.shade700
                          : Colors.black87)));
        }).toList());
  }
}

class _CommentPreview extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentPreview({required this.comment});

  @override
  Widget build(BuildContext context) {
    final user = comment['user'] is Map
        ? Map<String, dynamic>.from(comment['user'])
        : <String, dynamic>{};
    final memberId = _memberId(user);
    return Padding(
      padding: EdgeInsets.only(bottom: 5.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            url: user['avatar_url']?.toString(),
            name: user['name']?.toString() ?? 'Member',
            size: 20.r,
            onTap: memberId == null
                ? null
                : () => showDailioMemberProfileSheet(
                      context,
                      DailioMemberPreview(
                        memberId: memberId,
                        name: user['name']?.toString() ?? 'Member',
                        avatarUrl: user['avatar_url']?.toString(),
                      ),
                    ),
          ),
          SizedBox(width: 7.r),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${user['name']?.toString() ?? 'Member'}  ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: comment['body']?.toString() ?? ''),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.r, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class AnnouncementDetailPage extends StatefulWidget {
  final String announcementId;
  const AnnouncementDetailPage({super.key, required this.announcementId});

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  late final ApiClient _api;
  late final JsonCacheStore _cache;
  late final PreferencesStorage _prefs;
  Map<String, dynamic>? _item;
  List<Map<String, dynamic>> _comments = [];
  final _commentController = TextEditingController();
  String? _replyTo;
  bool _loading = true;
  bool _reactionBusy = false;
  bool _commentSending = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _cache = context.read<JsonCacheStore>();
    _prefs = context.read<PreferencesStorage>();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final org = _prefs.activeOrganizationId;
    if (org == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }
    try {
      final response = await _api.dio
          .get('/organizations/$org/announcements/${widget.announcementId}');
      List<Map<String, dynamic>> commentsData = [];
      try {
        final comments = await _api.dio.get(
            '/organizations/$org/announcements/${widget.announcementId}/comments');
        commentsData = (comments.data['data'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {
        // Keep the announcement readable if comments are temporarily unavailable.
      }
      if (!mounted) return;
      setState(() {
        _item = Map<String, dynamic>.from(response.data['data'] as Map);
        _comments = commentsData;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    final org = _prefs.activeOrganizationId;
    if (text.isEmpty || org == null || _commentSending) return;
    final replyTo = _replyTo;
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = <String, dynamic>{
      'id': localId,
      'body': text,
      'reply_to_id': replyTo,
      'pending': true,
      'created_at': DateTime.now().toIso8601String(),
      'user': {'name': 'You'},
    };
    setState(() {
      _commentSending = true;
      _comments = [..._comments, optimistic];
      _commentController.clear();
      _replyTo = null;
    });
    try {
      await _api.dio.post(
          '/organizations/$org/announcements/${widget.announcementId}/comments',
          data: {
            'body': text,
            if (replyTo != null) 'reply_to_id': replyTo,
            'idempotency_key':
                'mobile-comment-${DateTime.now().microsecondsSinceEpoch}'
          });
      unawaited(_load());
    } catch (_) {
      if (mounted) {
        setState(() => _comments =
            _comments.where((comment) => comment['id'] != localId).toList());
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send comment.')));
      }
    } finally {
      if (mounted) setState(() => _commentSending = false);
    }
  }

  Future<void> _toggleReaction() async {
    final org = _prefs.activeOrganizationId;
    if (org == null || _item == null || _reactionBusy) return;
    final previous = Map<String, dynamic>.from(_item!);
    final wasLiked = _item!['my_reaction'] == 'LIKE';
    final currentReactions =
        (_item!['_count'] is Map ? _item!['_count']['reactions'] : 0) as num? ??
            0;
    final optimistic = Map<String, dynamic>.from(_item!)
      ..['my_reaction'] = wasLiked ? null : 'LIKE'
      ..['_count'] = {
        ...((_item!['_count'] is Map)
            ? Map<String, dynamic>.from(_item!['_count'] as Map)
            : <String, dynamic>{}),
        'reactions': wasLiked
            ? (currentReactions - 1).clamp(0, double.infinity)
            : currentReactions + 1,
      };
    setState(() {
      _reactionBusy = true;
      _item = optimistic;
    });
    try {
      if (wasLiked) {
        await _api.dio.delete(
            '/organizations/$org/announcements/${widget.announcementId}/reaction');
      } else {
        await _api.dio.put(
            '/organizations/$org/announcements/${widget.announcementId}/reaction',
            data: {'reaction': 'LIKE'});
      }
      unawaited(_load());
    } catch (_) {
      if (mounted) {
        setState(() => _item = previous);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update reaction.')));
      }
    } finally {
      if (mounted) setState(() => _reactionBusy = false);
    }
  }

  Future<void> _deleteAnnouncement() async {
    final org = _prefs.activeOrganizationId;
    if (org == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete announcement?',
      message: 'This announcement will be removed for everyone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Iconsax.trash,
    );
    if (!confirmed || !mounted) return;
    try {
      await _api.dio.post(
          '/organizations/$org/announcements/${widget.announcementId}/cancel');
      await _cache.clearKey(
          _cache.scopedKey('announcements:$org:${_prefs.activeBranchId}'));
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete announcement.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final actor = item?['actor'] is Map
        ? Map<String, dynamic>.from(item!['actor'])
        : <String, dynamic>{};
    final isAuthor = actor['id']?.toString() == _cache.userId;
    final canEdit = isAuthor || _prefs.hasPermission('ANNOUNCEMENT_UPDATE');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: [
          if (canEdit)
            const DailioMenuItem(
              value: 'edit',
              icon: Iconsax.edit_2,
              label: 'Edit announcement',
            ),
          if (canEdit)
            const DailioMenuItem(
              value: 'delete',
              icon: Iconsax.trash,
              label: 'Delete announcement',
            ),
        ],
        onMenuSelected: (value) {
          if (value == 'edit') {
            context.push(AppRoutes.announcementEdit
                .replaceFirst(':announcementId', widget.announcementId));
          }
          if (value == 'delete') _deleteAnnouncement();
        },
      ),
      body: _loading
          ? const _AnnouncementDetailSkeleton()
          : item == null
              ? _AnnouncementDetailError(onRetry: _load)
              : Column(children: [
                  Expanded(
                      child: ListView(
                          padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 12.r),
                          children: [
                        _AnnouncementCard(
                            item: item,
                            onReact: _toggleReaction,
                            onOpen: () {}),
                        SizedBox(height: 16.r),
                        Text('Comments',
                            style: TextStyle(
                                fontSize: 16.r, fontWeight: FontWeight.w700)),
                        SizedBox(height: 10.r),
                        if (_comments.isEmpty)
                          const Text('No comments yet.',
                              style: TextStyle(color: Colors.grey))
                        else
                          ..._comments.map(_commentTile),
                      ])),
                  SafeArea(
                      top: false,
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(12.r, 8.r, 12.r, 10.r),
                          child: Row(children: [
                            Expanded(
                                child: TextField(
                                    controller: _commentController,
                                    decoration: InputDecoration(
                                        hintText: _replyTo == null
                                            ? 'Write a comment'
                                            : 'Reply to comment',
                                        isDense: true,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(22.r))))),
                            IconButton(
                                onPressed:
                                    _commentSending ? null : _sendComment,
                                icon: const Icon(Iconsax.send_1,
                                    color: AppColors.brandAccent)),
                          ]))),
                ]),
    );
  }

  Widget _commentTile(Map<String, dynamic> comment) {
    final user = comment['user'] is Map
        ? Map<String, dynamic>.from(comment['user'])
        : <String, dynamic>{};
    final deleted =
        comment['deleted_at'] != null || comment['body'] == '[deleted]';
    final memberId = _memberId(user);
    return Padding(
        padding: EdgeInsets.only(bottom: 13.r),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Avatar(
              url: user['avatar_url']?.toString(),
              name: user['name']?.toString() ?? 'Member',
              size: 30.r,
              onTap: memberId == null
                  ? null
                  : () => showDailioMemberProfileSheet(
                        context,
                        DailioMemberPreview(
                          memberId: memberId,
                          name: user['name']?.toString() ?? 'Member',
                          avatarUrl: user['avatar_url']?.toString(),
                        ),
                      )),
          SizedBox(width: 8.r),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(user['name']?.toString() ?? 'Member',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13.r)),
                Text(
                    deleted
                        ? 'Comment deleted'
                        : comment['body']?.toString() ?? '',
                    style: TextStyle(
                        color: deleted ? Colors.grey : Colors.black87,
                        fontSize: 13.r)),
                if (comment['pending'] == true)
                  Text('Sending…',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 10.r))
                else if (!deleted)
                  TextButton(
                      onPressed: () =>
                          setState(() => _replyTo = comment['id']?.toString()),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero, minimumSize: Size(0, 24.r)),
                      child: Text('Reply', style: TextStyle(fontSize: 12.r))),
              ])),
        ]));
  }
}

class AnnouncementComposerPage extends StatefulWidget {
  final String? announcementId;
  const AnnouncementComposerPage({super.key, this.announcementId});
  @override
  State<AnnouncementComposerPage> createState() =>
      _AnnouncementComposerPageState();
}

class _AnnouncementComposerPageState extends State<AnnouncementComposerPage> {
  late final ApiClient _api;
  late final PreferencesStorage _prefs;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _bodyFocus = FocusNode();
  final List<Map<String, dynamic>> _blocks = [];
  bool _saving = false;
  bool _preview = false;
  bool _bold = false;
  bool _italic = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _prefs = context.read<PreferencesStorage>();
    _body.addListener(_refresh);
    unawaited(_loadExisting());
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _paragraph() => {
        'type': 'paragraph',
        'text': _body.text.trim(),
        'marks': [if (_bold) 'bold', if (_italic) 'italic']
      };

  void _formatSelection(String marker) {
    final value = _body.value;
    final start =
        value.selection.start < 0 ? value.text.length : value.selection.start;
    final end = value.selection.end < 0 ? start : value.selection.end;
    final selected = value.text.substring(start, end);
    final replacement =
        selected.isEmpty ? '$marker$marker' : '$marker$selected$marker';
    final caret =
        selected.isEmpty ? start + marker.length : start + replacement.length;
    _body.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
    _bodyFocus.requestFocus();
  }

  void _insertLinePrefix(String prefix) {
    final value = _body.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final lineStart = value.text.lastIndexOf('\n', start - 1) + 1;
    _body.value = value.copyWith(
      text: value.text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: lineStart + prefix.length),
      composing: TextRange.empty,
    );
    _bodyFocus.requestFocus();
  }

  Future<void> _addTextBlock(String type) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == 'heading' ? 'Add heading' : 'Add quote'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Write text'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    if (text != null && text.isNotEmpty && mounted) {
      setState(() => _blocks.add({'type': type, 'text': text}));
    }
  }

  Future<void> _loadExisting() async {
    final id = widget.announcementId;
    final organizationId = _prefs.activeOrganizationId;
    if (id == null || organizationId == null) return;
    try {
      final response = await _api.dio
          .get('/organizations/$organizationId/announcements/$id');
      final item = Map<String, dynamic>.from(response.data['data'] as Map);
      final content = (item['content'] as List?)
              ?.whereType<Map>()
              .map((block) => Map<String, dynamic>.from(block))
              .toList() ??
          [];
      if (!mounted) return;
      setState(() {
        _title.text = item['title']?.toString() ?? '';
        _body.text = item['body']?.toString() ?? '';
        _blocks
          ..clear()
          ..addAll(content.where((block) => block['type'] != 'paragraph'));
      });
    } catch (_) {}
  }

  Future<void> _addImage({bool slide = false}) async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
        maxWidth: 1600.r,
        maxHeight: 1600.r);
    if (file == null || !mounted) return;
    setState(() => _blocks.add({
          'type': slide ? 'slide' : 'image',
          'local_file': file.path,
          'alt': file.name,
          if (slide)
            'slide_index': _blocks.where((b) => b['type'] == 'slide').length,
        }));
  }

  Future<List<Map<String, dynamic>>> _blocksForPublish() async {
    final prepared = await Future.wait(_blocks.map((block) async {
      final localPath = block['local_file']?.toString();
      if (localPath == null || localPath.isEmpty) {
        return Map<String, dynamic>.from(block);
      }
      final filename = block['alt']?.toString() ?? 'announcement-image.jpg';
      final uploaded = await uploadSignedCloudinaryImage(
        api: _api.dio,
        signaturePath:
            '/organizations/${_prefs.activeOrganizationId}/announcements/media/upload-signature',
        filename: filename,
        filePath: localPath,
      );
      final next = Map<String, dynamic>.from(block)
        ..remove('local_file')
        ..remove('media_base64')
        ..remove('media_filename')
        ..['storage_key'] = uploaded['storage_key'];
      if (uploaded['format'] != null) next['format'] = uploaded['format'];
      return next;
    }));
    return prepared;
  }

  Future<void> _publish() async {
    final org = _prefs.activeOrganizationId;
    final branch = _prefs.activeBranchId;
    if (org == null ||
        branch == null ||
        _title.text.trim().isEmpty ||
        _body.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      final content = [
        _paragraph(),
        ...await _blocksForPublish(),
      ];
      final payload = {
        'branch_id': branch,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'content': content,
        'audience': 'ALL_ACTIVE_MEMBERS'
      };
      if (widget.announcementId == null) {
        final created = (await _api.dio.post(
          '/organizations/$org/announcements',
          data: payload,
        ))
            .data['data'] as Map;
        await _api.dio
            .post('/organizations/$org/announcements/${created['id']}/publish');
      } else {
        await _api.dio.patch(
          '/organizations/$org/announcements/${widget.announcementId}',
          data: payload,
        );
      }
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not publish announcement.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _mediaPreview() {
    if (_blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 12.r),
      child: Column(
        children: _blocks.asMap().entries.map((entry) {
          final localPath = entry.value['local_file']?.toString();
          return Padding(
            padding: EdgeInsets.only(bottom: 8.r),
            child: Row(children: [
              if (localPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.file(File(localPath),
                      width: 70.r, height: 52.r, fit: BoxFit.cover),
                )
              else
                SizedBox(width: 70.r, height: 52.r, child: Icon(Iconsax.image)),
              SizedBox(width: 9.r),
              Expanded(
                  child: Text(
                localPath == null
                    ? 'Attached media'
                    : 'Ready to upload when published',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.r),
              )),
              IconButton(
                tooltip: 'Remove media',
                onPressed: () => setState(() => _blocks.removeAt(entry.key)),
                icon: Icon(Iconsax.close_circle, size: 18.r),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComposer() => Scaffold(
        backgroundColor: Colors.white,
        appBar: DailioSimpleAppBar(onBack: () => context.pop()),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 24.r),
                children: [
                  Text(
                      widget.announcementId == null
                          ? 'New announcement'
                          : 'Edit announcement',
                      style: TextStyle(
                          fontSize: 18.r, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4.r),
                  Text('Share a clear update with everyone in this branch.',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12.r)),
                  SizedBox(height: 18.r),
                  _Field(
                      controller: _title,
                      label: 'Title',
                      hint: 'What should people know?'),
                  SizedBox(height: 16.r),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(14.r, 12.r, 10.r, 8.r),
                            child: Row(children: [
                              Text('Message',
                                  style: TextStyle(
                                      fontSize: 12.r,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('${_body.text.length}/10000',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11.r)),
                              SizedBox(width: 8.r),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment<bool>(
                                      value: false, label: Text('Write')),
                                  ButtonSegment<bool>(
                                      value: true, label: Text('Preview')),
                                ],
                                selected: {_preview},
                                onSelectionChanged: (value) =>
                                    setState(() => _preview = value.first),
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  textStyle: WidgetStateProperty.all(
                                      TextStyle(fontSize: 11.r)),
                                  padding: WidgetStateProperty.all(
                                      EdgeInsets.symmetric(horizontal: 8.r)),
                                ),
                              ),
                            ]),
                          ),
                          if (!_preview) ...[
                            Container(
                              height: 42.r,
                              color: const Color(0xFFFAFAFA),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  IconButton(
                                      tooltip: 'Bold',
                                      onPressed: () => _formatSelection('**'),
                                      icon:
                                          Icon(Iconsax.text_bold, size: 18.r)),
                                  IconButton(
                                      tooltip: 'Italic',
                                      onPressed: () => _formatSelection('_'),
                                      icon: Icon(Iconsax.text_italic,
                                          size: 18.r)),
                                  IconButton(
                                      tooltip: 'Bullet',
                                      onPressed: () => _insertLinePrefix('• '),
                                      icon: Icon(Iconsax.task_square,
                                          size: 18.r)),
                                  IconButton(
                                      tooltip: 'Quote',
                                      onPressed: () => _insertLinePrefix('> '),
                                      icon: Icon(Iconsax.quote_up, size: 18.r)),
                                  IconButton(
                                      tooltip: 'Add image',
                                      onPressed: () => _addImage(),
                                      icon: Icon(Iconsax.image, size: 18.r)),
                                  IconButton(
                                      tooltip: 'Add slide',
                                      onPressed: () => _addImage(slide: true),
                                      icon: Icon(Iconsax.gallery, size: 18.r)),
                                ]),
                              ),
                            ),
                            TextField(
                              controller: _body,
                              focusNode: _bodyFocus,
                              minLines: 11,
                              maxLines: null,
                              maxLength: 10000,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.top,
                              style: TextStyle(fontSize: 14.r, height: 1.5),
                              decoration: InputDecoration(
                                hintText: 'Write your announcement here...',
                                border: InputBorder.none,
                                counterText: '',
                                contentPadding:
                                    EdgeInsets.fromLTRB(14.r, 14.r, 14.r, 18.r),
                              ),
                            ),
                          ] else
                            Padding(
                              padding: EdgeInsets.all(14.r),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _body.text.trim().isEmpty
                                        ? Text('Your preview will appear here.',
                                            style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 14.r))
                                        : _AnnouncementRichText(
                                            text: _body.text,
                                            style: TextStyle(
                                                fontSize: 14.r, height: 1.5)),
                                    _mediaPreview(),
                                  ]),
                            ),
                        ]),
                  ),
                  if (!_preview) _mediaPreview(),
                  SizedBox(height: 8.r),
                  Text(
                      'Use the toolbar for emphasis, bullets, quotes, images, and slides.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11.r)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.r, 8.r, 16.r, 12.r),
                child: SizedBox(
                  height: 46.r,
                  child: FilledButton(
                    onPressed: _saving ? null : _publish,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandAccent),
                    child: _saving
                        ? SizedBox(
                            width: 18.r,
                            height: 18.r,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.r, color: Colors.white))
                        : Text(widget.announcementId == null
                            ? 'Publish announcement'
                            : 'Save changes'),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => _buildComposer();

  // Kept as a reference for the previous editor layout during migration.
  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: DailioSimpleAppBar(onBack: () => context.pop()),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 20.r),
          children: [
            Text(
              widget.announcementId == null
                  ? 'New announcement'
                  : 'Edit announcement',
              style: TextStyle(
                fontSize: 17.r,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12.r),
            _Field(
                controller: _title,
                label: 'Title',
                hint: 'What should people know?'),
            SizedBox(height: 12.r),
            Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(14.r)),
                child: Column(children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      TextButton(
                          onPressed: () => _addTextBlock('heading'),
                          child: const Text('H',
                              style: TextStyle(fontWeight: FontWeight.w800))),
                      TextButton(
                          onPressed: () => _addTextBlock('quote'),
                          child: Text('“', style: TextStyle(fontSize: 20.r))),
                      TextButton(
                          onPressed: () =>
                              setState(() => _blocks.add({'type': 'divider'})),
                          child: const Text('—')),
                      IconButton(
                          onPressed: () => setState(() => _bold = !_bold),
                          icon: Icon(Iconsax.text_bold,
                              color: _bold
                                  ? AppColors.brandAccent
                                  : Colors.black87)),
                      IconButton(
                          onPressed: () => setState(() => _italic = !_italic),
                          icon: Icon(Iconsax.text_italic,
                              color: _italic
                                  ? AppColors.brandAccent
                                  : Colors.black87)),
                      IconButton(
                          onPressed: () => _addImage(),
                          icon: const Icon(Iconsax.image)),
                      IconButton(
                          onPressed: () => _addImage(slide: true),
                          icon: const Icon(Iconsax.gallery)),
                    ]),
                  ),
                  TextField(
                      controller: _body,
                      maxLines: 6,
                      decoration: InputDecoration(
                          hintText: 'Write an announcement...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(14.r))),
                ])),
            if (_blocks.isNotEmpty) ...[
              SizedBox(height: 12.r),
              ..._blocks.asMap().entries.map((entry) {
                final localPath = entry.value['local_file']?.toString();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: localPath == null
                      ? const Icon(Iconsax.image)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: Image.file(
                            File(localPath),
                            width: 56.r,
                            height: 56.r,
                            fit: BoxFit.cover,
                          ),
                        ),
                  title: Text(entry.value['type'] == 'slide'
                      ? 'Slide ${entry.key + 1}'
                      : 'Image attached'),
                  subtitle: Text(localPath == null
                      ? 'Uploaded media'
                      : 'Ready to upload when published'),
                  trailing: IconButton(
                      onPressed: () =>
                          setState(() => _blocks.removeAt(entry.key)),
                      icon: Icon(Iconsax.close_circle, size: 19.r)),
                );
              }),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.r, 8.r, 16.r, 12.r),
            child: SizedBox(
              height: 44.r,
              child: FilledButton(
                onPressed: _saving ? null : _publish,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandAccent,
                ),
                child: _saving
                    ? SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.r,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.announcementId == null
                        ? 'Publish announcement'
                        : 'Save changes'),
              ),
            ),
          ),
        ),
      );
}

class _AnnouncementRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _AnnouncementRichText({required this.text, this.style});

  @override
  Widget build(BuildContext context) => Text(text, style: style);
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _Field(
      {required this.controller, required this.label, required this.hint});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w500)),
          SizedBox(height: 7.r),
          TextField(
            controller: controller,
            style: TextStyle(fontSize: 13.r),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(fontSize: 13.r, color: Colors.grey),
              prefixIcon: Icon(Iconsax.edit_2, size: 16.r),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  EdgeInsets.symmetric(vertical: 13.r, horizontal: 14.r),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide:
                    BorderSide(color: AppColors.brandAccent, width: 1.4.r),
              ),
            ),
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8.r)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11.r, fontWeight: FontWeight.w700)));
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final VoidCallback? onTap;
  const _Avatar({this.url, required this.name, required this.size, this.onTap});
  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.brandAccent.withValues(alpha: .12),
      backgroundImage: url != null && url!.isNotEmpty
          ? CachedNetworkImageProvider(url!)
          : null,
      child: url == null || url!.isEmpty
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                  color: AppColors.brandAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: size * .38))
          : null,
    );
    return onTap == null
        ? avatar
        : InkWell(
            onTap: onTap, customBorder: const CircleBorder(), child: avatar);
  }
}

String? _memberId(Map<String, dynamic> user) {
  final members = user['members'];
  if (members is List && members.isNotEmpty && members.first is Map) {
    return (members.first as Map)['id']?.toString();
  }
  return user['member_id']?.toString();
}

class _MediaPlaceholder extends StatefulWidget {
  final String? storageKey;
  final String? announcementId;
  final String? mediaUrl;
  final String? format;
  final String? alt;
  const _MediaPlaceholder(
      {this.storageKey,
      this.announcementId,
      this.mediaUrl,
      this.format,
      this.alt});

  @override
  State<_MediaPlaceholder> createState() => _MediaPlaceholderState();
}

class _MediaPlaceholderState extends State<_MediaPlaceholder> {
  String? _url;

  String? _formatFromAlt(String? value) {
    final name = value?.trim().toLowerCase();
    if (name == null || !name.contains('.')) return null;
    final format = name.split('.').last;
    return RegExp(r'^[a-z0-9]{2,8}$').hasMatch(format) ? format : null;
  }

  String? get _requestedFormat =>
      widget.format?.trim().toLowerCase() ?? _formatFromAlt(widget.alt);

  @override
  void initState() {
    super.initState();
    _url = widget.mediaUrl;
    // Always refresh protected media URLs. Cached announcement payloads may
    // contain a URL that has expired or was generated before a delivery rule
    // changed, while the storage key remains the stable authorization handle.
    _load();
  }

  Future<void> _load() async {
    final storageKey = widget.storageKey;
    final announcementId = widget.announcementId;
    final organizationId =
        context.read<PreferencesStorage>().activeOrganizationId;
    if (storageKey == null ||
        announcementId == null ||
        organizationId == null) {
      return;
    }
    try {
      final response = await context.read<ApiClient>().dio.get(
        '/organizations/$organizationId/announcements/media-url',
        queryParameters: {
          'storage_key': storageKey,
          'announcement_id': announcementId,
          if (_requestedFormat != null) 'format': _requestedFormat,
        },
      );
      if (mounted) {
        setState(() => _url = response.data['data']['url']?.toString());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = AspectRatio(
      aspectRatio: 1.65,
      child: Container(
        width: double.infinity,
        color: Colors.grey.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 18.r,
                height: 18.r,
                child: CircularProgressIndicator(
                    strokeWidth: 2.r, color: AppColors.brandAccent)),
          ],
        ),
      ),
    );
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 5.r),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
      child: _url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: _url!,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => _MediaError(
                onRetry: _load,
              ),
            ),
    );
  }
}

class _MediaError extends StatelessWidget {
  final VoidCallback onRetry;

  const _MediaError({required this.onRetry});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1.65,
        child: Container(
          color: const Color(0xFFF7F7F7),
          alignment: Alignment.center,
          child: IconButton(
            tooltip: 'Retry image',
            onPressed: onRetry,
            icon:
                Icon(Iconsax.refresh, color: Colors.grey.shade500, size: 20.r),
          ),
        ),
      );
}

class _AnnouncementSkeleton extends StatelessWidget {
  const _AnnouncementSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 100.r),
        itemCount: 5,
        separatorBuilder: (_, __) => Divider(height: 1.r),
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.symmetric(vertical: 12.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 18.r, backgroundColor: Color(0xFFF1F1F1)),
              SizedBox(width: 9.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AnnouncementSkeletonLine(width: 120.r),
                    SizedBox(height: 8.r),
                    _AnnouncementSkeletonLine(width: 190.r),
                    SizedBox(height: 7.r),
                    _AnnouncementSkeletonLine(width: double.infinity),
                    SizedBox(height: 10.r),
                    _AnnouncementSkeletonLine(width: 75.r),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _AnnouncementSkeletonLine extends StatelessWidget {
  final double width;
  const _AnnouncementSkeletonLine({required this.width});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 10.r,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(6.r),
        ),
      );
}

class _AnnouncementDetailError extends StatelessWidget {
  final VoidCallback onRetry;
  const _AnnouncementDetailError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.warning_2, size: 30.r, color: AppColors.brandAccent),
              SizedBox(height: 10.r),
              const Text('Could not open this announcement',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 8.r),
              TextButton.icon(
                onPressed: onRetry,
                icon: Icon(Iconsax.refresh, size: 16.r),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

class _AnnouncementDetailSkeleton extends StatelessWidget {
  const _AnnouncementDetailSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 32.r),
        children: [
          Row(
            children: [
              CircleAvatar(radius: 18.r, backgroundColor: Color(0xFFF1F1F1)),
              SizedBox(width: 9.r),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnnouncementSkeletonLine(width: 125.r),
                  SizedBox(height: 7.r),
                  _AnnouncementSkeletonLine(width: 80.r),
                ],
              ),
            ],
          ),
          SizedBox(height: 18.r),
          _AnnouncementSkeletonLine(width: 210.r),
          SizedBox(height: 10.r),
          const _AnnouncementSkeletonLine(width: double.infinity),
          SizedBox(height: 8.r),
          const _AnnouncementSkeletonLine(width: double.infinity),
          SizedBox(height: 8.r),
          _AnnouncementSkeletonLine(width: 160.r),
          SizedBox(height: 24.r),
          _AnnouncementSkeletonLine(width: 90.r),
        ],
      );
}

class _EmptyAnnouncements extends StatelessWidget {
  const _EmptyAnnouncements();
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(top: 220.r),
      child: Center(child: Text('No announcements yet.')));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Could not load announcements',
            style: TextStyle(color: Colors.grey.shade700)),
        SizedBox(height: 10.r),
        TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Iconsax.refresh),
            label: const Text('Retry'))
      ]));
}

String _dateLabel(DateTime? value) =>
    value == null ? '' : DateFormat('dd MMM, hh:mm a').format(value.toLocal());
