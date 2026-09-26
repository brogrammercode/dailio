import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/interceptors/logging_interceptor.dart';
import '../../../core/storage/preferences_storage.dart';
import '../controllers/fees_repository.dart';
import '../models/fee_models.dart';

class MemberSubscriptionDetailPage extends StatefulWidget {
  final String memberId;
  final String? subscriptionId;

  const MemberSubscriptionDetailPage(
      {super.key, required this.memberId, this.subscriptionId});

  @override
  State<MemberSubscriptionDetailPage> createState() =>
      _MemberSubscriptionDetailPageState();
}

class _MemberSubscriptionDetailPageState
    extends State<MemberSubscriptionDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _subscription;
  List<PaymentRequestModel> _paymentRequests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apiClient = context.read<ApiClient>();
    if (widget.subscriptionId == null) {
      setState(() => _loading = false);
      return;
    }
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) {
      setState(() {
        _loading = false;
        _error = 'No active branch selected.';
      });
      return;
    }
    try {
      final response = await apiClient.dio
          .get('/branches/$branchId/subscriptions/${widget.subscriptionId}');
      if (mounted) {
        setState(() {
          _subscription =
              Map<String, dynamic>.from(response.data['data'] as Map);
          final requests =
              (_subscription?['payment_requests'] as List?) ?? const [];
          _paymentRequests = requests
              .map((item) => PaymentRequestModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList();
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
          title: const Text('Subscription detail'),
          backgroundColor: Colors.white,
          elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_buildContent()])),
    );
  }

  Widget _buildContent() {
    final data = _subscription;
    if (data == null) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No active subscription found.')));
    }
    final plan = (data['plan'] as Map?)?.cast<String, dynamic>();
    final member = (data['member'] as Map?)?.cast<String, dynamic>();
    final user = (member?['user'] as Map?)?.cast<String, dynamic>();
    final avatarUrl = user?['avatar_url']?.toString();
    final memberName = user?['name']?.toString() ?? 'Member';
    final entries =
        (data['ledger_entries'] as List?)?.cast<Map>() ?? const <Map>[];
    final start = _date(data['start_date']);
    final end = _date(data['end_date']);
    final amount = ((data['agreed_amount_minor'] as num?)?.toInt() ?? 0) / 100;
    final outstanding = entries.fold<int>(
        0,
        (sum, entry) =>
            sum + ((entry['amount_minor_unit'] as num?)?.toInt() ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.indigo.shade100,
          backgroundImage: avatarUrl == null || avatarUrl.isEmpty
              ? null
              : NetworkImage(avatarUrl),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(memberName.isEmpty ? '?' : memberName[0].toUpperCase())
              : null,
        ),
        const SizedBox(width: 12),
        Text(memberName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 14),
      _section(
          'Plan',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plan?['name']?.toString() ?? 'Subscription',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Status: ${data['status'] ?? 'UNKNOWN'}'),
            Text('Coverage: $start – $end'),
            Text(NumberFormat.currency(
                    locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2)
                .format(amount)),
          ])),
      const SizedBox(height: 12),
      _paymentSection(outstanding),
      const SizedBox(height: 12),
      _section(
          'Ledger history',
          entries.isEmpty
              ? const Text('No ledger entries found.')
              : Column(
                  children: entries
                      .map((entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry['description']?.toString() ??
                                entry['category']?.toString() ??
                                'Ledger entry'),
                            subtitle: Text(_date(entry['created_at'])),
                            trailing: Text(NumberFormat.currency(
                                    locale: 'en_IN',
                                    symbol: '\u20B9',
                                    decimalDigits: 2)
                                .format(((entry['amount_minor_unit'] as num?)
                                            ?.toInt() ??
                                        0) /
                                    100)),
                          ))
                      .toList())),
    ]);
  }

  Widget _paymentSection(int outstandingMinorUnit) {
    return _section(
        'Payment requests',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_paymentRequests.isEmpty)
            const Text('No payment request has been submitted.'),
          ..._paymentRequests.map((request) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${request.method} • ${_money(request.amountMinorUnit)}'),
                subtitle: Text(
                    '${request.status}${request.reason == null ? '' : ' — ${request.reason}'}'),
                trailing: request.status == 'REQUESTED'
                    ? const Icon(Icons.schedule, color: Colors.orange)
                    : request.payment?.receipt != null
                        ? IconButton(
                            tooltip: 'View receipt',
                            onPressed: () => _viewReceipt(request),
                            icon: const Icon(Icons.receipt_long),
                          )
                        : null,
              )),
          if (outstandingMinorUnit > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showPaymentRequestForm(outstandingMinorUnit),
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                      'Submit payment evidence • ${_money(outstandingMinorUnit)}'),
                )),
          ],
        ]));
  }

  Future<void> _viewReceipt(PaymentRequestModel request) async {
    final paymentId = request.payment?.id;
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (paymentId == null || branchId == null) return;
    try {
      final data =
          await context.read<FeesRepository>().getReceipt(branchId, paymentId);
      if (!mounted) return;
      final receipt = (data['receipt'] as Map?)?.cast<String, dynamic>() ?? {};
      final payment = (data['payment'] as Map?)?.cast<String, dynamic>() ?? {};
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Payment receipt'),
          content: Text(
              'Receipt: ${receipt['receipt_number'] ?? '-'}\nAmount: ${_money((payment['amount_minor_unit'] as num?)?.toInt() ?? 0)}\nMethod: ${payment['method'] ?? '-'}\nIssued: ${_date(receipt['issued_at'])}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Receipt unavailable: $error')));
      }
    }
  }

  Future<void> _showPaymentRequestForm(int outstandingMinorUnit) async {
    final amountController = TextEditingController(
        text: (outstandingMinorUnit / 100).toStringAsFixed(2));
    final referenceController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit payment evidence'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (INR)')),
          TextField(
              controller: referenceController,
              decoration:
                  const InputDecoration(labelText: 'Reference / UPI ID')),
          const SizedBox(height: 8),
          const Text(
              'Add the payment reference so staff can verify the request.',
              style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                    'amount': amountController.text,
                    'reference': referenceController.text
                  }),
              child: const Text('Submit')),
        ],
      ),
    );
    amountController.dispose();
    referenceController.dispose();
    if (result == null || !mounted) return;
    final amount = double.tryParse(result['amount'] ?? '') ?? 0;
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    final subscriptionId = widget.subscriptionId;
    if (branchId == null || subscriptionId == null || amount <= 0) return;
    try {
      final repository = context.read<FeesRepository>();
      final evidence = await _uploadEvidence(repository, branchId);
      final reference = (result['reference'] ?? '').trim();
      if (evidence == null && reference.isEmpty) {
        throw Exception('Attach a receipt or enter a payment reference');
      }
      await repository.createPaymentRequest(
          branchId,
          {
            'subscription_id': subscriptionId,
            'amount_minor_unit': (amount * 100).round(),
            'currency': 'INR',
            'method': 'UPI',
            if (reference.isNotEmpty) 'reference': reference,
            'evidence': [
              if (evidence != null)
                {
                  'storage_key': evidence['storage_key'],
                  'content_type': evidence['content_type'],
                  'size_bytes': evidence['size_bytes'],
                },
            ],
          },
          idempotencyKey:
              'mobile-payment-$subscriptionId-${DateTime.now().toUtc().toIso8601String()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment request submitted for review')));
        _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not submit payment request: $error')));
      }
    }
  }

  Future<Map<String, dynamic>?> _uploadEvidence(
      FeesRepository repository, String branchId) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;
    final file = File(picked.path);
    final sizeBytes = await file.length();
    if (sizeBytes > 20 * 1024 * 1024) {
      throw Exception('Evidence file must be smaller than 20 MB');
    }
    final contentType =
        picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final signature = await repository.createEvidenceUploadSignature(
        branchId, picked.name, contentType);
    final uploadUrl =
        'https://api.cloudinary.com/v1_1/${signature['cloud_name']}/auto/upload';
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: picked.name),
      'api_key': signature['api_key'],
      'timestamp': signature['timestamp'],
      'signature': signature['signature'],
      'folder': signature['folder'],
      'public_id': signature['public_id'],
      'type': signature['type'],
    });
    final uploadDio = Dio()..interceptors.add(LoggingInterceptor());
    final response = await uploadDio.post(uploadUrl,
        data: form, options: Options(contentType: 'multipart/form-data'));
    if (response.statusCode != 200) throw Exception('Evidence upload failed');
    final storageKey = signature['storage_key']?.toString();
    return storageKey == null
        ? null
        : {
            'storage_key': storageKey,
            'content_type': contentType,
            'size_bytes': sizeBytes
          };
  }

  String _money(int minor) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2)
          .format(minor / 100);

  Widget _section(String title, Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        child
      ]));

  String _date(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    return parsed == null
        ? '—'
        : DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }
}
