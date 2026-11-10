import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/lbank_service.dart';
import '../widgets/chart_drawing_canvas.dart';
import '../widgets/pnl_fibonacci_tool.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late final WebViewController _lbankChartController;
  late final TabController _tabController;
  final LBankFuturesService _lbankService = LBankFuturesService();

  Timer? _refreshTimer;
  LBankFuturesQuote? _quote;
  LBankOrderBook? _orderBook;
  LBankContractInfo? _contractInfo;
  List<LBankFuturesInstrument> _instruments = [];
  String _selectedSymbol = 'GOLDUSDT';
  bool _instrumentsLoading = false;
  String? _instrumentsError;
  bool _contractLoading = false;
  String? _contractError;
  bool _quoteLoading = false;
  bool _bookLoading = false;
  String? _bookError;
  String _selectedLBankTimeframe = '15m';
  String _selectedDrawingTool = 'pointer';
  bool _showVolume = true;

  static const List<Map<String, String>> _drawingTools = [
    {'id': 'pointer', 'label': 'انتخاب', 'icon': '☝'},
    {'id': 'measure', 'label': 'Measure', 'icon': '↔'},
    {'id': 'trendline', 'label': 'Trendline', 'icon': '／'},
    {'id': 'crossline', 'label': 'Crossline', 'icon': '＋'},
    {'id': 'fibchannel', 'label': 'Fib Channel', 'icon': '▤'},
    {'id': 'fib_retracement', 'label': 'Fib Retracement', 'icon': 'F'},
    {'id': 'date_price_range', 'label': 'Date & Price Range', 'icon': '↗'},
    {'id': 'text', 'label': 'Text', 'icon': 'T'},
    {'id': 'pin', 'label': 'Pin', 'icon': '📍'},
  ];

  static const List<Map<String, String>> _lbankTimeframes = [
    {'label': '1m', 'value': '1m'},
    {'label': '3m', 'value': '3m'},
    {'label': '5m', 'value': '5m'},
    {'label': '15m', 'value': '15m'},
    {'label': '30m', 'value': '30m'},
    {'label': '1h', 'value': '1h'},
    {'label': '2h', 'value': '2h'},
    {'label': '4h', 'value': '4h'},
    {'label': '6h', 'value': '6h'},
    {'label': '8h', 'value': '8h'},
    {'label': '12h', 'value': '12h'},
    {'label': '1D', 'value': '1d'},
    {'label': '3D', 'value': '3d'},
    {'label': '1W', 'value': '1w'},
    {'label': '1M', 'value': '1M'},
  ];

  String? _quoteError;
  bool _isLoading = true;
  String _errorMessage = '';

  static const Color _background = Color(0xFF131722);
  static const Color _surface = Color(0xFF1E222D);
  static const Color _green = Color(0xFF26A69A);
  static const Color _red = Color(0xFFEF5350);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initializeTradingView();
    _initializeLBankChart();
    _loadInstruments();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      _loadInstruments();
      _loadLBankQuote();
      _loadOrderBook();
      _loadContractInfo();
      _refreshTimer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) {
          if (mounted && _tabController.index == 1) { _loadLBankQuote(); _loadOrderBook(); _loadContractInfo(); }
        },
      );
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  Future<void> _loadInstruments() async {
    if (_instrumentsLoading) return;
    setState(() { _instrumentsLoading = true; _instrumentsError = null; });
    try {
      final result = await _lbankService.fetchAllFuturesInstruments();
      if (!mounted) return;
      setState(() {
        _instruments = result;
        if (!_instruments.any((e) => e.symbol.toUpperCase() == _selectedSymbol.toUpperCase())) {
          _selectedSymbol = _instruments.first.symbol;
        }
      });
      _loadLBankQuote(); _loadOrderBook(); _loadContractInfo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _instrumentsError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _instrumentsLoading = false);
    }
  }

  Widget _buildInstrumentSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('قرارداد Futures',
          style: TextStyle(color: Colors.white70, fontSize: 12))),
        if (_instrumentsLoading) const SizedBox(width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2)),
        IconButton(visualDensity: VisualDensity.compact,
          onPressed: _instrumentsLoading ? null : _loadInstruments,
          icon: const Icon(Icons.refresh, color: Colors.white70, size: 18)),
      ]),
      if (_instrumentsError != null)
        Text(_instrumentsError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
      DropdownButtonFormField<String>(
        value: _instruments.any((e) => e.symbol == _selectedSymbol) ? _selectedSymbol : null,
        isExpanded: true, dropdownColor: _surface,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(filled: true, fillColor: _surface,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        hint: const Text('انتخاب نماد از فهرست قراردادهای LBank',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
        items: _instruments.map((item) => DropdownMenuItem<String>(
          value: item.symbol,
          child: Text('${item.symbol} · ${item.symbolName}', overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (value) {
          if (value == null || value == _selectedSymbol) return;
          setState(() { _selectedSymbol = value; _quote = null; _orderBook = null; _contractInfo = null; });
          _loadLBankQuote(); _loadOrderBook(); _loadContractInfo();
          _reloadTradingView();
          _reloadLBankChart();
        },
      ),
      Text('${_instruments.length} قرارداد در فهرست دریافت‌شده',
        style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]);
  }

  Future<void> _loadLBankQuote() async {
    if (_quoteLoading) return;
    setState(() {
      _quoteLoading = true;
      _quoteError = null;
    });
    try {
      final result = await _lbankService.fetchQuote(_selectedSymbol);
      if (!mounted) return;
      setState(() => _quote = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _quoteError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }



  Future<void> _loadContractInfo() async {
    if (_contractLoading) return;
    setState(() { _contractLoading = true; _contractError = null; });
    try {
      final result = await _lbankService.fetchContractInfo(_selectedSymbol);
      if (!mounted) return;
      setState(() => _contractInfo = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _contractError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _contractLoading = false);
    }
  }

  Widget _buildContractInfo() {
    final info = _contractInfo;
    return Container(
      margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('مشخصات قرارداد',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          if (_contractLoading) const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(visualDensity: VisualDensity.compact,
            onPressed: _contractLoading ? null : _loadContractInfo,
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white70)),
        ]),
        if (info != null) ...[
          _contractRow('نماد', info.symbol),
          _contractRow('ارز پایه / قیمت', '${info.baseCurrency} / ${info.priceCurrency}'),
          _contractRow('گام قیمت', info.priceTick.toString()),
          _contractRow('گام حجم', info.volumeTick.toString()),
          _contractRow('ضریب قرارداد', info.volumeMultiple.toString()),
          _contractRow('حداقل حجم سفارش', info.minOrderVolume.toString()),
          _contractRow('حداکثر حجم سفارش', info.maxOrderVolume.toString()),
          _contractRow('حداقل ارزش سفارش', info.minOrderCost.toString()),
          _contractRow('اهرم پیش‌فرض', info.defaultLeverage.toString()),
        ] else if (_contractError != null)
          Text(_contractError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11))
        else
          const Text('در انتظار دریافت مشخصات قرارداد…',
            style: TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    );
  }

  Widget _contractRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 11)),
    ]),
  );

  Future<void> _loadOrderBook() async {
    if (_bookLoading) return;
    setState(() { _bookLoading = true; _bookError = null; });
    try {
      final result = await _lbankService.fetchOrderBook(_selectedSymbol);
      if (!mounted) return;
      setState(() => _orderBook = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bookError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _bookLoading = false);
    }
  }

  Widget _bookSide(String title, List<LBankBookLevel> levels, Color color) {
    final maxVolume = levels.fold<double>(0, (m, e) => e.volume > m ? e.volume : m);
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      const SizedBox(height: 7),
      const Row(children: [
        Expanded(child: Text('قیمت', style: TextStyle(color: Colors.white38, fontSize: 10))),
        Expanded(child: Text('حجم', textAlign: TextAlign.end, style: TextStyle(color: Colors.white38, fontSize: 10))),
      ]),
      const SizedBox(height: 4),
      ...levels.take(10).map((level) {
        final fraction = maxVolume <= 0 ? 0.0 : (level.volume / maxVolume).clamp(0.0, 1.0);
        return Stack(children: [
          Positioned.fill(child: Align(alignment: Alignment.centerRight,
            child: FractionallySizedBox(widthFactor: fraction,
              child: Container(color: color.withValues(alpha: 0.12))))),
          Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            child: Row(children: [
              Expanded(child: Text(level.price.toStringAsFixed(4),
                style: TextStyle(color: color, fontSize: 11), overflow: TextOverflow.ellipsis)),
              Expanded(child: Text(level.volume.toStringAsFixed(4), textAlign: TextAlign.end,
                style: const TextStyle(color: Colors.white70, fontSize: 11))),
            ])),
        ]);
      }),
    ]));
  }

  Widget _buildOrderBook() {
    final book = _orderBook;
    return Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('دفتر سفارش Futures',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          if (_bookLoading) const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(onPressed: _bookLoading ? null : _loadOrderBook,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
            visualDensity: VisualDensity.compact),
        ]),
        if (book != null) ...[
          Text('آخرین به‌روزرسانی: ${book.fetchedAt.toLocal()}',
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bookSide('Bids', book.bids, _green),
            const SizedBox(width: 12),
            _bookSide('Asks', book.asks, _red),
          ]),
        ] else if (_bookError != null)
          Text(_bookError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11))
        else
          const Text('در انتظار دریافت دفتر سفارش…',
            style: TextStyle(color: Colors.white54, fontSize: 11)),
      ]));
  }

  Future<void> _showRiskRewardCalculator() async {
    final balance = TextEditingController();
    final riskPercent = TextEditingController(text: '1');
    final entry = TextEditingController();
    final stop = TextEditingController();
    final target = TextEditingController();
    String? result;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _surface,
          title: const Text('مدیریت ریسک و محاسبه حجم Futures',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _riskInput(balance, 'موجودی حساب (USDT)'),
              const SizedBox(height: 10),
              _riskInput(riskPercent, 'درصد ریسک در هر معامله'),
              const SizedBox(height: 10),
              _riskInput(entry, 'قیمت ورود'),
              const SizedBox(height: 10),
              _riskInput(stop, 'حد ضرر'),
              const SizedBox(height: 10),
              _riskInput(target, 'حد سود'),
              if (result != null) ...[
                const SizedBox(height: 14),
                SelectableText(result!,
                    style: const TextStyle(color: _green, height: 1.6)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () {
              final b = double.tryParse(balance.text);
              final rp = double.tryParse(riskPercent.text);
              final e = double.tryParse(entry.text);
              final sl = double.tryParse(stop.text);
              final tp = double.tryParse(target.text);
              final info = _contractInfo;
              if (b == null || rp == null || e == null || sl == null ||
                  tp == null || b <= 0 || rp <= 0 || rp > 100 ||
                  e <= 0 || sl <= 0 || tp <= 0 || e == sl || e == tp) {
                setDialogState(() => result =
                    'مقادیر را معتبر وارد کنید؛ درصد ریسک باید بیشتر از صفر و حداکثر ۱۰۰ باشد.');
                return;
              }
              if (info == null || info.volumeMultiple <= 0 ||
                  info.volumeTick <= 0 || info.minOrderVolume <= 0) {
                setDialogState(() => result =
                    'مشخصات معتبر قرارداد هنوز دریافت نشده است. ابتدا در تب LBank مشخصات قرارداد را تازه‌سازی کنید.');
                return;
              }
              final isLong = sl < e && tp > e;
              final isShort = sl > e && tp < e;
              if (!isLong && !isShort) {
                setDialogState(() => result =
                    'برای Long حد ضرر پایین‌تر و حد سود بالاتر از ورود؛ برای Short برعکس وارد کنید.');
                return;
              }
              final riskAmount = b * rp / 100;
              final riskPerContract = (e - sl).abs() * info.volumeMultiple;
              final rawContracts = riskAmount / riskPerContract;
              final contracts = (rawContracts / info.volumeTick).floor() *
                  info.volumeTick;
              if (contracts < info.minOrderVolume) {
                setDialogState(() => result =
                    'حجم محاسبه‌شده کمتر از حداقل حجم مجاز قرارداد است. برای رعایت سقف ریسک، حجم را خودکار افزایش ندادیم.');
                return;
              }
              if (info.maxOrderVolume > 0 && contracts > info.maxOrderVolume) {
                setDialogState(() => result =
                    'حجم محاسبه‌شده از حداکثر حجم مجاز بیشتر است. حجم را بازبینی کنید یا سفارش را طبق محدودیت صرافی تقسیم کنید.');
                return;
              }
              final exposureUnits = contracts * info.volumeMultiple;
              final notional = exposureUnits * e;
              final actualRisk = contracts * riskPerContract;
              final rewardPerContract = (tp - e).abs() * info.volumeMultiple;
              final potentialProfit = contracts * rewardPerContract;
              final ratio = rewardPerContract / riskPerContract;
              final leverage = info.defaultLeverage;
              final estimatedMargin = leverage > 0 ? notional / leverage : 0;
              final volumeText = contracts.toStringAsFixed(8)
                  .replaceFirst(RegExp(r'\.?0+$'), '');
              setDialogState(() => result =
                  "جهت معامله: ${isLong ? 'Long' : 'Short'}\n"
                  'ریسک مجاز: ${riskAmount.toStringAsFixed(4)} USDT\n'
                  'تعداد قرارداد: $volumeText\n'
                  'ضریب هر قرارداد: ${info.volumeMultiple}\n'
                  'مقدار دارایی معادل: ${exposureUnits.toStringAsFixed(6)}\n'
                  'ریسک محاسبه‌شده: ${actualRisk.toStringAsFixed(4)} USDT\n'
                  'ارزش اسمی پوزیشن: ${notional.toStringAsFixed(4)} USDT\n'
                  'سود بالقوه تا هدف: ${potentialProfit.toStringAsFixed(4)} USDT\n'
                  'نسبت ریسک به ریوارد: 1 : ${ratio.toStringAsFixed(2)}\n'
                  "${estimatedMargin > 0 ? 'مارجین تخمینی با اهرم پیش‌فرض ${leverage}x: ${estimatedMargin.toStringAsFixed(4)} USDT\n' : ''}"
                  'حجم به گام مجاز قرارداد رو به پایین گرد شده است.\n'
                  'کارمزد، فاندینگ، لغزش قیمت و ریسک لیکوییدشدن لحاظ نشده‌اند.');
            }, child: const Text('محاسبه')),
            TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('بستن')),
          ],
        ),
      ),
    );
    balance.dispose();
    riskPercent.dispose();
    entry.dispose();
    stop.dispose();
    target.dispose();
  }

  Widget _riskInput(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _green)),
        ),
      );

  void _showPnlFibonacciTool() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PnlFibonacciTool(
        initialPrice: _quote?.lastPrice ?? 0,
      ),
    );
  }

  Widget _buildAnalysisTools() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ابزارهای تحلیل و ترسیم',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SizedBox(height: 38, child: ListView(
        scrollDirection: Axis.horizontal,
        children: _drawingTools.map((tool) {
          final selected = _selectedDrawingTool == tool['id'];
          return Padding(padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text('${tool['icon']} ${tool['label']}'),
              selected: selected,
              onSelected: (_) => setState(
                () => _selectedDrawingTool = tool['id']!),
              selectedColor: _green.withValues(alpha: 0.2),
              backgroundColor: _background,
              labelStyle: TextStyle(
                color: selected ? _green : Colors.white70, fontSize: 11),
            ));
        }).toList(),
      )),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
          onPressed: _showPnlFibonacciTool,
          icon: const Icon(Icons.show_chart, size: 16),
          label: const Text('PnL Fibonacci'),
        ),
        OutlinedButton.icon(
          onPressed: _showRiskRewardCalculator,
          icon: const Icon(Icons.calculate_outlined, size: 16),
          label: const Text('ریسک به ریوارد')),
        FilterChip(
          label: const Text('نمایش حجم'),
          selected: _showVolume,
          onSelected: (v) => setState(() => _showVolume = v),
          selectedColor: _green.withValues(alpha: 0.2),
          checkmarkColor: _green,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
      Text(_selectedDrawingTool == 'pointer'
        ? 'انتخاب و جابه‌جایی ترسیمات؛ برای حرکت دادن نمودار، از کنترل‌های خود نمودار استفاده کن.'
        : 'ابزار ${_drawingTools.firstWhere((e) => e['id'] == _selectedDrawingTool)['label']} فعال است. ترسیم روی نمودار نمایش داده و برای همین نماد و تایم‌فریم ذخیره می‌شود. اتصال دقیق به قیمت و زمان کندل هنوز فعال نیست.',
        style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );

  Uri get _lbankFuturesPageUri => Uri.parse('https://www.lbank.com/futures/${_selectedSymbol.toLowerCase()}');

  String get _tradingViewSymbol {
    final normalized = _selectedSymbol.toUpperCase().replaceAll(
      RegExp(r'\.P$'), '',
    );
    return 'LBANK:$normalized.P';
  }

  String get _tradingViewInterval => switch (_selectedLBankTimeframe) {
    '1m' => '1',
    '3m' => '3',
    '5m' => '5',
    '15m' => '15',
    '30m' => '30',
    '1h' => '60',
    '2h' => '120',
    '4h' => '240',
    '6h' => '360',
    '8h' => '480',
    '12h' => '720',
    '1d' => 'D',
    '3d' => '3D',
    '1w' => 'W',
    '1M' => 'M',
    _ => '15',
  };

  void _initializeTradingView() {
    _controller = _createChartController();
    _controller.loadHtmlString(_buildTradingViewHtml(), baseUrl: 'https://www.tradingview.com');
  }

  void _initializeLBankChart() {
    _lbankChartController = _createChartController();
    _lbankChartController.loadRequest(_lbankFuturesPageUri);
  }

  WebViewController _createChartController() => WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _errorMessage = '';
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _isLoading = false;
              _errorMessage = 'خطا در بارگذاری نمودار. اتصال اینترنت را بررسی کنید.';
            });
          },
        ),
      )
      ;

  String _buildTradingViewHtml() => '''
<!DOCTYPE html><html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:#131722}
.tradingview-widget-container,.tradingview-widget-container__widget{width:100%;height:100%}
</style></head><body>
<div class="tradingview-widget-container">
<div class="tradingview-widget-container__widget"></div>
<script type="text/javascript" src="https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js" async>
{
  "autosize":true,
  "symbol":"$_tradingViewSymbol",
  "interval":"$_tradingViewInterval",
  "timezone":"Etc/UTC",
  "theme":"dark",
  "style":"1",
  "locale":"fa",
  "enable_publishing":false,
  "allow_symbol_change":false,
  "hide_top_toolbar":false,
  "hide_side_toolbar":false,
  "hide_legend":false,
  "save_image":false,
  "withdateranges":true,
  "details":true,
  "calendar":false,
  "support_host":"https://www.tradingview.com"
}
</script></div></body></html>
''';

  Future<void> _reloadTradingView() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    await _controller.loadHtmlString(
      _buildTradingViewHtml(),
      baseUrl: 'https://www.tradingview.com',
    );
  }

  Future<void> _reloadLBankChart() async {
    if (!mounted) return;
    await _lbankChartController.loadRequest(_lbankFuturesPageUri);
  }

  Widget _buildTradingViewTab() => Column(
    children: [
      Container(
        color: _background,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstrumentSelector(),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _lbankTimeframes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final item = _lbankTimeframes[index];
                  final value = item['value']!;
                  final selected = value == _selectedLBankTimeframe;
                  return ChoiceChip(
                    label: Text(item['label']!),
                    selected: selected,
                    onSelected: (_) {
                      if (selected) return;
                      setState(() => _selectedLBankTimeframe = value);
                      _reloadTradingView();
                      _reloadLBankChart();
                    },
                    selectedColor: _green.withValues(alpha: 0.22),
                    backgroundColor: _surface,
                    labelStyle: TextStyle(
                      color: selected ? _green : Colors.white70,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: selected ? _green : Colors.white12,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: Stack(children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.blue)),
          if (_errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off, color: Colors.white70, size: 45),
                  const SizedBox(height: 15),
                  Text(_errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _reloadTradingView,
                    child: const Text('تلاش مجدد'),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    ],
  );

  Widget _metric(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 7),
            FittedBox(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
          ]),
        ),
      );

  Widget _buildLBankTab() {
    final q = _quote;
    final positive = q != null && q.lastPrice >= q.openPrice;
    return Container(
      color: _background,
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildInstrumentSelector(),
        const SizedBox(height: 8),
        _buildAnalysisTools(),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(
            child: Text('نمودار زنده LBank Futures',
              style: TextStyle(color: Colors.white70, fontSize: 12,
                fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: 'بارگذاری مجدد نمودار',
            visualDensity: VisualDensity.compact,
            onPressed: _reloadLBankChart,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 19),
          ),
        ]),
        const SizedBox(height: 4),
        SizedBox(
          height: 430,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                WebViewWidget(controller: _lbankChartController),
                ChartDrawingCanvas(
                  tool: _selectedDrawingTool,
                  storageScope: '$_selectedSymbol-$_selectedLBankTimeframe',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_selectedSymbol Futures',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('داده عمومی بازار LBank',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
          IconButton(
            onPressed: _quoteLoading ? null : () { _loadLBankQuote(); _loadOrderBook(); },
            icon: _quoteLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, color: Colors.white),
          ),
        ]),
        const SizedBox(height: 14),
        if (q != null) ...[
          Text(q.lastPrice.toStringAsFixed(4),
              style: TextStyle(
                  color: positive ? _green : _red,
                  fontSize: 30,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('آخرین دریافت: ${q.fetchedAt.toLocal()}',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 16),
          Row(children: [
            _metric('بازشدن ۲۴ساعته', q.openPrice.toStringAsFixed(4)),
            const SizedBox(width: 8),
            _metric('بیشترین', q.highPrice.toStringAsFixed(4)),
            const SizedBox(width: 8),
            _metric('کمترین', q.lowPrice.toStringAsFixed(4)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _metric('Mark Price', q.markedPrice.toStringAsFixed(4)),
            const SizedBox(width: 8),
            if (_showVolume) _metric('حجم ۲۴ساعته', q.volume.toStringAsFixed(2)),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'تایم‌فریم انتخاب‌شده: $_selectedLBankTimeframe. قیمت بالا، داده زنده بازار Futures است؛ اما API رسمی کندل تاریخی/وب‌سوکت برای این قرارداد هنوز تأیید نشده، بنابراین انتخاب تایم‌فریم فعلاً فقط تنظیم رابط است و کندل ساختگی نمایش داده نمی‌شود.',
              style: const TextStyle(color: Colors.white70, height: 1.6),
            ),
          ),
        ] else if (_quoteError != null) ...[
          const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 42),
          const SizedBox(height: 12),
          Text(_quoteError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.orangeAccent, height: 1.5)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: _loadLBankQuote, child: const Text('تلاش مجدد')),
        ] else ...[
          const Center(child: Padding(padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(color: _green))),
        ],
        if (q != null) ...[const SizedBox(height: 14), _buildOrderBook(), _buildContractInfo()],
        const Text(
          'منبع: API عمومی Contract Futures صرافی LBank',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _surface,
          foregroundColor: Colors.white,
          title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_selectedSymbol.P',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text('LBank Futures',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ]),
          actions: [
            IconButton(
              onPressed: _tabController.index == 0
                  ? _reloadTradingView
                  : _loadLBankQuote,
              icon: const Icon(Icons.refresh),
              tooltip: 'به‌روزرسانی',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: _green,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.show_chart), text: 'TradingView'),
              Tab(icon: Icon(Icons.candlestick_chart), text: 'LBank'),
            ],
          ),
        ),
        body: TabBarView(controller: _tabController, children: [
          _buildTradingViewTab(),
          _buildLBankTab(),
        ]),
      );
}
