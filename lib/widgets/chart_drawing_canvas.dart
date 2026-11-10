import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChartDrawingCanvas extends StatefulWidget {
  final String tool;
  final String symbol;
  final String timeframe;
  const ChartDrawingCanvas({super.key, required this.tool, required this.symbol, required this.timeframe});
  @override
  State<ChartDrawingCanvas> createState() => _ChartDrawingCanvasState();
}

class _ChartDrawingCanvasState extends State<ChartDrawingCanvas> {
  final List<_Drawing> _drawings = [];
  Offset? _start, _current;
  bool _loaded = false;

  String get _storageKey => 'lbank_chart_drawings_v2_${Uri.encodeComponent(widget.symbol)}_${Uri.encodeComponent(widget.timeframe)}';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _drawings.addAll(decoded.whereType<Map>().map((e) => _Drawing(
            e['tool']?.toString() ?? 'trend',
            Offset((e['sx'] as num).toDouble(), (e['sy'] as num).toDouble()),
            Offset((e['ex'] as num).toDouble(), (e['ey'] as num).toDouble()),
          )));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_drawings.map((d) => {
        'tool': d.tool, 'sx': d.a.dx, 'sy': d.a.dy, 'ex': d.b.dx, 'ey': d.b.dy,
      }).toList()));
    } catch (_) {}
  }

  Offset _point(Offset p, Size s) => Offset(
    (p.dx / s.width).clamp(0.0, 1.0), (p.dy / s.height).clamp(0.0, 1.0));

  void _undo() {
    if (_drawings.isEmpty) return;
    setState(() => _drawings.removeLast());
    _save();
  }

  void _clear() {
    if (_drawings.isEmpty) return;
    setState(_drawings.clear);
    _save();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    final size = c.biggest;
    if (!_loaded) return const SizedBox.expand();
    return Stack(fit: StackFit.expand, children: [
      IgnorePointer(
        ignoring: widget.tool == 'pointer',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            if (size.width <= 0 || size.height <= 0) return;
            final p = _point(d.localPosition, size);
            setState(() { _start = p; _current = p; });
          },
          onPanUpdate: (d) {
            if (_start != null) setState(() => _current = _point(d.localPosition, size));
          },
          onPanEnd: (_) {
            if (_start != null && _current != null) {
              setState(() {
                _drawings.add(_Drawing(widget.tool, _start!, _current!));
                _start = null;
                _current = null;
              });
              _save();
            }
          },
          onPanCancel: () => setState(() { _start = null; _current = null; }),
          child: CustomPaint(
            painter: _DrawingPainter(
              drawings: _drawings,
              preview: _start != null && _current != null ? _Drawing(widget.tool, _start!, _current!) : null,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      Positioned(top: 4, left: 4, child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xCC131722), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'بازگردانی آخرین ترسیم', visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            onPressed: _drawings.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo, color: Colors.white, size: 17)),
          IconButton(
            tooltip: 'پاک‌کردن ترسیمات این نماد و تایم‌فریم', visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            onPressed: _drawings.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 17)),
          Padding(padding: const EdgeInsets.only(right: 8),
            child: Text('${_drawings.length}', style: const TextStyle(color: Colors.white70, fontSize: 11))),
        ]),
      )),
      if (widget.tool != 'pointer')
        const Positioned(right: 7, bottom: 7, child: IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xCC131722), borderRadius: BorderRadius.all(Radius.circular(5))),
          child: Padding(padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text('حالت ترسیم فعال · برای حرکت نمودار «انتخاب» را بزنید',
              style: TextStyle(color: Colors.white70, fontSize: 9))),
        ))),
    ]);
  });
}

class _Drawing {
  final String tool;
  final Offset a, b;
  const _Drawing(this.tool, this.a, this.b);
}

class _DrawingPainter extends CustomPainter {
  final List<_Drawing> drawings;
  final _Drawing? preview;
  const _DrawingPainter({required this.drawings, this.preview});

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in [...drawings, if (preview != null) preview!]) {
      final a = Offset(d.a.dx * size.width, d.a.dy * size.height);
      final b = Offset(d.b.dx * size.width, d.b.dy * size.height);
      final p = Paint()..color = const Color(0xFF26A69A)..strokeWidth = 1.8..style = PaintingStyle.stroke;
      switch (d.tool) {
        case 'horizontal': canvas.drawLine(Offset(0, a.dy), Offset(size.width, a.dy), p); break;
        case 'vertical': canvas.drawLine(Offset(a.dx, 0), Offset(a.dx, size.height), p); break;
        case 'rectangle': canvas.drawRect(Rect.fromPoints(a, b), p); break;
        case 'fib':
          canvas.drawLine(a, b, p);
          for (final level in const [0.0, .236, .382, .5, .618, .786, 1.0]) {
            final y = a.dy + (b.dy - a.dy) * level;
            canvas.drawLine(Offset(a.dx, y), Offset(b.dx, y), Paint()..color = Colors.amber..strokeWidth = 1.2);
            final label = TextPainter(
              text: TextSpan(text: '${(level * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.amber, fontSize: 9)),
              textDirection: TextDirection.ltr)..layout();
            label.paint(canvas, Offset(b.dx + 3, y - label.height / 2));
          }
          break;
        case 'ruler':
          canvas.drawLine(a, b, Paint()..color = Colors.orangeAccent..strokeWidth = 1.8);
          final label = TextPainter(
            text: TextSpan(text: '${(b - a).distance.toStringAsFixed(0)} px', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10)),
            textDirection: TextDirection.ltr)..layout();
          label.paint(canvas, Offset((a.dx + b.dx) / 2 + 5, (a.dy + b.dy) / 2 + 5));
          break;
        case 'trend': canvas.drawLine(a, b, p); break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
