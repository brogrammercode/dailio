import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final ApiClient _api;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _markingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.dio.get('/notifications');
      final data = response.data['data'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _items = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _markRead(int index) async {
    final item = _items[index];
    if (item['read_at'] != null) return;
    try {
      await _api.dio.patch('/notifications/${item['id']}/read');
      if (mounted) {
        setState(() => _items[index] = {
              ...item,
              'read_at': DateTime.now().toIso8601String()
            });
      }
    } catch (_) {
      // Keep the inbox usable if a read receipt is temporarily offline.
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _api.dio.post('/notifications/read-all');
      if (mounted) {
        setState(() {
          _items = _items
              .map((item) =>
                  {...item, 'read_at': DateTime.now().toIso8601String()})
              .toList();
        });
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: _markingAll ? null : _markAllRead,
            icon: _markingAll
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Iconsax.tick_square, size: 16),
            label: const Text('Mark all read'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Iconsax.refresh),
                      label: const Text('Retry')))
              : _items.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(children: const [
                        SizedBox(height: 240),
                        Center(child: Text('You are all caught up.'))
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => _buildItem(index),
                      ),
                    ),
    );
  }

  Widget _buildItem(int index) {
    final item = _items[index];
    final unread = item['read_at'] == null;
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return InkWell(
      onTap: () => _markRead(index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? Colors.orange.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: unread ? Colors.orange.shade200 : Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(unread ? Iconsax.notification_bing : Iconsax.notification,
                color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title']?.toString() ?? 'Notification',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(item['body']?.toString() ?? '',
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  if (created != null) ...[
                    const SizedBox(height: 6),
                    Text(
                        DateFormat('dd MMM, hh:mm a').format(created.toLocal()),
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ],
              ),
            ),
            if (unread)
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}
