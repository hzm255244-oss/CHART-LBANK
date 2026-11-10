import 'dart:convert';
import 'package:http/http.dart' as http;

class LBankFuturesQuote {
  final String symbol;
  final double lastPrice;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final double volume;
  final double markedPrice;
  final DateTime fetchedAt;

  const LBankFuturesQuote({
    required this.symbol,
    required this.lastPrice,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.markedPrice,
    required this.fetchedAt,
  });

  static double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  factory LBankFuturesQuote.fromJson(Map<String, dynamic> json) {
    return LBankFuturesQuote(
      symbol: (json['symbol'] ?? 'GOLDUSDT').toString(),
      lastPrice: _number(json['lastPrice']),
      openPrice: _number(json['openPrice']),
      highPrice: _number(json['highestPrice']),
      lowPrice: _number(json['lowestPrice']),
      volume: _number(json['volume']),
      markedPrice: _number(json['markedPrice']),
      fetchedAt: DateTime.now(),
    );
  }
}

class LBankFuturesService {
  static const String _baseUrl = 'https://lbkperp.lbank.com';
  static const String _productGroup = 'SwapU';
  static const String _targetSymbol = 'GOLDUSDT';

  Future<LBankFuturesQuote> fetchGoldQuote() async {
    final uri = Uri.parse('$_baseUrl/cfd/openApi/v1/pub/marketData')
        .replace(queryParameters: {'productGroup': _productGroup});

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('پاسخ سرور LBank: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final rows = _extractRows(decoded);
    if (rows.isEmpty) {
      throw Exception('LBank داده بازار Futures را برنگرداند.');
    }

    Map<String, dynamic>? gold;
    for (final row in rows) {
      final symbol = (row['symbol'] ?? '').toString().toUpperCase();
      if (symbol == _targetSymbol || symbol == 'GOLDUSDT.P') {
        gold = row;
        break;
      }
    }

    if (gold == null) {
      final available = rows
          .map((e) => (e['symbol'] ?? '').toString())
          .where((s) => s.toUpperCase().contains('GOLD'))
          .take(10)
          .join(', ');
      throw Exception(
        available.isEmpty
            ? 'قرارداد GOLDUSDT در گروه $_productGroup پیدا نشد.'
            : 'نمادهای GOLD برگشتی: $available',
      );
    }

    final quote = LBankFuturesQuote.fromJson(gold);
    if (quote.lastPrice <= 0) {
      throw Exception('قیمت معتبر برای قرارداد GOLD از LBank دریافت نشد.');
    }
    return quote;
  }

  List<Map<String, dynamic>> _extractRows(dynamic decoded) {
    dynamic value = decoded;
    if (value is Map<String, dynamic>) {
      if (value['success'] == false || value['result'] == false) {
        throw Exception(value['msg']?.toString() ?? 'خطای API صرافی');
      }
      value = value['data'] ?? value['list'] ?? value['result'] ?? value;
    }
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      if (value['list'] is List) {
        return (value['list'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (value['symbol'] != null) {
        return [Map<String, dynamic>.from(value)];
      }
    }
    return [];
  }
}
