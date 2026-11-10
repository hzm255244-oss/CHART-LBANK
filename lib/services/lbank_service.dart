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


class LBankBookLevel {
  final double price;
  final double volume;
  final int orders;
  const LBankBookLevel({required this.price, required this.volume, required this.orders});
}

class LBankOrderBook {
  final String symbol;
  final List<LBankBookLevel> bids;
  final List<LBankBookLevel> asks;
  final DateTime fetchedAt;
  const LBankOrderBook({required this.symbol, required this.bids, required this.asks, required this.fetchedAt});
}


class LBankContractInfo {
  final String symbol, baseCurrency, priceCurrency;
  final double priceTick, volumeTick, volumeMultiple;
  final double minOrderVolume, maxOrderVolume, minOrderCost, defaultLeverage;
  const LBankContractInfo({required this.symbol, required this.baseCurrency,
    required this.priceCurrency, required this.priceTick, required this.volumeTick,
    required this.volumeMultiple, required this.minOrderVolume,
    required this.maxOrderVolume, required this.minOrderCost,
    required this.defaultLeverage});
  static double _n(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  factory LBankContractInfo.fromJson(Map<String, dynamic> j) => LBankContractInfo(
    symbol: (j['symbol'] ?? '').toString(),
    baseCurrency: (j['baseCurrency'] ?? '').toString(),
    priceCurrency: (j['priceCurrency'] ?? '').toString(),
    priceTick: _n(j['priceTick']), volumeTick: _n(j['volumeTick']),
    volumeMultiple: _n(j['volumeMultiple']),
    minOrderVolume: _n(j['minOrderVolume']), maxOrderVolume: _n(j['maxOrderVolume']),
    minOrderCost: _n(j['minOrderCost']), defaultLeverage: _n(j['defaultLeverage']));
}


class LBankFuturesInstrument {
  final String symbol, symbolName, baseCurrency, priceCurrency;
  final double priceTick, volumeTick, volumeMultiple, minOrderVolume, maxOrderVolume;
  const LBankFuturesInstrument({required this.symbol, required this.symbolName,
    required this.baseCurrency, required this.priceCurrency, required this.priceTick,
    required this.volumeTick, required this.volumeMultiple, required this.minOrderVolume,
    required this.maxOrderVolume});
  factory LBankFuturesInstrument.fromJson(Map<String,dynamic> j) => LBankFuturesInstrument(
    symbol: (j['symbol'] ?? '').toString(),
    symbolName: (j['symbolName'] ?? j['symbol'] ?? '').toString(),
    baseCurrency: (j['baseCurrency'] ?? '').toString(),
    priceCurrency: (j['priceCurrency'] ?? '').toString(),
    priceTick: LBankContractInfo._n(j['priceTick']),
    volumeTick: LBankContractInfo._n(j['volumeTick']),
    volumeMultiple: LBankContractInfo._n(j['volumeMultiple']),
    minOrderVolume: LBankContractInfo._n(j['minOrderVolume']),
    maxOrderVolume: LBankContractInfo._n(j['maxOrderVolume']));
}

class LBankFuturesService {
  static const String _baseUrl = 'https://lbkperp.lbank.com';
  static const String _productGroup = 'SwapU';
  static const String _targetSymbol = 'GOLDUSDT';




  Future<List<LBankFuturesInstrument>> fetchAllFuturesInstruments() async {
    final uri = Uri.parse('$_baseUrl/cfd/openApi/v1/pub/instrument')
        .replace(queryParameters: {'productGroup': _productGroup});
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('خطای دریافت فهرست قراردادها: HTTP ${response.statusCode}');
    }
    final rows = _extractRows(jsonDecode(response.body));
    final instruments = rows.map(LBankFuturesInstrument.fromJson)
        .where((e) => e.symbol.isNotEmpty).toList()
      ..sort((a,b) => a.symbol.compareTo(b.symbol));
    if (instruments.isEmpty) {
      throw Exception('فهرست قراردادهای Futures خالی است یا پاسخ API قابل‌خواندن نیست.');
    }
    return instruments;
  }

