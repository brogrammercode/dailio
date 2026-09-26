import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:dailio/features/context_selection/pages/qr_scanner_page.dart';

void main() {
  test('extracts a token from a Dailio invite QR', () {
    final capture = BarcodeCapture(
      barcodes: [
        const Barcode(rawValue: 'dailio://invite?token=permanent-token'),
      ],
    );

    expect(extractDailioInviteToken(capture), 'permanent-token');
  });

  test('rejects non-Dailio and incomplete QR values', () {
    final capture = BarcodeCapture(
      barcodes: [
        const Barcode(rawValue: 'https://example.com?token=not-an-invite'),
        const Barcode(rawValue: 'dailio://invite'),
      ],
    );

    expect(extractDailioInviteToken(capture), isNull);
  });

  test('maps invite membership states to the correct next flow', () {
    expect(qrInviteFlowState({'joinability': 'JOINABLE'}), 'JOINABLE');
    expect(qrInviteFlowState({'joinability': 'ALREADY_PENDING'}), 'PENDING');
    expect(
        qrInviteFlowState({'joinability': 'MEMBERSHIP_INACTIVE'}), 'INACTIVE');
    expect(qrInviteFlowState({'joinability': 'UNEXPECTED'}), 'UNKNOWN');
    expect(
      qrInviteFlowState({'joinability': 'ALREADY_MEMBER'}),
      'UNKNOWN',
    );
    expect(
      qrInviteFlowState({
        'joinability': 'ALREADY_MEMBER',
        'attendance_action': 'CLOCK_IN',
      }),
      'ACTIVE_CLOCK_IN',
    );
    expect(
      qrInviteFlowState({
        'joinability': 'ALREADY_MEMBER',
        'attendance_action': 'CLOCK_OUT',
      }),
      'ACTIVE_CLOCK_OUT',
    );
    expect(
      qrInviteFlowState({
        'joinability': 'ALREADY_MEMBER',
        'attendance_action': 'ATTENDANCE_DISABLED',
      }),
      'ATTENDANCE_DISABLED',
    );
  });
}
