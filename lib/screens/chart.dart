import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late final TabController _tabController;

  bool _isLoading = true;
  String _errorMessage = '';

  static const Color _background = Color(0xFF131722);
  static const Color _surface = Color(0xFF1E222D);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeTradingView();
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
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _isLoading = false;
              _errorMessage =
                  'خطا در بارگذاری نمودار. اتصال اینترنت را بررسی کنید.';
            });
          },
        ),
      )
      ..loadHtmlString(
        _tradingViewHtml,
        baseUrl: 'https://www.tradingview.com',
      );
  }

  static const String _tradingViewHtml = r'''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0; padding: 0; width: 100%; height: 100%;
      overflow: hidden; background: #131722;
    }
    .tradingview-widget-container,
    .tradingview-widget-container__widget {
      width: 100%; height: 100%;
    }
  </style>
</head>
<body>
<div class="tradingview-widget-container">
  <div class="tradingview-widget-container__widget"></div>
  <script type="text/javascript"
    src="https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js"
    async>
  {
    "autosize": true,
    "symbol": "LBANK:GOLDUSDT.P",
    "interval": "15",
    "timezone": "Etc/UTC",
    "theme": "dark",
    "style": "1",
    "locale": "fa",
    "enable_publishing": false,
    "allow_symbol_change": false,
    "hide_top_toolbar": false,
    "hide_legend": false,
    "save_image": false,
    "withdateranges": true,
    "details": true,
    "calendar": false,
    "support_host": "https://www.tradingview.com"
  }
  </script>
</div>
</body>
</html>
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
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTradingViewTab() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          ),
        if (_errorMessage.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white70, size: 45),
                  const SizedBox(height: 15),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _reloadTradingView,
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLBankTab() {
    return Container(
      color: _background,
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.candlestick_chart,
                color: Color(0xFF26A69A),
                size: 58,
              ),
              const SizedBox(height: 18),
              const Text(
                'نمودار مستقیم LBank Futures',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'نماد: GOLDUSDT.P  •  تایم‌فریم: ۱۵ دقیقه',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'اتصال داده‌های Futures هنوز تأیید نشده است',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'این بخش عمداً هنوز کندل یا قیمت ساختگی نمایش نمی‌دهد. '
                      'پس از تأیید مسیر رسمی دریافت کندل GOLDUSDT در بازار '
                      'فیوچرز LBank، نمودار مستقل و زنده در همین قسمت فعال می‌شود. '
                      'داده Spot یا TradingView جایگزین داده Futures نخواهد شد.',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.6,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'مرحله بعد: تأیید API عمومی Futures و سپس اتصال امن حساب '
                'برای اطلاعات خصوصی و سفارش‌ها.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GOLDUSDT.P',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'LBank Futures',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _tabController.index == 0 ? _reloadTradingView : null,
            icon: const Icon(Icons.refresh),
            tooltip: 'به‌روزرسانی نمودار',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF26A69A),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart), text: 'TradingView'),
            Tab(icon: Icon(Icons.candlestick_chart), text: 'LBank'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTradingViewTab(),
          _buildLBankTab(),
        ],
      ),
    );
  }
}
