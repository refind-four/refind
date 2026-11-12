import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/logic/price_logic.dart';

void main() {
  test('Schweizer Format nach N-06', () {
    expect(formatChf(165000), "CHF 1'650");
    expect(formatChf(200000), "CHF 2'000");
    expect(formatChf(0), 'CHF 0');
    expect(formatChf(5000), 'CHF 50');
    expect(formatChf(100000000), "CHF 1'000'000");
    expect(formatChf(165050), "CHF 1'650.50");
    expect(formatChf(5), 'CHF 0.05');
  });

  test('Rappen und Franken umrechnen', () {
    expect(chfToRappen(2000), 200000);
    expect(rappenToChf(200000), 2000);
    expect(rappenToChf(199), 1);
  });
}
