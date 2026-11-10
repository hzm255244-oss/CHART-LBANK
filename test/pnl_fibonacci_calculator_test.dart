import 'package:flutter_test/flutter_test.dart';
import 'package:chart_lbank/widgets/pnl_fibonacci_tool.dart';

void main() {
  group('PnlFibonacciCalculator', () {
    test('calculates long position profit and loss on both sides', () {
      final levels = PnlFibonacciCalculator.calculate(
        entryPrice: 4000,
        positionValueUsd: 1000,
        leverage: 10,
        side: PnlFibSide.long,
        percentages: [1, 2],
      );

      final plusOne = levels.firstWhere((e) => e.priceChangePercent == 1);
      final minusOne = levels.firstWhere((e) => e.priceChangePercent == -1);
      expect(plusOne.price, 4040);
      expect(plusOne.pnl, 10);
      expect(minusOne.price, 3960);
      expect(minusOne.pnl, -10);
      expect(plusOne.marginRoiPercent, 10);
    });

    test('reverses PnL for short while keeping price levels', () {
      final levels = PnlFibonacciCalculator.calculate(
        entryPrice: 4000,
        positionValueUsd: 1000,
        leverage: 10,
        side: PnlFibSide.short,
        percentages: [1],
      );

      final plusOne = levels.firstWhere((e) => e.priceChangePercent == 1);
      final minusOne = levels.firstWhere((e) => e.priceChangePercent == -1);
      expect(plusOne.pnl, -10);
      expect(minusOne.pnl, 10);
    });

    test('leverage changes margin ROI but not nominal PnL', () {
      final ten = PnlFibonacciCalculator.calculate(
        entryPrice: 100,
        positionValueUsd: 500,
        leverage: 10,
        side: PnlFibSide.long,
        percentages: [2],
      ).firstWhere((e) => e.priceChangePercent == 2);
      final twenty = PnlFibonacciCalculator.calculate(
        entryPrice: 100,
        positionValueUsd: 500,
        leverage: 20,
        side: PnlFibSide.long,
        percentages: [2],
      ).firstWhere((e) => e.priceChangePercent == 2);

      expect(ten.pnl, 10);
      expect(twenty.pnl, 10);
      expect(ten.marginRoiPercent, 20);
      expect(twenty.marginRoiPercent, 40);
    });
  });
}
