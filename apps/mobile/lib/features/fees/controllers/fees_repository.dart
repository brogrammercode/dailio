import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/fee_models.dart';

class FeesRepository {
  final ApiClient apiClient;

  FeesRepository({required this.apiClient});

  Future<Map<String, dynamic>> _getContext(String branchId, String path,
      {Map<String, dynamic>? query}) async {
    final response = await apiClient.dio
        .get('/branches/$branchId/$path', queryParameters: query);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<FeeCardModel>> listFees(
    String branchId, {
    String period = 'this_month',
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final data = await _getContext(branchId, 'fees', query: {
      'period': period,
      if (from != null) 'from': _dateOnly(from),
      if (to != null) 'to': _dateOnly(to),
      if (status != null) 'status': status,
    });
    return ((data['data'] as List?) ?? const [])
        .map((item) =>
            FeeCardModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<List<PaymentRequestModel>> listPaymentRequests(String branchId,
      {String? status}) async {
    final data = await _getContext(branchId, 'payment-requests', query: {
      if (status != null) 'status': status,
    });
    return ((data['data'] as List?) ?? const [])
        .map((item) => PaymentRequestModel.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> getPaymentRequest(
      String branchId, String requestId) async {
    return _getContext(branchId, 'payment-requests/$requestId');
  }

  Future<Map<String, dynamic>> createPaymentRequest(
    String branchId,
    Map<String, dynamic> data, {
    required String idempotencyKey,
  }) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/payment-requests',
      data: data,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createEvidenceUploadSignature(
      String branchId, String filename, String contentType) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/payment-evidence/upload-signature',
      data: {'filename': filename, 'content_type': contentType},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> reviewPaymentRequest(
    String branchId,
    String requestId,
    String action, {
    String? reason,
  }) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/payment-requests/$requestId/$action',
      data: {if (reason != null) 'reason': reason},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getReceipt(
      String branchId, String paymentAttemptId) async {
    final response = await apiClient.dio
        .get('/branches/$branchId/payment-attempts/$paymentAttemptId/receipt');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> getEvidenceDownloadUrl(
      String branchId, String requestId, String evidenceId) async {
    final response = await apiClient.dio.get(
        '/branches/$branchId/payment-requests/$requestId/evidence/$evidenceId/download');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> transitionSubscription(String branchId,
      String subscriptionId, String action, String reason) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/subscriptions/$subscriptionId/$action',
      data: {'reason': reason},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> renewSubscription(
      String branchId, String subscriptionId, String startDate,
      {required String idempotencyKey}) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/subscriptions/$subscriptionId/renew',
      data: {'start_date': startDate},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }
}
