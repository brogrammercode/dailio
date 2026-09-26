import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../context_selection/controllers/branch_repository.dart';
import '../../../core/network/interceptors/logging_interceptor.dart';
import '../controllers/fees_repository.dart';

class SubscriptionPurchasePage extends StatefulWidget {
  final Map<String, dynamic> invite;
  const SubscriptionPurchasePage({super.key, required this.invite});

  @override
  State<SubscriptionPurchasePage> createState() =>
      _SubscriptionPurchasePageState();
}

class _SubscriptionPurchasePageState extends State<SubscriptionPurchasePage> {
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  final _requestKey =
      'mobile-purchase-${DateTime.now().toUtc().millisecondsSinceEpoch}';
  String _method = 'UPI';
  XFile? _evidenceFile;
  bool _submitting = false;
  bool _uploading = false;

  Map<String, dynamic> get _plan =>
      (widget.invite['plan'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _branch =>
      (widget.invite['branch'] as Map?)?.cast<String, dynamic>() ?? {};

  int get _discount {
    final amount = (_plan['amount_minor_unit'] as num?)?.toInt() ?? 0;
    final joining = (_plan['joining_fee_minor'] as num?)?.toInt() ?? 0;
    final percent = (_plan['discount_percent'] as num?)?.toDouble() ?? 0;
    return ((amount + joining) * percent / 100).round();
  }

  int get _total =>
      ((_plan['amount_minor_unit'] as num?)?.toInt() ?? 0) +
      ((_plan['joining_fee_minor'] as num?)?.toInt() ?? 0) -
      _discount;

  bool get _isDirectPurchase => widget.invite['direct_plan'] == true;

  @override
  Widget build(BuildContext context) {
    final name = _plan['name']?.toString() ?? 'Subscription plan';
    final currency = _plan['currency']?.toString() ?? 'INR';
    return Scaffold(
      appBar: AppBar(title: const Text('Buy subscription')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _summary(name, currency),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(
                labelText: 'Payment method', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(
                  value: 'BANK_TRANSFER', child: Text('Bank transfer')),
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(value: 'CARD', child: Text('Card')),
            ],
            onChanged: _submitting
                ? null
                : (value) => setState(() => _method = value ?? 'UPI'),
          ),
          const SizedBox(height: 14),
          TextField(
              controller: _referenceController,
              decoration: const InputDecoration(
                  labelText: 'Transaction/reference ID',
                  border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Note (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickEvidence,
            icon: const Icon(Icons.upload_file),
            label: Text(_uploading
                ? 'Uploading evidence...'
                : _evidenceFile == null
                    ? 'Attach payment evidence'
                    : 'Evidence: ${_evidenceFile!.name}'),
          ),
          const SizedBox(height: 8),
          const Text(
              'Your request remains pending until the branch reviewer confirms the payment.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit for review'),
          ),
        ],
      ),
    );
  }

  Widget _summary(String name, String currency) {
    final amount = (_plan['amount_minor_unit'] as num?)?.toInt() ?? 0;
    final joining = (_plan['joining_fee_minor'] as num?)?.toInt() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(
              '${_branch['name'] ?? 'Branch'} • ${_plan['duration_days'] ?? 0} days',
              style: const TextStyle(color: Colors.grey)),
          const Divider(height: 26),
          _line('Plan fee', _money(amount, currency)),
          _line('Admission fee', _money(joining, currency)),
          if (_discount > 0)
            _line('Discount', '-${_money(_discount, currency)}'),
          const Divider(height: 22),
          _line('Total', _money(_total, currency), strong: true),
          const SizedBox(height: 8),
          Text(
              'Start date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _line(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  String _money(int minor, String currency) =>
      '$currency ${(minor / 100).toStringAsFixed(2)}';

  Future<void> _pickEvidence() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _evidenceFile = picked);
  }

  Future<Map<String, dynamic>?> _uploadEvidence(String branchId) async {
    final picked = _evidenceFile;
    if (picked == null) return null;
    final repository = context.read<FeesRepository>();
    final file = File(picked.path);
    final size = await file.length();
    if (size > 20 * 1024 * 1024) {
      throw Exception('Evidence must be smaller than 20 MB');
    }
    setState(() => _uploading = true);
    try {
      final contentType = picked.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
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
      return {
        'storage_key': signature['storage_key'],
        'content_type': contentType,
        'size_bytes': size
      };
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final branchId = _branch['id']?.toString();
    final token = widget.invite['token']?.toString();
    final planId = _plan['id']?.toString();
    if (branchId == null ||
        (!_isDirectPurchase && (token == null || token.isEmpty)) ||
        (_isDirectPurchase && (planId == null || planId.isEmpty))) {
      return;
    }
    if (_referenceController.text.trim().isEmpty && _evidenceFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a reference ID or payment evidence.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final branchRepository = context.read<BranchRepository>();
      final feesRepository = context.read<FeesRepository>();
      final draft = _isDirectPurchase
          ? await branchRepository.createDirectSubscriptionDraft(
              branchId,
              planId!,
              DateTime.now().toUtc().toIso8601String(),
              idempotencyKey: _requestKey,
            )
          : await branchRepository.createSubscriptionDraft(
              token!,
              DateTime.now().toUtc().toIso8601String(),
              idempotencyKey: _requestKey,
            );
      final subscription =
          (draft['subscription'] as Map?)?.cast<String, dynamic>();
      final subscriptionId = (subscription?['id'] ?? draft['id'])?.toString();
      if (subscriptionId == null || subscriptionId.isEmpty) {
        throw Exception('The subscription draft was not created');
      }
      final evidence = await _uploadEvidence(branchId);
      await feesRepository.createPaymentRequest(
        branchId,
        {
          'subscription_id': subscriptionId,
          'amount_minor_unit':
              (draft['total_minor_unit'] as num?)?.toInt() ?? _total,
          'currency': _plan['currency'] ?? 'INR',
          'method': _method,
          if (_referenceController.text.trim().isNotEmpty)
            'reference': _referenceController.text.trim(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
          'evidence': [if (evidence != null) evidence],
        },
        idempotencyKey: '$_requestKey-payment',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment request submitted for review.')));
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not submit request: $error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