  Future<LBankContractInfo> fetchContractInfo(String symbol) async {
    final uri = Uri.parse('$_baseUrl/cfd/openApi/v1/pub/instrument')
        .replace(queryParameters: {'productGroup': _productGroup});
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('خطای دریافت مشخصات قرارداد: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    dynamic data = decoded;
    if (data is Map) {
      if (data['success'] == false || data['result'] == false) {
        throw Exception(data['msg']?.toString() ?? 'خطای دریافت مشخصات قرارداد');
      }
      data = data['data'] ?? data['list'] ?? data['result'] ?? data;
    }
    final rows = data is List ? data : (data is Map && data['list'] is List
        ? data['list'] as List : [data]);
    for (final row in rows.whereType<Map>()) {
      final candidate = (row['symbol'] ?? '').toString().toUpperCase();
      if (candidate == symbol.toUpperCase() || candidate == '${symbol.toUpperCase()}.P') {
        return LBankContractInfo.fromJson(Map<String, dynamic>.from(row));
      }
    }
    throw Exception('مشخصات قرارداد $symbol در گروه $_productGroup پیدا نشد.');
  }

  Future<LBankOrderBook> fetchOrderBook(String symbol, {int depth = 20}) async {
    final uri = Uri.parse('$_baseUrl/cfd/openApi/v1/pub/marketOrder')
        .replace(queryParameters: {
      'symbol': symbol,
      'depth': depth.toString(),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('خطای دریافت دفتر سفارش: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('ساختار پاسخ دفتر سفارش LBank معتبر نیست.');
    }
    if (decoded['success'] == false || decoded['result'] == false) {
      throw Exception(decoded['msg']?.toString() ?? 'LBank دفتر سفارش را برنگرداند.');
    }
    final data = decoded['data'] is Map ? decoded['data'] as Map : decoded;
    List<LBankBookLevel> parseSide(dynamic value) {
      if (value is! List) return const [];
      return value.whereType<Map>().map((row) {
        return LBankBookLevel(
          price: double.tryParse(row['price']?.toString() ?? '') ?? 0,
          volume: double.tryParse(row['volume']?.toString() ?? '') ?? 0,
          orders: int.tryParse(row['orders']?.toString() ?? '') ?? 0,
        );
      }).where((level) => level.price > 0 && level.volume >= 0).toList();
    }
    final bids = parseSide(data['bids']);
    final asks = parseSide(data['asks']);
    if (bids.isEmpty && asks.isEmpty) {
      throw Exception('دفتر سفارش برای قرارداد $_targetSymbol خالی است.');
    }
    bids.sort((a, b) => b.price.compareTo(a.price));
    asks.sort((a, b) => a.price.compareTo(b.price));
    return LBankOrderBook(
      symbol: symbol,
      bids: bids.take(depth).toList(),
      asks: asks.take(depth).toList(),
      fetchedAt: DateTime.now(),
    );
  }

  Future<LBankFuturesQuote> fetchQuote(String symbol) async {
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
      final candidate = (row['symbol'] ?? '').toString().toUpperCase();
      if (candidate == symbol.toUpperCase() || candidate == '${symbol.toUpperCase()}.P') {
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
            ? 'قرارداد $symbol در گروه $_productGroup پیدا نشد.'
            : 'نمادهای GOLD برگشتی: $available',
      );
    }

    final quote = LBankFuturesQuote.fromJson(gold);
    if (quote.lastPrice <= 0) {
      throw Exception('قیمت معتبر برای قرارداد $symbol از LBank دریافت نشد.');
    }
    return quote;
  }


  Future<LBankContractInfo> fetchGoldContractInfo() => fetchContractInfo(_targetSymbol);
  Future<LBankOrderBook> fetchGoldOrderBook({int depth = 20}) =>
      fetchOrderBook(_targetSymbol, depth: depth);
  Future<LBankFuturesQuote> fetchGoldQuote() => fetchQuote(_targetSymbol);

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
