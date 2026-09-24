import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/fees/models/fee_models.dart';
import 'package:mobile/features/fees/models/financial_models.dart';

void main() {
  test('fee card round-trips server financial fields', () {
    final card = FeeCardModel.fromJson({
      'status': 'EXPIRING_SOON',
      'member': {'id': 'member-1', 'name': 'Adarsh'},
      'subscription': {
        'id': 'sub-1',
        'status': 'ACTIVE',
        'plan_name': 'Three Months',
        'start_date': '2026-01-01T00:00:00.000Z',
        'end_date': '2026-03-31T00:00:00.000Z',
      },
      'balance_minor_unit': 250000,
      'currency': 'INR',
      'remaining_days': 5,
      'payment_date': '2026-01-01T00:00:00.000Z',
      'receipt_number': 'REC-1',
      'evidence_status': 'CONFIRMED',
      'paid_earlier_covering_period': true,
    });

    expect(card.memberName, 'Adarsh');
    expect(card.planName, 'Three Months');
    expect(card.balanceMinorUnit, 250000);
    expect(card.receiptNumber, 'REC-1');
    expect(card.paidEarlierCoveringPeriod, isTrue);
  });

  test('subscription financial models parse allocations and receipt', () {
    final subscription = SubscriptionModel.fromJson({
      'id': 'sub-1',
      'member_id': 'member-1',
      'plan_id': 'plan-1',
      'status': 'ACTIVE',
      'agreed_amount_minor': 100000,
      'discount_minor': 0,
      'currency': 'INR',
      'plan': {'id': 'plan-1', 'name': 'One Month', 'duration_days': 30, 'amount_minor_unit': 100000, 'joining_fee_minor': 10000, 'currency': 'INR', 'is_active': true},
      'ledger_entries': [
        {'id': 'ledger-1', 'category': 'SUBSCRIPTION_CHARGE', 'amount_minor_unit': 100000, 'currency': 'INR', 'allocations': [
          {'id': 'allocation-1', 'allocated_amount': 50000, 'payment_attempt': {'id': 'payment-1', 'amount': 50000, 'currency': 'INR', 'method': 'UPI', 'status': 'SUCCESS', 'receipt': {'id': 'receipt-1', 'receipt_number': 'REC-1'}}},
        ]},
      ],
    });

    expect(subscription.plan?.joiningFeeMinor, 10000);
    expect(subscription.ledgerEntries.single.allocations.single.payment?.receipt?.receiptNumber, 'REC-1');
  });
}
