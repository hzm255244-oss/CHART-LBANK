import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/lbank_service.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late final TabController _tabController;
  final LBankFuturesService _lbankService = LBankFuturesService();

  Timer? _refreshTimer;
  LBankFuturesQuote? _quote;
  bool _quoteLoading = false;
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
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      _loadLBankQuote();
      _refreshTimer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) {
          if (mounted && _tabController.index == 1) _loadLBankQuote();
        },
      );
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  Future<void> _loadLBankQuote() async {
    if (_quoteLoading) return;
    setState(() {
      _quoteLoading = true;
      _quoteError = null;
    });
    try {
      final result = await _lbankService.fetchGoldQuote();
      if (!mounted) return;
      setState(() => _quote = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _quoteError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  void _initializeTradingView() {
    _controller = WebViewController()
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
      ..loadHtmlString(_tradingViewHtml,
          baseUrl: 'https://www.tradingview.com');
  }

  static const String _tradingViewHtml = r'''
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
"autosize":true,"symbol":"LBANK:GOLDUSDT.P","interval":"15",
"timezone":"Etc/UTC","theme":"dark","style":"1","locale":"fa",
"enable_publishing":false,"allow_symbol_change":false,
"hide_top_toolbar":false,"hide_legend":false,"save_image":false,
"withdateranges":true,"details":true,"calendar":false,
"support_host":"https://www.tradingview.com"
}
</script></div></body></html>
''';

  Future<void> _reloadTradingView() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    await _controller.reload();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTradingViewTab() => Stack(children: [
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
                    child: const Text('تلاش مجدد')),
              ]),
            ),
          ),
      ]);

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GOLDUSDT Futures',
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
            onPressed: _quoteLoading ? null : _loadLBankQuote,
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
            _metric('حجم ۲۴ساعته', q.volume.toStringAsFixed(2)),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'اتصال قیمت لحظه‌ای Futures برقرار است. این اطلاعات، آمار ۲۴ ساعته بازار است و کندل ۱۵ دقیقه‌ای محسوب نمی‌شود. مسیر رسمی کندل تاریخی/وب‌سوکت قرارداد باید جداگانه تأیید شود؛ تا آن زمان نمودار کندلی نمایش داده نمی‌شود.',
              style: TextStyle(color: Colors.white70, height: 1.6),
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
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: _green),
            ),
          ),
        ],
        if (q != null) const Spacer(),
        const Text(
          'منبع: API عمومی Contract Futures صرافی LBank',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _surface,
          foregroundColor: Colors.white,
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GOLDUSDT.P',
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
