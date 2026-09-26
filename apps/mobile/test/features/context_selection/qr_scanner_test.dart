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
}
