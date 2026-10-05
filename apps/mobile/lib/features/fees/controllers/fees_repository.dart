import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/json_cache_store.dart';
import '../models/fee_models.dart';

class FeesRepository {
  final ApiClient apiClient;
  final JsonCacheStore? cache;

  FeesRepository({required this.apiClient, this.cache});

  Future<Map<String, dynamic>> _getContext(String branchId, String path,
      {Map<String, dynamic>? query,
      void Function(Map<String, dynamic> freshData)? onFresh}) async {
    final queryKey = query == null
        ? ''
        : query.entries.map((entry) => '${entry.key}=${entry.value}').join('&');
    final key = 'branch:$branchId:$path:$queryKey';
    if (cache == null) {
      final response = await apiClient.dio
          .get('/branches/$branchId/$path', queryParameters: query);
      return Map<String, dynamic>.from(response.data as Map);
    }
    return cache!.load<Map<String, dynamic>>(
      key: cache!.scopedKey(key),
      scope: 'branch:$branchId',
      fetch: () async => (await apiClient.dio
              .get('/branches/$branchId/$path', queryParameters: query))
          .data,
      decode: (payload) => Map<String, dynamic>.from(payload as Map),
      onFresh: onFresh,
    );
  }

  Future<List<FeeCardModel>> listFees(
    String branchId, {
    String period = 'this_month',
    DateTime? from,
    DateTime? to,
    String? status,
    void Function(List<FeeCardModel> freshCards)? onFresh,
  }) async {
    List<FeeCardModel> parse(Map<String, dynamic> data) {
      final cards = ((data['data'] as List?) ?? const [])
          .map((item) =>
              FeeCardModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      cards.sort((left, right) {
        int priority(FeeCardModel card) {
          final days = card.remainingDays;
          if (days != null && days >= 0 && days <= 7) return 0;
          if (card.status == 'EXPIRING_SOON') return 0;
          if ((days != null && days < 0) || card.status == 'EXPIRED') return 1;
          return 2;
        }

        final order = priority(left) - priority(right);
        if (order != 0) return order;
        if (left.remainingDays != null && right.remainingDays != null) {
          final days = left.remainingDays! - right.remainingDays!;
          if (priority(left) < 2 && days != 0) return days;
        }
        return left.memberName.compareTo(right.memberName);
      });
      return cards;
    }

    final data = await _getContext(branchId, 'fees',
        query: {
          'period': period,
          if (from != null) 'from': _dateOnly(from),
          if (to != null) 'to': _dateOnly(to),
          if (status != null) 'status': status,
        },
        onFresh: (freshData) => onFresh?.call(parse(freshData)));
    return parse(data);
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<List<PaymentRequestModel>> listPaymentRequests(String branchId,
      {String? status,
      String? period,
      void Function(List<PaymentRequestModel> freshRequests)? onFresh}) async {
    List<PaymentRequestModel> parse(Map<String, dynamic> data) =>
        ((data['data'] as List?) ?? const [])
            .map((item) => PaymentRequestModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
    final data = await _getContext(branchId, 'payment-requests',
        query: {
          if (status != null) 'status': status,
          if (period != null) 'period': period,
        },
        onFresh: (freshData) => onFresh?.call(parse(freshData)));
    return parse(data);
  }

  Future<Map<String, dynamic>> getPaymentRequest(
      String branchId, String requestId) async {
    return _getContext(branchId, 'payment-requests/$requestId');
  }

  Future<Map<String, dynamic>> getSubscription(
      String branchId, String subscriptionId,
      {void Function(Map<String, dynamic> freshData)? onFresh}) async {
    return _getContext(
      branchId,
      'subscriptions/$subscriptionId',
      onFresh: onFresh,
    );
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
    await cache?.clearScope('branch:$branchId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createSettlementWaiver(
    String branchId,
    String subscriptionId,
    int amountMinorUnit,
    String reason,
  ) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/subscriptions/$subscriptionId/settlement-waivers',
      data: {'amount_minor_unit': amountMinorUnit, 'reason': reason},
      options: Options(headers: {
        'Idempotency-Key':
            'mobile-waiver-${DateTime.now().toUtc().microsecondsSinceEpoch}'
      }),
    );
    await cache?.clearScope('branch:$branchId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> listSettlementWaivers(
    String branchId,
    String subscriptionId, {
    int page = 1,
  }) async {
    final response = await apiClient.dio.get(
      '/branches/$branchId/subscriptions/$subscriptionId/settlement-waivers',
      queryParameters: {'page': page, 'limit': 20},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> reverseSettlementWaiver(
    String branchId,
    String subscriptionId,
    String waiverId,
    String reason,
  ) async {
    final response = await apiClient.dio.post(
      '/branches/$branchId/subscriptions/$subscriptionId/settlement-waivers/$waiverId/reverse',
      data: {'reason': reason},
      options: Options(headers: {
        'Idempotency-Key':
            'mobile-waiver-reversal-${DateTime.now().toUtc().microsecondsSinceEpoch}'
      }),
    );
    await cache?.clearScope('branch:$branchId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updatePaymentRequest(
    String branchId,
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.dio.patch(
      '/branches/$branchId/payment-requests/$requestId',
      data: data,
    );
    await cache?.clearScope('branch:$branchId');
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
    await cache?.clearScope('branch:$branchId');
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
    await cache?.clearScope('branch:$branchId');
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
    await cache?.clearScope('branch:$branchId');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }
}
