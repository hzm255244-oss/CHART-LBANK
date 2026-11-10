import 'package:flutter/material.dart';

enum PnlFibSide { long, short }

class PnlFibLevel {
  final double price;
  final double priceChangePercent;
  final double pnl;
  final double marginRoiPercent;

  const PnlFibLevel({
    required this.price,
    required this.priceChangePercent,
    required this.pnl,
    required this.marginRoiPercent,
  });
}

/// Calculator for linear USDT-margined contracts.
///
/// positionValueUsd is the notional value at entry, not the margin.
/// Contract multiplier/quantity and fees are intentionally not guessed here.
class PnlFibonacciCalculator {
  static List<PnlFibLevel> calculate({
    required double entryPrice,
    required double positionValueUsd,
    required double leverage,
    required PnlFibSide side,
    required List<double> percentages,
  }) {
    if (!entryPrice.isFinite || entryPrice <= 0 ||
        !positionValueUsd.isFinite || positionValueUsd <= 0 ||
        !leverage.isFinite || leverage <= 0) {
      return const [];
    }

    final margin = positionValueUsd / leverage;
    final sorted = percentages
        .where((p) => p.isFinite && p > 0 && p < 100)
        .toSet()
        .toList()
      ..sort();

    final levels = <PnlFibLevel>[
      PnlFibLevel(
        price: entryPrice,
        priceChangePercent: 0,
        pnl: 0,
        marginRoiPercent: 0,
      ),
    ];

    for (final percent in sorted) {
      for (final direction in const [-1.0, 1.0]) {
        final signedPriceChange = percent * direction;
        final price = entryPrice * (1 + signedPriceChange / 100);
        final tradeDirection = side == PnlFibSide.long ? 1.0 : -1.0;
        final pnl = positionValueUsd *
            (signedPriceChange / 100) * tradeDirection;
        levels.add(PnlFibLevel(
          price: price,
          priceChangePercent: signedPriceChange,
          pnl: pnl,
          marginRoiPercent: margin > 0 ? pnl / margin * 100 : 0,
        ));
      }
    }

    levels.sort((a, b) => a.price.compareTo(b.price));
    return levels;
  }
}

/// First implementation stage: configurable calculation panel.
/// The chart overlay will consume the same calculator once the native
/// LBank Futures candle chart exposes its price/time coordinate transform.
class PnlFibonacciTool extends StatefulWidget {
  const PnlFibonacciTool({super.key, this.initialPrice = 0});

  final double initialPrice;

  @override
  State<PnlFibonacciTool> createState() => _PnlFibonacciToolState();
}

class _PnlFibonacciToolState extends State<PnlFibonacciTool> {
  late final TextEditingController _entry;
  final _value = TextEditingController(text: '1000');
  final _leverage = TextEditingController(text: '10');
  final _levels = TextEditingController(text: '1, 2');
  PnlFibSide _side = PnlFibSide.long;

  @override
  void initState() {
    super.initState();
    _entry = TextEditingController(
      text: widget.initialPrice > 0 ? widget.initialPrice.toString() : '',
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _value.dispose();
    _leverage.dispose();
    _levels.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  String _money(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)} USDT';

  @override
  Widget build(BuildContext context) {
    final percentages = _levels.text
        .split(RegExp(r'[,;\\s]+'))
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();
    final rows = PnlFibonacciCalculator.calculate(
      entryPrice: _parse(_entry),
      positionValueUsd: _parse(_value),
      leverage: _parse(_leverage),
      side: _side,
      percentages: percentages,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E222D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PnL Fibonacci',
                style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('ارزش پوزیشن، قیمت ورود و درصد سطوح را وارد کن.',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 14),
              _field(_entry, 'قیمت ورود'),
              _field(_value, 'ارزش کل پوزیشن (USDT)'),
              _field(_leverage, 'اهرم'),
              _field(_levels, 'درصد سطوح؛ با ویرگول جدا کن (مثلاً 1, 2, 3)'),
              const SizedBox(height: 8),
              DropdownButtonFormField<PnlFibSide>(
                value: _side,
                dropdownColor: const Color(0xFF131722),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'جهت معامله',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                ),
                items: const [
                  DropdownMenuItem(value: PnlFibSide.long, child: Text('خرید (Long)')),
                  DropdownMenuItem(value: PnlFibSide.short, child: Text('فروش (Short)')),
                ],
                onChanged: (v) => setState(() => _side = v ?? _side),
              ),
              const SizedBox(height: 16),
              const Text('سطوح محاسبه‌شده',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Text('برای نمایش سطوح، قیمت ورود و ارزش پوزیشن معتبر وارد کن.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12))
              else
                ...rows.map((level) {
                  final isZero = level.priceChangePercent == 0;
                  final color = isZero ? Colors.amber :
                      level.pnl >= 0 ? const Color(0xFF26A69A) :
                      const Color(0xFFEF5350);
                  final percent = level.priceChangePercent;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131722),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: color.withValues(alpha: .55)),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(
                        isZero ? '۰٪ · ورود' :
                          '${percent > 0 ? '+' : ''}${percent.toStringAsFixed(2)}٪',
                        style: TextStyle(color: color, fontSize: 12))),
                      Expanded(child: Text(level.price.toStringAsFixed(4),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 12))),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(isZero ? 'سر‌به‌سر' : _money(level.pnl),
                            style: TextStyle(color: color, fontSize: 12,
                              fontWeight: FontWeight.bold)),
                          Text('${level.marginRoiPercent.toStringAsFixed(2)}٪ مارجین',
                            style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      )),
                    ]),
                  );
                }),
              const SizedBox(height: 8),
              const Text(
                'محاسبه تقریبی قرارداد خطی USDT است؛ کارمزد، فاندینگ، لغزش قیمت و ضریب اختصاصی قرارداد لحاظ نشده‌اند. اهرم فقط مارجین و بازدهی نسبت به مارجین را تغییر می‌دهد، نه PnL دلاری را.',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true, signed: false),
          style: const TextStyle(color: Colors.white),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF131722),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF26A69A))),
          ),
        ),
      );
}
