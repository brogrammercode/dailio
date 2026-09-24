DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

class PlanModel {
  final String id;
  final String name;
  final String? description;
  final int durationDays;
  final int amountMinorUnit;
  final int joiningFeeMinor;
  final String currency;
  final bool isActive;
  final String? branchId;

  const PlanModel({
    required this.id,
    required this.name,
    this.description,
    required this.durationDays,
    required this.amountMinorUnit,
    required this.joiningFeeMinor,
    required this.currency,
    required this.isActive,
    this.branchId,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) => PlanModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
        amountMinorUnit: (json['amount_minor_unit'] as num?)?.toInt() ?? 0,
        joiningFeeMinor: (json['joining_fee_minor'] as num?)?.toInt() ?? 0,
        currency: json['currency']?.toString() ?? 'INR',
        isActive: json['is_active'] != false,
        branchId: json['branch_id']?.toString(),
      );
}

class LedgerEntryModel {
  final String id;
  final String category;
  final int amountMinorUnit;
  final String currency;
  final String? description;
  final DateTime? createdAt;
  final List<PaymentAllocationModel> allocations;

  const LedgerEntryModel({
    required this.id,
    required this.category,
    required this.amountMinorUnit,
    required this.currency,
    this.description,
    this.createdAt,
    this.allocations = const [],
  });

  factory LedgerEntryModel.fromJson(Map<String, dynamic> json) =>
      LedgerEntryModel(
        id: json['id']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        amountMinorUnit: (json['amount_minor_unit'] as num?)?.toInt() ?? 0,
        currency: json['currency']?.toString() ?? 'INR',
        description: json['description']?.toString(),
        createdAt: _date(json['created_at']),
        allocations: ((json['allocations'] as List?) ?? const [])
            .map((item) => PaymentAllocationModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}

class SubscriptionModel {
  final String id;
  final String memberId;
  final String planId;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int agreedAmountMinor;
  final int discountMinor;
  final String currency;
  final PlanModel? plan;
  final List<LedgerEntryModel> ledgerEntries;

  const SubscriptionModel({
    required this.id,
    required this.memberId,
    required this.planId,
    required this.status,
    this.startDate,
    this.endDate,
    required this.agreedAmountMinor,
    required this.discountMinor,
    required this.currency,
    this.plan,
    this.ledgerEntries = const [],
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionModel(
        id: json['id']?.toString() ?? '',
        memberId: json['member_id']?.toString() ?? '',
        planId: json['plan_id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'UNKNOWN',
        startDate: _date(json['start_date']),
        endDate: _date(json['end_date']),
        agreedAmountMinor: (json['agreed_amount_minor'] as num?)?.toInt() ?? 0,
        discountMinor: (json['discount_minor'] as num?)?.toInt() ?? 0,
        currency: json['currency']?.toString() ?? 'INR',
        plan: json['plan'] is Map
            ? PlanModel.fromJson(Map<String, dynamic>.from(json['plan'] as Map))
            : null,
        ledgerEntries: ((json['ledger_entries'] as List?) ?? const [])
            .map((item) => LedgerEntryModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}

class PaymentEvidenceModel {
  final String id;
  final String storageKey;
  final String contentType;
  final int? sizeBytes;
  final DateTime? createdAt;

  const PaymentEvidenceModel({
    required this.id,
    required this.storageKey,
    required this.contentType,
    this.sizeBytes,
    this.createdAt,
  });

  factory PaymentEvidenceModel.fromJson(Map<String, dynamic> json) =>
      PaymentEvidenceModel(
        id: json['id']?.toString() ?? '',
        storageKey: json['storage_key']?.toString() ?? '',
        contentType: json['content_type']?.toString() ?? '',
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
        createdAt: _date(json['created_at']),
      );
}

class ReceiptModel {
  final String id;
  final String receiptNumber;
  final DateTime? issuedAt;

  const ReceiptModel(
      {required this.id, required this.receiptNumber, this.issuedAt});

  factory ReceiptModel.fromJson(Map<String, dynamic> json) => ReceiptModel(
        id: json['id']?.toString() ?? '',
        receiptNumber: json['receipt_number']?.toString() ?? '',
        issuedAt: _date(json['issued_at']),
      );
}

class PaymentModel {
  final String id;
  final int amountMinorUnit;
  final String currency;
  final String method;
  final String status;
  final DateTime? postedAt;
  final ReceiptModel? receipt;

  const PaymentModel({
    required this.id,
    required this.amountMinorUnit,
    required this.currency,
    required this.method,
    required this.status,
    this.postedAt,
    this.receipt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json['id']?.toString() ?? '',
        amountMinorUnit: (json['amount'] as num?)?.toInt() ??
            (json['amount_minor_unit'] as num?)?.toInt() ??
            0,
        currency: json['currency']?.toString() ?? 'INR',
        method: json['method']?.toString() ?? '',
        status: json['status']?.toString() ?? 'PENDING',
        postedAt: _date(json['posted_at']),
        receipt: json['receipt'] is Map
            ? ReceiptModel.fromJson(
                Map<String, dynamic>.from(json['receipt'] as Map))
            : null,
      );
}

class PaymentAllocationModel {
  final String id;
  final int allocatedAmount;
  final PaymentModel? payment;

  const PaymentAllocationModel(
      {required this.id, required this.allocatedAmount, this.payment});

  factory PaymentAllocationModel.fromJson(Map<String, dynamic> json) =>
      PaymentAllocationModel(
        id: json['id']?.toString() ?? '',
        allocatedAmount: (json['allocated_amount'] as num?)?.toInt() ?? 0,
        payment: json['payment_attempt'] is Map
            ? PaymentModel.fromJson(
                Map<String, dynamic>.from(json['payment_attempt'] as Map))
            : null,
      );
}
