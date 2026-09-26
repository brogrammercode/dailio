import 'financial_models.dart';

class FeeCardModel {
  final String memberId;
  final String memberName;
  final String? memberNumber;
  final String? avatarUrl;
  final String status;
  final String? subscriptionId;
  final String? planName;
  final String? subscriptionStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final int balanceMinorUnit;
  final int paidAmountMinorUnit;
  final String currency;
  final int? remainingDays;
  final String? pendingRequestId;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? receiptNumber;
  final String? evidenceStatus;
  final bool paidEarlierCoveringPeriod;

  const FeeCardModel({
    required this.memberId,
    required this.memberName,
    this.memberNumber,
    this.avatarUrl,
    required this.status,
    this.subscriptionId,
    this.planName,
    this.subscriptionStatus,
    this.startDate,
    this.endDate,
    required this.balanceMinorUnit,
    this.paidAmountMinorUnit = 0,
    required this.currency,
    this.remainingDays,
    this.pendingRequestId,
    this.paymentDate,
    this.paymentMethod,
    this.receiptNumber,
    this.evidenceStatus,
    this.paidEarlierCoveringPeriod = false,
  });

  factory FeeCardModel.fromJson(Map<String, dynamic> json) {
    final member = (json['member'] as Map?)?.cast<String, dynamic>() ?? {};
    final subscription =
        (json['subscription'] as Map?)?.cast<String, dynamic>();
    DateTime? date(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());
    return FeeCardModel(
      memberId: member['id']?.toString() ?? '',
      memberName: member['name']?.toString() ?? 'Member',
      memberNumber: member['member_number']?.toString(),
      avatarUrl: member['avatar_url']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      subscriptionId: subscription?['id']?.toString(),
      planName: subscription?['plan_name']?.toString(),
      subscriptionStatus: subscription?['status']?.toString(),
      startDate: date(subscription?['start_date']),
      endDate: date(subscription?['end_date']),
      balanceMinorUnit: (json['balance_minor_unit'] as num?)?.toInt() ?? 0,
      paidAmountMinorUnit:
          (json['paid_amount_minor_unit'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'INR',
      remainingDays: (json['remaining_days'] as num?)?.toInt(),
      pendingRequestId: json['pending_request_id']?.toString(),
      paymentDate: date(json['payment_date']),
      paymentMethod: json['payment_method']?.toString(),
      receiptNumber: json['receipt_number']?.toString(),
      evidenceStatus: json['evidence_status']?.toString(),
      paidEarlierCoveringPeriod: json['paid_earlier_covering_period'] == true,
    );
  }
}

class PaymentRequestModel {
  final String id;
  final String status;
  final int amountMinorUnit;
  final String currency;
  final String method;
  final String? reference;
  final String? note;
  final String? reason;
  final DateTime? createdAt;
  final List<PaymentEvidenceModel> evidence;
  final PaymentModel? payment;
  final String? memberName;
  final String? memberAvatarUrl;
  final String? planName;

  const PaymentRequestModel({
    required this.id,
    required this.status,
    required this.amountMinorUnit,
    required this.currency,
    required this.method,
    this.reference,
    this.note,
    this.reason,
    this.createdAt,
    this.evidence = const [],
    this.payment,
    this.memberName,
    this.memberAvatarUrl,
    this.planName,
  });

  factory PaymentRequestModel.fromJson(Map<String, dynamic> json) {
    final member = (json['member'] as Map?)?.cast<String, dynamic>();
    final user = (member?['user'] as Map?)?.cast<String, dynamic>();
    final subscription =
        (json['subscription'] as Map?)?.cast<String, dynamic>();
    final plan = (subscription?['plan'] as Map?)?.cast<String, dynamic>();
    return PaymentRequestModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'REQUESTED',
      amountMinorUnit: (json['amount_minor_unit'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'INR',
      method: json['method']?.toString() ?? 'UPI',
      reference: json['reference']?.toString(),
      note: json['note']?.toString(),
      reason: json['rejection_reason']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      evidence: ((json['evidence'] as List?) ?? const [])
          .map((item) => PaymentEvidenceModel.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      payment: json['payment_attempt'] is Map
          ? PaymentModel.fromJson(
              Map<String, dynamic>.from(json['payment_attempt'] as Map))
          : null,
      memberName: user?['name']?.toString(),
      memberAvatarUrl: user?['avatar_url']?.toString(),
      planName: plan?['name']?.toString(),
    );
  }

  int get signedAmountMinorUnit => payment?.status == 'SUCCESS'
      ? -payment!.amountMinorUnit
      : amountMinorUnit;
}
