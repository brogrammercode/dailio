import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/json_cache_store.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';

class FeedTimeline extends StatefulWidget {
  final Map<String, dynamic> feed;

  const FeedTimeline({super.key, required this.feed});

  @override
  State<FeedTimeline> createState() => _FeedTimelineState();
}

class _FeedTimelineState extends State<FeedTimeline> {
  late final ApiClient _api;
  late final JsonCacheStore _cache;
  late final PreferencesStorage _prefs;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  String get _feedId => widget.feed['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _cache = context.read<JsonCacheStore>();
    _prefs = context.read<PreferencesStorage>();
    unawaited(_load());
  }

  String get _cacheKey =>
      'feed-posts:${_prefs.activeOrganizationId}:${_prefs.activeBranchId}:$_feedId';

  List<Map<String, dynamic>> _decode(dynamic payload) {
    final data = payload is Map ? payload['data'] : payload;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _load() async {
    final org = _prefs.activeOrganizationId;
    if (org == null || _feedId.isEmpty) return;
    setState(() {
      _loading = _posts.isEmpty;
      _error = null;
    });
    try {
      final value = await _cache.load<List<Map<String, dynamic>>>(
        key: _cache.scopedKey(_cacheKey),
        scope: 'branch:${_prefs.activeBranchId}',
        fetch: () async =>
            (await _api.dio.get('/organizations/$org/feeds/$_feedId/posts'))
                .data,
        decode: _decode,
        onFresh: (fresh) {
          if (mounted) setState(() => _posts = fresh);
        },
      );
      if (mounted) {
        setState(() {
          _posts = value;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _openPost(Map<String, dynamic> post) async {
    final org = _prefs.activeOrganizationId;
    final id = post['id']?.toString();
    if (org == null || id == null) return;
    try {
      await _api.dio.post('/organizations/$org/feeds/$_feedId/posts/$id/read');
    } catch (_) {}
    if (!mounted) return;
    await context.push(AppRoutes.feedPostDetail
        .replaceFirst(':feedId', _feedId)
        .replaceFirst(':postId', id));
    await _cache.clearKey(_cache.scopedKey(_cacheKey));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const FeedTimelineSkeleton();
    if (_error != null && _posts.isEmpty) {
      return _FeedMessage(
          icon: Iconsax.warning_2,
          text: 'Could not load this feed',
          action: _load);
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
        child: Row(
          children: [
            Text(
              '${_posts.length} ${_posts.length == 1 ? 'post' : 'posts'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _posts.isEmpty
              ? ListView(children: const [_FeedEmpty()])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _posts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) => _FeedPostTile(
                      post: _posts[index],
                      onTap: () => _openPost(_posts[index])),
                ),
        ),
      ),
    ]);
  }
}

class FeedCreatePage extends StatefulWidget {
  const FeedCreatePage({super.key});
  @override
  State<FeedCreatePage> createState() => _FeedCreatePageState();
}

class _FeedCreatePageState extends State<FeedCreatePage> {
  late final ApiClient _api;
  late final PreferencesStorage _prefs;
  final _name = TextEditingController();
  final _timeout = TextEditingController();
  final _threshold = TextEditingController(text: '3');
  List<Map<String, dynamic>> _members = [];
  final _selectedMembers = <String>{};
  bool _canPost = false;
  bool _saving = false;
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _prefs = context.read<PreferencesStorage>();
    unawaited(_loadMembers());
  }

  @override
  void dispose() {
    _name.dispose();
    _timeout.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final branch = _prefs.activeBranchId;
    if (branch == null) {
      if (mounted) setState(() => _loadingMembers = false);
      return;
    }
    try {
      final response = await _api.dio.get('/branches/$branch/members',
          queryParameters: {'page': 1, 'limit': 100});
      final data = response.data is Map ? response.data['data'] : null;
      if (!mounted) return;
      setState(() {
        _members = (data is List ? data : const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loadingMembers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _save() async {
    final org = _prefs.activeOrganizationId;
    if (org == null || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await _api.dio.post('/organizations/$org/feeds', data: {
        'name': _name.text.trim(),
        'member_ids': _selectedMembers.toList(),
        'participants_can_post': _canPost,
        'post_timeout': int.tryParse(_timeout.text.trim()),
        'report_threshold': int.tryParse(_threshold.text.trim()) ?? 3,
      });
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not create feed.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: DailioSimpleAppBar(onBack: () => context.pop()),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            const Text('New feed',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Choose participants and posting rules.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 14),
            _FeedField(
                controller: _name, label: 'Feed name', hint: 'e.g. Trainers'),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Participants can post'),
              subtitle: const Text('When off, only feed managers can post.'),
              value: _canPost,
              onChanged: (value) => setState(() => _canPost = value),
              activeThumbColor: AppColors.brandAccent,
            ),
            _FeedField(
                controller: _timeout,
                label: 'Post timeout (minutes)',
                hint: 'Optional'),
            const SizedBox(height: 12),
            _FeedField(
                controller: _threshold, label: 'Report threshold', hint: '3'),
            const SizedBox(height: 22),
            const Text('Participants',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_loadingMembers)
              ...List.generate(5, (_) => const _ParticipantSkeleton())
            else if (_members.isEmpty)
              Text('No active branch members found.',
                  style: TextStyle(color: Colors.grey.shade600))
            else
              ..._members.map((member) {
                final id = member['id']?.toString() ?? '';
                final user = member['user'] is Map
                    ? Map<String, dynamic>.from(member['user'])
                    : <String, dynamic>{};
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  value: _selectedMembers.contains(id),
                  title: Text(user['name']?.toString() ?? 'Member'),
                  subtitle: Text(member['member_number']?.toString() ?? ''),
                  activeColor: AppColors.brandAccent,
                  onChanged: (value) => setState(() => value == true
                      ? _selectedMembers.add(id)
                      : _selectedMembers.remove(id)),
                );
              }),
            const SizedBox(height: 12),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandAccent),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create feed'),
              ),
            ),
          ),
        ),
      );
}

class FeedPostComposerPage extends StatefulWidget {
  final String feedId;
  final String? postId;
  const FeedPostComposerPage({super.key, required this.feedId, this.postId});
  @override
  State<FeedPostComposerPage> createState() => _FeedPostComposerPageState();
}

class _FeedPostComposerPageState extends State<FeedPostComposerPage> {
  late final ApiClient _api;
  late final PreferencesStorage _prefs;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _bodyFocus = FocusNode();
  final List<Map<String, dynamic>> _blocks = [];
  bool _saving = false;
  bool _preview = false;

  bool get _canPublish =>
      _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _prefs = context.read<PreferencesStorage>();
    _title.addListener(_refresh);
    _body.addListener(_refresh);
    if (widget.postId != null) unawaited(_loadExisting());
  }

  @override
  void dispose() {
    _title.removeListener(_refresh);
    _body.removeListener(_refresh);
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadExisting() async {
    final org = _prefs.activeOrganizationId;
    if (org == null || widget.postId == null) return;
    try {
      final response = await _api.dio.get(
          '/organizations/$org/feeds/${widget.feedId}/posts/${widget.postId}');
      final post = Map<String, dynamic>.from(response.data['data'] as Map);
      final content = (post['content'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) => item['type'] != 'paragraph')
              .toList() ??
          [];
      if (!mounted) return;
      setState(() {
        _title.text = post['title']?.toString() ?? '';
        _body.text = post['body']?.toString() ?? '';
        _blocks
          ..clear()
          ..addAll(content);
      });
    } catch (_) {
      // Keep the editor usable if the existing post cannot be loaded.
    }
  }

  void _formatSelection(String marker) {
    final value = _body.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;
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
    final text = value.text.replaceRange(lineStart, lineStart, prefix);
    _body.value = value.copyWith(
      text: text,
      selection: TextSelection.collapsed(
          offset:
              (selection.baseOffset < 0 ? lineStart : selection.baseOffset) +
                  prefix.length),
      composing: TextRange.empty,
    );
    _bodyFocus.requestFocus();
  }

  Future<void> _addMedia({required bool slide}) async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (file == null || !mounted) return;
    setState(() => _blocks.add({
          'type': slide ? 'slide' : 'image',
          'local_file': file.path,
          'alt': file.name,
          if (slide)
            'slide_index': _blocks.where((b) => b['type'] == 'slide').length,
        }));
  }

  Future<List<Map<String, dynamic>>> _blocksForSave() async {
    final prepared = <Map<String, dynamic>>[];
    for (final block in _blocks) {
      final localPath = block['local_file']?.toString();
      if (localPath == null || localPath.isEmpty) {
        prepared.add(Map<String, dynamic>.from(block));
        continue;
      }
      final filename = block['alt']?.toString() ?? 'feed-image.jpg';
      final next = Map<String, dynamic>.from(block)
        ..remove('local_file')
        ..['media_base64'] = base64Encode(await File(localPath).readAsBytes())
        ..['media_filename'] = filename;
      prepared.add(next);
    }
    return prepared;
  }

  Future<void> _save() async {
    final org = _prefs.activeOrganizationId;
    if (org == null || !_canPublish || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final branch = _prefs.activeBranchId;
      if (branch == null) return;
      final contentBlocks = await _blocksForSave();
      final payload = {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'content': [
          {
            'type': 'paragraph',
            'text': _body.text.trim(),
          },
          ...contentBlocks,
        ],
        if (widget.postId == null)
          'idempotency_key': 'mobile-${DateTime.now().microsecondsSinceEpoch}',
      };
      if (widget.postId == null) {
        await _api.dio.post('/organizations/$org/feeds/${widget.feedId}/posts',
            data: payload);
      } else {
        await _api.dio.patch(
            '/organizations/$org/feeds/${widget.feedId}/posts/${widget.postId}',
            data: payload);
      }
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not publish post.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _composerMediaPreview() {
    if (_blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _blocks.asMap().entries.map((entry) {
          final localPath = entry.value['local_file']?.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (localPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(localPath),
                      width: 70,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const SizedBox(
                    width: 70,
                    height: 52,
                    child: Icon(Iconsax.image),
                  ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    localPath == null
                        ? 'Uploaded media'
                        : 'Ready to upload when published',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove media',
                  onPressed: () => setState(() => _blocks.removeAt(entry.key)),
                  icon: const Icon(Iconsax.close_circle, size: 18),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(onBack: () => context.pop()),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Text(widget.postId == null ? 'New post' : 'Edit post',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Share a clear update with this feed.',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 18),
                  _FeedField(
                    controller: _title,
                    label: 'Title',
                    hint: 'What is this about?',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                          child: Row(
                            children: [
                              const Text('Message',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('${_body.text.length}/10000',
                                  style: TextStyle(
                                      color: _body.text.length > 9500
                                          ? Colors.red
                                          : Colors.grey.shade500,
                                      fontSize: 11)),
                              const SizedBox(width: 8),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment<bool>(
                                      value: false, label: Text('Write')),
                                  ButtonSegment<bool>(
                                      value: true, label: Text('Preview')),
                                ],
                                selected: {_preview},
                                onSelectionChanged: (selection) =>
                                    setState(() => _preview = selection.first),
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  textStyle: WidgetStateProperty.all(
                                      const TextStyle(fontSize: 11)),
                                  padding: WidgetStateProperty.all(
                                      const EdgeInsets.symmetric(
                                          horizontal: 8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_preview) ...[
                          Container(
                            height: 42,
                            decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                border: Border(
                                    top:
                                        BorderSide(color: Colors.grey.shade200),
                                    bottom: BorderSide(
                                        color: Colors.grey.shade200))),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Bold selection',
                                    onPressed: () => _formatSelection('**'),
                                    icon:
                                        const Icon(Iconsax.text_bold, size: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'Italic selection',
                                    onPressed: () => _formatSelection('_'),
                                    icon: const Icon(Iconsax.text_italic,
                                        size: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'Bullet line',
                                    onPressed: () => _insertLinePrefix('• '),
                                    icon: const Icon(Iconsax.task_square,
                                        size: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'Quote line',
                                    onPressed: () => _insertLinePrefix('> '),
                                    icon:
                                        const Icon(Iconsax.quote_up, size: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'Add image',
                                    onPressed: () => _addMedia(slide: false),
                                    icon: const Icon(Iconsax.image, size: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'Add slide',
                                    onPressed: () => _addMedia(slide: true),
                                    icon: const Icon(Iconsax.gallery, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextField(
                            controller: _body,
                            focusNode: _bodyFocus,
                            minLines: 11,
                            maxLines: null,
                            maxLength: 10000,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textAlignVertical: TextAlignVertical.top,
                            scrollPadding: const EdgeInsets.all(24),
                            style: const TextStyle(fontSize: 14, height: 1.5),
                            decoration: const InputDecoration(
                              hintText: 'Write your update here...',
                              hintStyle:
                                  TextStyle(color: Colors.grey, fontSize: 14),
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding:
                                  EdgeInsets.fromLTRB(14, 14, 14, 18),
                            ),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _body.text.trim().isEmpty
                                    ? Text('Your preview will appear here.',
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 14))
                                    : _FeedRichText(
                                        text: _body.text,
                                        style: const TextStyle(
                                            fontSize: 14, height: 1.5)),
                                _composerMediaPreview(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_preview) _composerMediaPreview(),
                  const SizedBox(height: 8),
                  Text('Use the toolbar for emphasis, bullets, and quotes.',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _saving || !_canPublish ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandAccent),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(widget.postId == null
                            ? 'Publish post'
                            : 'Save changes'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedPostDetailPage extends StatefulWidget {
  final String feedId;
  final String postId;
  const FeedPostDetailPage(
      {super.key, required this.feedId, required this.postId});
  @override
  State<FeedPostDetailPage> createState() => _FeedPostDetailPageState();
}

class _FeedPostDetailPageState extends State<FeedPostDetailPage> {
  late final ApiClient _api;
  late final PreferencesStorage _prefs;
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  final _comment = TextEditingController();
  String? _replyTo;
  bool _loading = true;
  bool _reactionBusy = false;
  bool _commentSending = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _prefs = context.read<PreferencesStorage>();
    unawaited(_load());
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final org = _prefs.activeOrganizationId;
    if (org == null) return;
    try {
      final responses = await Future.wait([
        _api.dio.get(
            '/organizations/$org/feeds/${widget.feedId}/posts/${widget.postId}'),
        _api.dio.get(
            '/organizations/$org/feeds/${widget.feedId}/posts/${widget.postId}/comments'),
      ]);
      if (!mounted) return;
      setState(() {
        _post = Map<String, dynamic>.from(responses[0].data['data'] as Map);
        final data = responses[1].data['data'];
        _comments = (data is List ? data : const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _react() async {
    final org = _prefs.activeOrganizationId;
    if (org == null || _post == null || _reactionBusy) return;
    final previous = Map<String, dynamic>.from(_post!);
    final wasLiked = _post!['my_reaction'] == 'LIKE';
    final currentReactions =
        (_post!['_count'] is Map ? _post!['_count']['reactions'] : 0) as num? ??
            0;
    final optimistic = Map<String, dynamic>.from(_post!)
      ..['my_reaction'] = wasLiked ? null : 'LIKE'
      ..['_count'] = {
        ...((_post!['_count'] is Map)
            ? Map<String, dynamic>.from(_post!['_count'] as Map)
            : <String, dynamic>{}),
        'reactions': wasLiked
            ? (currentReactions - 1).clamp(0, double.infinity)
            : currentReactions + 1,
      };
    setState(() {
      _reactionBusy = true;
      _post = optimistic;
    });
    try {
      if (wasLiked) {
        await _api.dio.delete(
            '/organizations/$org/feeds/${widget.feedId}/posts/${widget.postId}/reaction');
      } else {
        await _api.dio.put(
            '/organizations/$org/feeds/${widget.feedId}/posts/${widget.postId}/reaction',
            data: {'reaction': 'LIKE'});
      }
      unawaited(_load());
    } catch (_) {
      if (mounted) {
        setState(() => _post = previous);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update reaction.')));
      }
    } finally {
      if (mounted) setState(() => _reactionBusy = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    final org = _prefs.activeOrganizationId;
    if (org == null || text.isEmpty || _commentSending) return;
    final replyTo = _replyTo;
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = <String, dynamic>{
      'id': localId,
      'body': text,
      'reply_to_id': replyTo,
      'pending': true,
      'created_at': DateTime.now().toIso8601String(),
      'member': {
        'user': {'name': 'You'}
      },
    };
    setState(() {
      _commentSending = true;
      _comments = [..._comments, optimistic];
      _comment.clear();
      _replyTo = null;
    });
    try {
      await _api.dio.post(
          '/organizations/$org/feeds/${widget.feedId}/posts/${widget.postId}/comments',
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

  Future<void> _report() async {
    final org = _prefs.activeOrganizationId;
    if (org == null) return;
    final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final controller = TextEditingController();
          return AlertDialog(
              title: const Text('Report post'),
              content: TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Why are you reporting this?')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, controller.text.trim()),
                    child: const Text('Report'))
              ]);
        });
    if (reason == null || reason.isEmpty) return;
    await _api.dio.post(
        '/organizations/$org/feeds/${widget.feedId}/posts/${widget.postId}/report',
        data: {'reason': reason});
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Report submitted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final member = post?['member'] is Map
        ? Map<String, dynamic>.from(post!['member'])
        : <String, dynamic>{};
    final user = member['user'] is Map
        ? Map<String, dynamic>.from(member['user'])
        : <String, dynamic>{};
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
          onBack: () => context.pop(),
          menuItems: [
            if (_prefs.hasPermission('FEED_UPDATE') ||
                _prefs.hasPermission('FEED_MODERATE'))
              const DailioMenuItem(
                  value: 'edit', icon: Iconsax.edit_2, label: 'Edit post'),
            const DailioMenuItem(
                value: 'report', icon: Iconsax.flag, label: 'Report post')
          ],
          onMenuSelected: (value) {
            if (value == 'edit') {
              context.push(AppRoutes.feedPostEdit
                  .replaceFirst(':feedId', widget.feedId)
                  .replaceFirst(':postId', widget.postId));
            }
            if (value == 'report') _report();
          }),
      body: _loading
          ? const FeedPostDetailSkeleton()
          : post == null
              ? const Center(child: Text('Post unavailable'))
              : Column(children: [
                  Expanded(
                      child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          children: [
                        Row(children: [
                          _FeedAvatar(
                              url: user['avatar_url']?.toString(),
                              name: user['name']?.toString() ?? 'Member',
                              onTap: member['id'] == null
                                  ? null
                                  : () => showDailioMemberProfileSheet(
                                        context,
                                        DailioMemberPreview(
                                          memberId: member['id'].toString(),
                                          name: user['name']?.toString() ??
                                              'Member',
                                          avatarUrl:
                                              user['avatar_url']?.toString(),
                                        ),
                                      )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(user['name']?.toString() ?? 'Member',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(_date(post['created_at']),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600))
                              ]))
                        ]),
                        const SizedBox(height: 18),
                        Text(post['title']?.toString() ?? '',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _FeedRichText(
                            text: post['body']?.toString() ?? '',
                            style: const TextStyle(fontSize: 15, height: 1.45)),
                        _FeedContentMedia(post: post, maxItems: null),
                        const SizedBox(height: 18),
                        Row(children: [
                          IconButton(
                              onPressed: _reactionBusy ? null : _react,
                              icon: Icon(
                                  post['my_reaction'] == 'LIKE'
                                      ? Iconsax.heart5
                                      : Iconsax.heart,
                                  color: post['my_reaction'] == 'LIKE'
                                      ? AppColors.brandAccent
                                      : Colors.black87)),
                          Text(
                              '${(post['_count'] is Map ? post['_count']['reactions'] : 0) ?? 0}'),
                          const SizedBox(width: 18),
                          const Icon(Iconsax.message_text, size: 19),
                          const SizedBox(width: 5),
                          Text(
                              '${(post['_count'] is Map ? post['_count']['comments'] : 0) ?? 0}')
                        ]),
                        const SizedBox(height: 22),
                        const Text('Comments',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17)),
                        const SizedBox(height: 12),
                        if (_comments.isEmpty)
                          Text('No comments yet.',
                              style: TextStyle(color: Colors.grey.shade600))
                        else
                          ..._comments.map(_commentTile),
                      ])),
                  SafeArea(
                      top: false,
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                  controller: _comment,
                                  decoration: InputDecoration(
                                      isDense: true,
                                      hintText: _replyTo == null
                                          ? 'Write a comment'
                                          : 'Reply to comment',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(22)))),
                            ),
                            IconButton(
                                onPressed:
                                    _commentSending ? null : _sendComment,
                                icon: const Icon(Iconsax.send_1,
                                    color: AppColors.brandAccent))
                          ]))),
                ]),
    );
  }

  Widget _commentTile(Map<String, dynamic> comment) {
    final member = comment['member'] is Map
        ? Map<String, dynamic>.from(comment['member'])
        : <String, dynamic>{};
    final user = member['user'] is Map
        ? Map<String, dynamic>.from(member['user'])
        : <String, dynamic>{};
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _FeedAvatar(
              url: user['avatar_url']?.toString(),
              name: user['name']?.toString() ?? 'Member',
              size: 30,
              onTap: member['id'] == null
                  ? null
                  : () => showDailioMemberProfileSheet(
                        context,
                        DailioMemberPreview(
                          memberId: member['id'].toString(),
                          name: user['name']?.toString() ?? 'Member',
                          avatarUrl: user['avatar_url']?.toString(),
                        ),
                      )),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(user['name']?.toString() ?? 'Member',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(comment['body']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13)),
                if (comment['pending'] == true)
                  Text('Sending…',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 10))
                else
                  TextButton(
                      onPressed: () =>
                          setState(() => _replyTo = comment['id']?.toString()),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 22)),
                      child:
                          const Text('Reply', style: TextStyle(fontSize: 12)))
              ]))
        ]));
  }
}

class _FeedRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const _FeedRichText({
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      TextSpan(children: _spans(text, base)),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  List<InlineSpan> _spans(String value, TextStyle base) {
    final spans = <InlineSpan>[];
    final lines = value.split('\n');
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final isBullet = line.startsWith('• ') || line.startsWith('- ');
      final isQuote = line.startsWith('> ');
      final content = (isBullet || isQuote) ? line.substring(2) : line;
      if (isBullet) {
        spans.add(TextSpan(
            text: '• ', style: base.copyWith(fontWeight: FontWeight.w700)));
      } else if (isQuote) {
        spans.add(TextSpan(
            text: '│ ',
            style: base.copyWith(
                color: AppColors.brandAccent, fontWeight: FontWeight.w700)));
      }
      spans.addAll(_inlineSpans(content, base));
      if (lineIndex < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  List<InlineSpan> _inlineSpans(String value, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*\n]+\*\*|_[^_\n]+_)');
    var cursor = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final italic = token.startsWith('_');
      spans.add(TextSpan(
        text: token.substring(italic ? 1 : 2, token.length - (italic ? 1 : 2)),
        style: base.copyWith(
            fontWeight: italic ? FontWeight.w400 : FontWeight.w700,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal),
      ));
      cursor = match.end;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }
    return spans;
  }
}

class _FeedContentMedia extends StatelessWidget {
  final Map<String, dynamic> post;
  final int? maxItems;
  const _FeedContentMedia({required this.post, required this.maxItems});

  @override
  Widget build(BuildContext context) {
    final blocks =
        (post['content'] is List ? post['content'] as List : const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['type'] == 'image' || item['type'] == 'slide')
            .toList();
    final visible = maxItems == null ? blocks : blocks.take(maxItems!).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: visible
            .map((block) => _FeedMediaPlaceholder(
                  storageKey: block['storage_key']?.toString(),
                  feedId: post['feed_id']?.toString(),
                  postId: post['id']?.toString(),
                  format: block['format']?.toString(),
                  alt: block['alt']?.toString(),
                ))
            .toList(),
      ),
    );
  }
}

class _FeedMediaPlaceholder extends StatefulWidget {
  final String? storageKey;
  final String? feedId;
  final String? postId;
  final String? format;
  final String? alt;
  const _FeedMediaPlaceholder({
    this.storageKey,
    this.feedId,
    this.postId,
    this.format,
    this.alt,
  });

  @override
  State<_FeedMediaPlaceholder> createState() => _FeedMediaPlaceholderState();
}

class _FeedMediaPlaceholderState extends State<_FeedMediaPlaceholder> {
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
    _load();
  }

  Future<void> _load() async {
    final org = context.read<PreferencesStorage>().activeOrganizationId;
    if (org == null ||
        widget.storageKey == null ||
        widget.feedId == null ||
        widget.postId == null) {
      return;
    }
    try {
      final response = await context.read<ApiClient>().dio.get(
        '/organizations/$org/feeds/media-url',
        queryParameters: {
          'storage_key': widget.storageKey,
          'feed_id': widget.feedId,
          'post_id': widget.postId,
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
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.image, color: Colors.grey),
            if (widget.alt != null)
              Text(widget.alt!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: _url!,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            ),
    );
  }
}

class _FeedPostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;
  const _FeedPostTile({required this.post, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final member = post['member'] is Map
        ? Map<String, dynamic>.from(post['member'])
        : <String, dynamic>{};
    final user = member['user'] is Map
        ? Map<String, dynamic>.from(member['user'])
        : <String, dynamic>{};
    final read =
        post['read_by'] is List && (post['read_by'] as List).isNotEmpty;
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FeedAvatar(
                  url: user['avatar_url']?.toString(),
                  name: user['name']?.toString() ?? 'Member',
                  onTap: member['id'] == null
                      ? null
                      : () => showDailioMemberProfileSheet(
                            context,
                            DailioMemberPreview(
                              memberId: member['id'].toString(),
                              name: user['name']?.toString() ?? 'Member',
                              avatarUrl: user['avatar_url']?.toString(),
                            ),
                          )),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(user['name']?.toString() ?? 'Member',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      Text(_date(post['created_at']),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600))
                    ]),
                    const SizedBox(height: 4),
                    Text(post['title']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    _FeedRichText(
                        text: post['body']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700)),
                    _FeedContentMedia(post: post, maxItems: 1),
                    const SizedBox(height: 7),
                    Row(children: [
                      Icon(read ? Iconsax.tick_circle : Iconsax.message,
                          size: 15,
                          color: read ? Colors.green : AppColors.brandAccent),
                      const SizedBox(width: 4),
                      Text(read ? 'Read' : 'New',
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  read ? Colors.green : AppColors.brandAccent))
                    ])
                  ]))
            ])));
  }
}

