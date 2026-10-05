import 'package:flutter_test/flutter_test.dart';
import 'package:dailio/core/utils/money_input.dart';

void main() {
  test('money input preserves exact minor units', () {
    expect(parseMoneyMinor('1200.05'), 120005);
    expect(parseMoneyMinor('1.2'), 120);
    expect(formatMoneyInput(120005), '1200.05');
  });
  test('money input rejects invalid amounts', () {
    expect(parseMoneyMinor('0'), isNull);
    expect(parseMoneyMinor('12.345'), isNull);
    expect(parseMoneyMinor('abc'), isNull);
    expect(parseMoneyMinor('21474836.48'), isNull);
  });
}
