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
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/confirm_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  Future<void> _react(Map<String, dynamic> post) async {
    final org = _prefs.activeOrganizationId;
    final id = post['id']?.toString();
    if (org == null || id == null) return;
    final index = _posts.indexWhere((item) => item['id']?.toString() == id);
    if (index < 0) return;
    final wasLiked = post['my_reaction'] == 'LIKE';
    final count =
        (post['_count'] is Map ? post['_count']['reactions'] : 0) as num? ?? 0;
    final next = Map<String, dynamic>.from(post)
      ..['my_reaction'] = wasLiked ? null : 'LIKE'
      ..['_count'] = {
        ...((post['_count'] is Map)
            ? Map<String, dynamic>.from(post['_count'] as Map)
            : <String, dynamic>{}),
        'reactions':
            wasLiked ? (count - 1).clamp(0, double.infinity) : count + 1,
      };
    setState(() => _posts[index] = next);
    try {
      if (wasLiked) {
        await _api.dio
            .delete('/organizations/$org/feeds/$_feedId/posts/$id/reaction');
      } else {
        await _api.dio.put(
            '/organizations/$org/feeds/$_feedId/posts/$id/reaction',
            data: {'reaction': 'LIKE'});
      }
      unawaited(_cache.clearKey(_cache.scopedKey(_cacheKey)));
    } catch (_) {
      if (mounted) setState(() => _posts[index] = post);
    }
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
        padding: EdgeInsets.fromLTRB(16.r, 4.r, 12.r, 0),
        child: Row(
          children: [
            Text(
              '${_posts.length} ${_posts.length == 1 ? 'post' : 'posts'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.r),
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
                  padding: EdgeInsets.fromLTRB(16.r, 8.r, 16.r, 100.r),
                  itemCount: _posts.length,
                  separatorBuilder: (_, __) => Divider(height: 1.r),
                  itemBuilder: (_, index) => _FeedPostTile(
                      post: _posts[index],
                      onTap: () => _openPost(_posts[index]),
                      onReact: () => _react(_posts[index])),
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
          padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 20.r),
          children: [
            Text('New feed',
                style: TextStyle(fontSize: 17.r, fontWeight: FontWeight.w700)),
            SizedBox(height: 4.r),
            Text('Choose participants and posting rules.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.r)),
            SizedBox(height: 14.r),
            _FeedField(
                controller: _name, label: 'Feed name', hint: 'e.g. Trainers'),
            SizedBox(height: 12.r),
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
            SizedBox(height: 12.r),
            _FeedField(
                controller: _threshold, label: 'Report threshold', hint: '3'),
            SizedBox(height: 22.r),
            const Text('Participants',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8.r),
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
            SizedBox(height: 12.r),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.r, 8.r, 16.r, 12.r),
            child: SizedBox(
              height: 44.r,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandAccent),
                child: _saving
                    ? SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.r, color: Colors.white))
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

  Future<List<Map<String, dynamic>>> _blocksForSave() async {
    final prepared = await Future.wait(_blocks.map((block) async {
      final localPath = block['local_file']?.toString();
      if (localPath == null || localPath.isEmpty) {
        return Map<String, dynamic>.from(block);
      }
      final filename = block['alt']?.toString() ?? 'feed-image.jpg';
      final uploaded = await uploadSignedCloudinaryImage(
        api: _api.dio,
        signaturePath:
            '/organizations/${_prefs.activeOrganizationId}/feeds/media/upload-signature',
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
      padding: EdgeInsets.only(top: 12.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _blocks.asMap().entries.map((entry) {
          final localPath = entry.value['local_file']?.toString();
          return Padding(
            padding: EdgeInsets.only(bottom: 8.r),
            child: Row(
              children: [
                if (localPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.file(
                      File(localPath),
                      width: 70.r,
                      height: 52.r,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  SizedBox(
                    width: 70.r,
                    height: 52.r,
                    child: Icon(Iconsax.image),
                  ),
                SizedBox(width: 9.r),
                Expanded(
                  child: Text(
                    localPath == null
                        ? 'Uploaded media'
                        : 'Ready to upload when published',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12.r,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove media',
                  onPressed: () => setState(() => _blocks.removeAt(entry.key)),
                  icon: Icon(Iconsax.close_circle, size: 18.r),
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
                padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 24.r),
                children: [
                  Text(widget.postId == null ? 'New post' : 'Edit post',
                      style: TextStyle(
                          fontSize: 18.r, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4.r),
                  Text('Share a clear update with this feed.',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12.r)),
                  SizedBox(height: 18.r),
                  _FeedField(
                    controller: _title,
                    label: 'Title',
                    hint: 'What is this about?',
                  ),
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
                          child: Row(
                            children: [
                              Text('Message',
                                  style: TextStyle(
                                      fontSize: 12.r,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('${_body.text.length}/10000',
                                  style: TextStyle(
                                      color: _body.text.length > 9500
                                          ? Colors.red
                                          : Colors.grey.shade500,
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
                                onSelectionChanged: (selection) =>
                                    setState(() => _preview = selection.first),
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  textStyle: WidgetStateProperty.all(
                                      TextStyle(fontSize: 11.r)),
                                  padding: WidgetStateProperty.all(
                                      EdgeInsets.symmetric(horizontal: 8.r)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_preview) ...[
                          Container(
                            height: 42.r,
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
                                    icon: Icon(Iconsax.text_bold, size: 18.r),
                                  ),
                                  IconButton(
                                    tooltip: 'Italic selection',
                                    onPressed: () => _formatSelection('_'),
                                    icon: Icon(Iconsax.text_italic, size: 18.r),
                                  ),
                                  IconButton(
                                    tooltip: 'Bullet line',
                                    onPressed: () => _insertLinePrefix('• '),
                                    icon: Icon(Iconsax.task_square, size: 18.r),
                                  ),
                                  IconButton(
                                    tooltip: 'Quote line',
                                    onPressed: () => _insertLinePrefix('> '),
                                    icon: Icon(Iconsax.quote_up, size: 18.r),
                                  ),
                                  IconButton(
                                    tooltip: 'Add image',
                                    onPressed: () => _addMedia(slide: false),
                                    icon: Icon(Iconsax.image, size: 18.r),
                                  ),
                                  IconButton(
                                    tooltip: 'Add slide',
                                    onPressed: () => _addMedia(slide: true),
                                    icon: Icon(Iconsax.gallery, size: 18.r),
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
                            scrollPadding: EdgeInsets.all(24.r),
                            style: TextStyle(fontSize: 14.r, height: 1.5),
                            decoration: InputDecoration(
                              hintText: 'Write your update here...',
                              hintStyle:
                                  TextStyle(color: Colors.grey, fontSize: 14.r),
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
                                    : _FeedRichText(
                                        text: _body.text,
                                        style: TextStyle(
                                            fontSize: 14.r, height: 1.5)),
                                _composerMediaPreview(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_preview) _composerMediaPreview(),
                  SizedBox(height: 8.r),
                  Text('Use the toolbar for emphasis, bullets, and quotes.',
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
                    onPressed: _saving || !_canPublish ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandAccent),
                    child: _saving
                        ? SizedBox(
                            width: 18.r,
                            height: 18.r,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.r, color: Colors.white))
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
  late final JsonCacheStore _cache;
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
    _cache = context.read<JsonCacheStore>();
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

  Future<void> _deletePost() async {
    final org = _prefs.activeOrganizationId;
    if (org == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete post?',
      message: 'This post will be removed from the feed for everyone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Iconsax.trash,
    );
    if (!confirmed || !mounted) return;
    try {
      await _api.dio.delete(
          '/organizations/$org/feeds/${widget.feedId}/posts/${widget.postId}');
      await _cache.clearKey(_cache.scopedKey(
          'feed-posts:$org:${_prefs.activeBranchId}:${widget.feedId}'));
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete post.')));
      }
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
    final isAuthor = user['id']?.toString() == _cache.userId ||
        member['user_id']?.toString() == _cache.userId;
    final canEdit = isAuthor ||
        _prefs.hasPermission('FEED_UPDATE') ||
        _prefs.hasPermission('FEED_MODERATE');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
          onBack: () => context.pop(),
          menuItems: [
            if (canEdit)
              const DailioMenuItem(
                  value: 'edit', icon: Iconsax.edit_2, label: 'Edit post'),
            if (canEdit)
              const DailioMenuItem(
                  value: 'delete', icon: Iconsax.trash, label: 'Delete post'),
            const DailioMenuItem(
                value: 'report', icon: Iconsax.flag, label: 'Report post')
          ],
          onMenuSelected: (value) {
            if (value == 'edit') {
              context.push(AppRoutes.feedPostEdit
                  .replaceFirst(':feedId', widget.feedId)
                  .replaceFirst(':postId', widget.postId));
            }
            if (value == 'delete') _deletePost();
            if (value == 'report') _report();
          }),
      body: _loading
          ? const FeedPostDetailSkeleton()
          : post == null
              ? const Center(child: Text('Post unavailable'))
              : Column(children: [
                  Expanded(
                      child: ListView(
                          padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 16.r),
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
                          SizedBox(width: 10.r),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(user['name']?.toString() ?? 'Member',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(_date(post['created_at']),
                                    style: TextStyle(
                                        fontSize: 12.r,
                                        color: Colors.grey.shade600))
                              ]))
                        ]),
                        SizedBox(height: 18.r),
                        Text(post['title']?.toString() ?? '',
                            style: TextStyle(
                                fontSize: 18.r, fontWeight: FontWeight.w700)),
                        SizedBox(height: 8.r),
                        _FeedRichText(
                            text: post['body']?.toString() ?? '',
                            style: TextStyle(fontSize: 15.r, height: 1.45)),
                        _FeedContentMedia(post: post, maxItems: null),
                        SizedBox(height: 18.r),
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
                          SizedBox(width: 18.r),
                          Icon(Iconsax.message_text, size: 19.r),
                          SizedBox(width: 5.r),
                          Text(
                              '${(post['_count'] is Map ? post['_count']['comments'] : 0) ?? 0}')
                        ]),
                        SizedBox(height: 22.r),
                        Text('Comments',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17.r)),
                        SizedBox(height: 12.r),
                        if (_comments.isEmpty)
                          Text('No comments yet.',
                              style: TextStyle(color: Colors.grey.shade600))
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
                                  controller: _comment,
                                  decoration: InputDecoration(
                                      isDense: true,
                                      hintText: _replyTo == null
                                          ? 'Write a comment'
                                          : 'Reply to comment',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(22.r)))),
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
        padding: EdgeInsets.only(bottom: 14.r),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _FeedAvatar(
              url: user['avatar_url']?.toString(),
              name: user['name']?.toString() ?? 'Member',
              size: 30.r,
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
          SizedBox(width: 8.r),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(user['name']?.toString() ?? 'Member',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13.r)),
                Text(comment['body']?.toString() ?? '',
                    style: TextStyle(fontSize: 13.r)),
                if (comment['pending'] == true)
                  Text('Sending…',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 10.r))
                else
                  TextButton(
                      onPressed: () =>
                          setState(() => _replyTo = comment['id']?.toString()),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero, minimumSize: Size(0, 22.r)),
                      child: Text('Reply', style: TextStyle(fontSize: 12.r)))
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
      padding: EdgeInsets.only(top: 10.r),
      child: Column(
        children: visible
            .map((block) => _FeedMediaPlaceholder(
                  storageKey: block['storage_key']?.toString(),
                  feedId: post['feed_id']?.toString(),
                  postId: post['id']?.toString(),
                  mediaUrl: block['media_url']?.toString(),
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
  final String? mediaUrl;
  final String? format;
  final String? alt;
  const _FeedMediaPlaceholder({
    this.storageKey,
    this.feedId,
    this.postId,
    this.mediaUrl,
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
    _url = widget.mediaUrl;
    if (_url == null || _url!.isEmpty) _load();
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
            SizedBox(
                width: 18.r,
                height: 18.r,
                child: CircularProgressIndicator(
                    strokeWidth: 2.r, color: AppColors.brandAccent)),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: _url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: _url!,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => AspectRatio(
                aspectRatio: 1.65,
                child: Container(
                  color: const Color(0xFFF7F7F7),
                  alignment: Alignment.center,
                  child: Icon(Iconsax.image,
                      color: Colors.grey.shade400, size: 20.r),
                ),
              ),
            ),
    );
  }
}

class _FeedPostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;
  final VoidCallback onReact;
  const _FeedPostTile(
      {required this.post, required this.onTap, required this.onReact});
  @override
  Widget build(BuildContext context) {
    final member = post['member'] is Map
        ? Map<String, dynamic>.from(post['member'])
        : <String, dynamic>{};
    final user = member['user'] is Map
        ? Map<String, dynamic>.from(member['user'])
        : <String, dynamic>{};
    final reactions =
        (post['_count'] is Map ? post['_count']['reactions'] : 0) as num? ?? 0;
    final comments =
        (post['_count'] is Map ? post['_count']['comments'] : 0) as num? ?? 0;
    final previews =
        (post['comments'] is List ? post['comments'] as List : const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: EdgeInsets.only(bottom: 12.r),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                name: user['name']?.toString() ?? 'Member',
                                avatarUrl: user['avatar_url']?.toString(),
                              ),
                            )),
                SizedBox(width: 9.r),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(user['name']?.toString() ?? 'Member',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.r)),
                      Text(_date(post['created_at']),
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 11.r)),
                    ])),
                Icon(Iconsax.more, size: 18.r),
              ]),
              SizedBox(height: 8.r),
              Text(post['title']?.toString() ?? 'Post',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 16.r)),
              SizedBox(height: 4.r),
              _FeedRichText(
                  text: post['body']?.toString() ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade800, height: 1.35)),
              _FeedContentMedia(post: post, maxItems: null),
              SizedBox(height: 7.r),
              Row(children: [
                InkWell(
                    onTap: onReact,
                    child: Row(children: [
                      Icon(
                          post['my_reaction'] == 'LIKE'
                              ? Iconsax.heart5
                              : Iconsax.heart,
                          size: 20.r,
                          color: post['my_reaction'] == 'LIKE'
                              ? AppColors.brandAccent
                              : Colors.black87),
                      SizedBox(width: 5.r),
                      Text('$reactions', style: TextStyle(fontSize: 12.r)),
                    ])),
                SizedBox(width: 18.r),
                InkWell(
                    onTap: onTap,
                    child: Row(children: [
                      Icon(Iconsax.message_text, size: 19.r),
                      SizedBox(width: 5.r),
                      Text('$comments', style: TextStyle(fontSize: 12.r)),
                    ])),
                const Spacer(),
                Text('View details',
                    style: TextStyle(
                        color: AppColors.brandAccent,
                        fontSize: 12.r,
                        fontWeight: FontWeight.w600)),
              ]),
              if (previews.isNotEmpty) ...[
                SizedBox(height: 10.r),
                ...previews
                    .map((comment) => _FeedCommentPreview(comment: comment)),
              ],
              SizedBox(height: 12.r),
              Divider(height: 1.r, color: Colors.grey.shade200),
            ])));
  }
}

class _FeedCommentPreview extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _FeedCommentPreview({required this.comment});

  @override
  Widget build(BuildContext context) {
    final member = comment['member'] is Map
        ? Map<String, dynamic>.from(comment['member'])
        : <String, dynamic>{};
    final user = member['user'] is Map
        ? Map<String, dynamic>.from(member['user'])
        : <String, dynamic>{};
    return Padding(
      padding: EdgeInsets.only(bottom: 5.r),
      child: Row(children: [
        _FeedAvatar(
            url: user['avatar_url']?.toString(),
            name: user['name']?.toString() ?? 'Member',
            size: 20.r),
        SizedBox(width: 7.r),
        Expanded(
            child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${user['name']?.toString() ?? 'Member'}  ',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: comment['body']?.toString() ?? ''),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.r, color: Colors.grey.shade800))),
      ]),
    );
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
              style: TextStyle(fontSize: 12.r, fontWeight: FontWeight.w500)),
          SizedBox(height: 7.r),
          TextField(
            controller: controller,
            maxLines: 1,
            keyboardType:
                label.contains('minute') || label.contains('threshold')
                    ? TextInputType.number
                    : null,
            style: TextStyle(fontSize: 13.r),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(fontSize: 13.r, color: Colors.grey),
              prefixIcon: Icon(Iconsax.edit_2, size: 16.r),
              alignLabelWithHint: false,
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

class _FeedAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double? size;
  final VoidCallback? onTap;
  const _FeedAvatar({
    required this.url,
    required this.name,
    this.size,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final avatarSize = size ?? 42.r;
    final avatar = CircleAvatar(
      radius: avatarSize / 2,
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
        padding: EdgeInsets.symmetric(vertical: 8.r),
        child: Row(
          children: [
            CircleAvatar(radius: 18.r, backgroundColor: Color(0xFFF0F0F0)),
            SizedBox(width: 10.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(width: 140.r),
                  SizedBox(height: 7.r),
                  _SkeletonLine(width: 82.r),
                ],
              ),
            ),
            Container(
              width: 20.r,
              height: 20.r,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(5.r),
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
      padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 80.r),
      itemCount: 5,
      separatorBuilder: (_, __) => Divider(height: 1.r),
      itemBuilder: (_, __) =>
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 21.r, backgroundColor: Color(0xFFF0F0F0)),
            SizedBox(width: 10.r),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _SkeletonLine(width: 130.r),
                  SizedBox(height: 9.r),
                  _SkeletonLine(width: double.infinity),
                  SizedBox(height: 7.r),
                  _SkeletonLine(width: 220.r),
                  SizedBox(height: 10.r),
                  _SkeletonLine(width: 80.r)
                ]))
          ]));
}

class FeedPostDetailSkeleton extends StatelessWidget {
  const FeedPostDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 32.r),
        children: [
          Row(
            children: [
              CircleAvatar(radius: 21.r, backgroundColor: Color(0xFFF0F0F0)),
              SizedBox(width: 10.r),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(width: 130.r),
                  SizedBox(height: 8.r),
                  _SkeletonLine(width: 85.r),
                ],
              ),
            ],
          ),
          SizedBox(height: 22.r),
          _SkeletonLine(width: 220.r),
          SizedBox(height: 12.r),
          const _SkeletonLine(width: double.infinity),
          SizedBox(height: 8.r),
          const _SkeletonLine(width: double.infinity),
          SizedBox(height: 8.r),
          _SkeletonLine(width: 160.r),
          SizedBox(height: 26.r),
          _SkeletonLine(width: 95.r),
        ],
      );
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  const _SkeletonLine({required this.width});
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: 11.r,
      decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8.r)));
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(top: 100.r),
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
        SizedBox(height: 8.r),
        Text(text),
        TextButton(onPressed: action, child: const Text('Retry'))
      ]));
}

String _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return parsed == null ? '' : DateFormat('d MMM, h:mm a').format(parsed);
}