class _FeedField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _FeedField(
      {required this.controller, required this.label, required this.hint});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            maxLines: 1,
            keyboardType:
                label.contains('minute') || label.contains('threshold')
                    ? TextInputType.number
                    : null,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Iconsax.edit_2, size: 16),
              alignLabelWithHint: false,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.brandAccent, width: 1.4),
              ),
            ),
          ),
        ],
      );
}

class _FeedAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final VoidCallback? onTap;
  const _FeedAvatar({
    required this.url,
    required this.name,
    this.size = 42,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFFFE6D2),
      backgroundImage:
          url == null || url!.isEmpty ? null : CachedNetworkImageProvider(url!),
      child: url == null || url!.isEmpty
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                  color: AppColors.brandAccent, fontWeight: FontWeight.w700))
          : null,
    );
    return onTap == null
        ? avatar
        : InkWell(
            onTap: onTap, customBorder: const CircleBorder(), child: avatar);
  }
}

class _ParticipantSkeleton extends StatelessWidget {
  const _ParticipantSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const CircleAvatar(radius: 18, backgroundColor: Color(0xFFF0F0F0)),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(width: 140),
                  SizedBox(height: 7),
                  _SkeletonLine(width: 82),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      );
}

class FeedTimelineSkeleton extends StatelessWidget {
  const FeedTimelineSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
      itemCount: 5,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) =>
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 21, backgroundColor: Color(0xFFF0F0F0)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const _SkeletonLine(width: 130),
                  SizedBox(height: 9),
                  _SkeletonLine(width: double.infinity),
                  SizedBox(height: 7),
                  _SkeletonLine(width: 220),
                  SizedBox(height: 10),
                  _SkeletonLine(width: 80)
                ]))
          ]));
}

class FeedPostDetailSkeleton extends StatelessWidget {
  const FeedPostDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          Row(
            children: [
              const CircleAvatar(
                  radius: 21, backgroundColor: Color(0xFFF0F0F0)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SkeletonLine(width: 130),
                  SizedBox(height: 8),
                  _SkeletonLine(width: 85),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SkeletonLine(width: 220),
          const SizedBox(height: 12),
          const _SkeletonLine(width: double.infinity),
          const SizedBox(height: 8),
          const _SkeletonLine(width: double.infinity),
          const SizedBox(height: 8),
          const _SkeletonLine(width: 160),
          const SizedBox(height: 26),
          const _SkeletonLine(width: 95),
        ],
      );
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  const _SkeletonLine({required this.width});
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: 11,
      decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8)));
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.only(top: 100),
      child: Center(child: Text('No posts in this feed yet.')));
}

class _FeedMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final Future<void> Function() action;
  const _FeedMessage(
      {required this.icon, required this.text, required this.action});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.brandAccent),
        const SizedBox(height: 8),
        Text(text),
        TextButton(onPressed: action, child: const Text('Retry'))
      ]));
}

String _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return parsed == null ? '' : DateFormat('d MMM, h:mm a').format(parsed);
}
