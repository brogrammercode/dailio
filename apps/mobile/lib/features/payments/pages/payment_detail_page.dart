import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../fees/controllers/fees_repository.dart';
import '../../fees/models/fee_models.dart';

class PaymentDetailPage extends StatefulWidget {
  final String requestId;

  const PaymentDetailPage({super.key, required this.requestId});

  @override
  State<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends State<PaymentDetailPage> {
  bool _loading = true;
  String? _error;
  PaymentRequestModel? _request;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final branchId = context.read<PreferencesStorage>().activeBranchId;
    if (branchId == null) {
      setState(() {
        _loading = false;
        _error = 'Select an active branch to view this payment.';
      });
      return;
    }
    try {
      final response = await context
          .read<FeesRepository>()
          .getPaymentRequest(branchId, widget.requestId);
      final data = (response['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) throw Exception('Payment details are unavailable');
      if (!mounted) return;
      setState(() {
        _request = PaymentRequestModel.fromJson(data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
            title: const Text('Payment details'),
            backgroundColor: Colors.white,
            elevation: 0),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_content(_request!)],
                    ),
                  ),
      );

  Widget _content(PaymentRequestModel request) {
    final name = request.memberName ?? 'Member';
    final avatar = request.memberAvatarUrl;
    final color = _statusColor(request.status);
    final payment = request.payment;
    final receipt = payment?.receipt;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.indigo.shade100,
                backgroundImage: avatar == null || avatar.isEmpty
                    ? null
                    : NetworkImage(avatar),
                child: avatar == null || avatar.isEmpty
                    ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(request.planName ?? 'Subscription payment'),
                  ])),
              _statusBadge(request.status, color),
            ]),
            const Divider(height: 28),
            _amountLine('Payment amount', request.signedAmountMinorUnit,
                request.currency,
                strong: true),
            if (payment != null)
              _amountLine('Confirmed payment', -payment.amountMinorUnit,
                  payment.currency),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _section('Payment information', [
        _detail('Method', request.method),
        _detail('Status', request.status.replaceAll('_', ' ')),
        _detail('Reference', request.reference ?? 'Not provided'),
        if (request.note != null && request.note!.isNotEmpty)
          _detail('Note', request.note!),
        _detail('Submitted', _dateTime(request.createdAt)),
        if (payment != null) _detail('Posted', _dateTime(payment.postedAt)),
        if (request.reason != null && request.reason!.isNotEmpty)
          _detail('Reviewer note', request.reason!),
      ]),
      const SizedBox(height: 12),
      _section('Receipt', [
        if (receipt == null)
          const Text('Receipt will appear here after the payment is approved.')
        else ...[
          _detail('Receipt number', receipt.receiptNumber),
          _detail('Issued', _dateTime(receipt.issuedAt)),
          _detail('Payment status', payment!.status),
        ],
      ]),
      const SizedBox(height: 12),
      _section('Evidence', [
        if (request.evidence.isEmpty)
          const Text('No evidence attached.')
        else
          ...request.evidence.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file),
                title: Text(item.contentType),
                subtitle: Text(
                    '${item.sizeBytes == null ? '' : '${(item.sizeBytes! / 1024).ceil()} KB • '}${_dateTime(item.createdAt)}'),
              )),
      ]),
      if (request.planName != null) ...[
        const SizedBox(height: 12),
        _section('Subscription', [
          _detail('Plan', request.planName!),
          const Text(
              'This payment is linked to the subscription plan shown above.'),
        ]),
      ],
    ]);
  }

  Widget _section(String title, List<Widget> children) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );

  Widget _amountLine(String label, int minor, String currency,
          {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label),
          Text(_money(minor, currency),
              style: TextStyle(fontWeight: strong ? FontWeight.bold : null)),
        ]),
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 112,
              child: Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value)),
        ]),
      );

  Widget _statusBadge(String status, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(status.replaceAll('_', ' '),
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      );

  Color _statusColor(String status) => switch (status) {
        'APPROVED' => Colors.green.shade700,
        'REJECTED' => Colors.red.shade700,
        'NEEDS_INFORMATION' => Colors.orange.shade800,
        'CANCELLED' => Colors.grey.shade700,
        _ => Colors.blue.shade700,
      };

  String _money(int minor, String currency) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: '$currency ',
        decimalDigits: 2,
      ).format(minor / 100);

  String _dateTime(DateTime? value) => value == null
      ? 'Not available'
      : DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
}
