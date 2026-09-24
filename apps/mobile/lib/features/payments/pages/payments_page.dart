import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../fees/controllers/fees_repository.dart';
import '../../fees/models/fee_models.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _loading = true;
  String? _error;
  List<PaymentRequestModel> _requests = [];

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
        _error = 'Select an active branch to view payments.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests =
          await context.read<FeesRepository>().listPaymentRequests(branchId);
      if (mounted) {
        setState(() {
          _requests = requests;
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
          title: const Text('Payments'),
          backgroundColor: Colors.white,
          elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _requests.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 180),
                          Center(child: Text('No payment requests yet.'))
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _requests.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) =>
                              _requestCard(_requests[index]),
                        ),
                ),
    );
  }

  Widget _requestCard(PaymentRequestModel request) {
    final color = switch (request.status) {
      'APPROVED' => Colors.green.shade700,
      'REJECTED' => Colors.red.shade700,
      'NEEDS_INFORMATION' => Colors.orange.shade800,
      _ => Colors.blue.shade700,
    };
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        title: Text('${request.method} • ${_money(request.amountMinorUnit)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${request.status.replaceAll('_', ' ')}${request.reference == null ? '' : '\nRef: ${request.reference}'}${request.createdAt == null ? '' : '\n${DateFormat('dd MMM yyyy').format(request.createdAt!.toLocal())}'}'),
        isThreeLine: request.reference != null || request.createdAt != null,
        trailing: Chip(
            label: Text(request.status.replaceAll('_', ' '),
                style: TextStyle(fontSize: 10, color: color)),
            backgroundColor: color.withValues(alpha: .1)),
      ),
    );
  }

  String _money(int minor) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2)
          .format(minor / 100);
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ));
}
