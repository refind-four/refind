// PriceLogic (Konzept 4.2.2): Rappen und Franken umrechnen, Schweizer
// Format. Beträge werden überall als ganze Rappen (int) gespeichert, damit
// keine Rundungsfehler wie bei 0.1 + 0.2 entstehen.

/// 200000 → 2000
int rappenToChf(int rappen) => rappen ~/ 100;

/// 2000 → 200000
int chfToRappen(int chf) => chf * 100;

/// Schweizer Format nach N-06: 165000 → «CHF 1'650», 165050 → «CHF 1'650.50».
String formatChf(int rappen) {
  final negative = rappen < 0;
  final abs = rappen.abs();
  final francs = abs ~/ 100;
  final cents = abs % 100;

  // Tausendertrennzeichen ' von rechts her einsetzen.
  final digits = francs.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write("'");
    buffer.write(digits[i]);
  }

  final cent = cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}';
  return 'CHF ${negative ? '-' : ''}$buffer$cent';
}
