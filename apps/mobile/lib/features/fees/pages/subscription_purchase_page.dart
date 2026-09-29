import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/interceptors/logging_interceptor.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_picker_field.dart';
import '../../context_selection/controllers/branch_repository.dart';
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
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        menuItems: const [
          DailioMenuItem(
            value: 'close',
            icon: Iconsax.close_circle,
            label: 'Close',
          ),
        ],
        onMenuSelected: (value) {
          if (value == 'close') Navigator.of(context).pop();
        },
      ),
      bottomNavigationBar: _submitBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          _summary(name, currency),
          const SizedBox(height: 22),
          _sectionLabel('PAYMENT DETAILS', 'Submit proof for verification'),
          const SizedBox(height: 10),
          DailioPickerField<String>(
            initialValue: _method,
            decoration: _inputDecoration(
              'UPI (Google Pay, PhonePe, Paytm)',
              Iconsax.card,
            ),
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
          const SizedBox(height: 10),
          TextField(
            controller: _referenceController,
            enabled: !_submitting,
            decoration: _inputDecoration(
              'Transaction / UTR reference number',
              Iconsax.receipt_text,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            enabled: !_submitting,
            maxLines: 1,
            decoration: _inputDecoration('Note (optional)', Iconsax.note_text),
          ),
          const SizedBox(height: 12),
          _evidencePicker(),
          const SizedBox(height: 10),
          _reviewNotice(),
        ],
      ),
    );
  }

  Widget _submitBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7600),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit for review',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Encrypted verification · Branch response within 2 hours',
              style: TextStyle(color: Color(0xFF999999), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(String name, String currency) {
    final amount = (_plan['amount_minor_unit'] as num?)?.toInt() ?? 0;
    final joining = (_plan['joining_fee_minor'] as num?)?.toInt() ?? 0;
    final duration = _plan['duration_days']?.toString() ?? '0';
    final branchName = _branch['name']?.toString() ?? 'Branch';
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORDER SUMMARY',
                      style: TextStyle(
                        color: Color(0xFF8A8A8A),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '$branchName · $duration days validity',
                      style: const TextStyle(
                          color: Color(0xFF6B6B6B), fontSize: 11),
                    ),
                  ],
                ),
              ),
              _badge('Review'),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _line('Plan fee', _money(amount, currency)),
          _line('Admission fee',
              joining == 0 ? 'Free' : _money(joining, currency)),
          if (_discount > 0)
            _line('Discount', '-${_money(_discount, currency)}'),
          const SizedBox(height: 7),
          const Divider(height: 1),
          const SizedBox(height: 11),
          _line('TOTAL PAYABLE', _money(_total, currency), strong: true),
          const SizedBox(height: 4),
          Text(
            'Subscription activates once confirmed by the branch reviewer.',
            style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _evidencePicker() {
    final selected = _evidenceFile;
    return InkWell(
      onTap: _submitting ? null : _pickEvidence,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF2D6AD)),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.document_upload,
                color: Color(0xFFD97706), size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _uploading
                        ? 'Uploading evidence...'
                        : selected == null
                            ? 'Attach payment evidence'
                            : selected.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Optional if a reference ID is provided',
                    style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Iconsax.arrow_right_3,
                color: Color(0xFF6B6B6B), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _reviewNotice() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Iconsax.info_circle, size: 16, color: Color(0xFF6B6B6B)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your subscription stays pending until the branch reviewer confirms the payment.',
                style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 10),
              ),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String title, String subtitle) => Row(
        children: [
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Text(subtitle,
              style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 10)),
        ],
      );

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: Icon(icon, size: 16, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFF8A00), width: 1.5),
        ),
      );

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: const TextStyle(
              color: Color(0xFFD97706),
              fontSize: 9,
              fontWeight: FontWeight.w700),
        ),
      );

  Widget _line(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: strong ? Colors.black : const Color(0xFF6B6B6B),
                    fontSize: strong ? 13 : 11,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.normal)),
            Text(value,
                style: TextStyle(
                    fontSize: strong ? 14 : 11,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w600)),
          ],
        ),
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
        'size_bytes': size,
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
