
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final WebViewController _controller;

  bool _isLoading = true;
  String _errorMessage = '';

  static const String _symbol = 'LBANK:GOLDUSDT.P';

  @override
  void initState() {
    super.initState();
    _initializeChart();
  }

  void _initializeChart() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF131722))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = '';
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                _isLoading = false;
                _errorMessage =
                    'خطا در بارگذاری نمودار. اتصال اینترنت را بررسی کنید.';
              });
            }
          },
        ),
      )
      ..loadHtmlString(
        _chartHtml,
        baseUrl: 'https://www.tradingview.com',
      );
  }

  static const String _chartHtml = r'''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport"
        content="width=device-width, initial-scale=1.0">

  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #131722;
    }

    .tradingview-widget-container {
      width: 100%;
      height: 100%;
    }

    .tradingview-widget-container__widget {
      width: 100%;
      height: 100%;
    }
  </style>
</head>

<body>

<div class="tradingview-widget-container">

  <div class="tradingview-widget-container__widget"></div>

  <script
    type="text/javascript"
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

  Future<void> _reloadChart() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131722),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GOLDUSDT.P',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'LBank Futures | 15 Minutes',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _reloadChart,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh chart',
          ),
        ],
      ),

      body: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
              ),
            ),

          if (_errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off,
                      color: Colors.white70,
                      size: 45,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _reloadChart,
                      child: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
