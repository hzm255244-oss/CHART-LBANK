import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChartDrawingCanvas extends StatefulWidget {
  final String tool;
  const ChartDrawingCanvas({super.key, required this.tool});
  @override
  State<ChartDrawingCanvas> createState() => _ChartDrawingCanvasState();
}

class _ChartDrawingCanvasState extends State<ChartDrawingCanvas> {
  final List<_Drawing> _drawings = [];
  Offset? _start, _current;
  bool _loaded = false;
  String get _storageKey => 'lbank_chart_drawings_v1';

  @override
  void initState() {
    super.initState();
    _restoreDrawings();
  }

  Future<void> _restoreDrawings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _drawings
            ..clear()
            ..addAll(decoded.whereType<Map>().map((e) => _Drawing(
              e['tool']?.toString() ?? 'trend',
              Offset((e['sx'] as num).toDouble(), (e['sy'] as num).toDouble()),
              Offset((e['ex'] as num).toDouble(), (e['ey'] as num).toDouble()),
            )));
        }
      }
    } catch (_) {
      // Ignore malformed local drawing data and keep the canvas usable.
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _persistDrawings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _drawings.map((d) => {
      'tool': d.tool, 'sx': d.start.dx, 'sy': d.start.dy,
      'ex': d.end.dx, 'ey': d.end.dy,
    }).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Offset _normalize(Offset p, Size s) =>
      Offset((p.dx / s.width).clamp(0.0, 1.0), (p.dy / s.height).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 270,
    child: LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, 270);
      if (!_loaded) return const SizedBox(height: 270, child: Center(child: CircularProgressIndicator()));\n      return Container(\n        decoration: BoxDecoration(color: const Color(0xFF131722),
          border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(8)),
        child: Stack(children: [
          Positioned.fill(child: GestureDetector(
            onPanStart: (d) {
              if (widget.tool == 'pointer') return;
              setState(() { _start = _normalize(d.localPosition, size); _current = _start; });
            },
            onPanUpdate: (d) {
              if (_start != null) setState(() => _current = _normalize(d.localPosition, size));
            },
            onPanEnd: (_) {
              if (_start != null && _current != null) {
                setState(() { _drawings.add(_Drawing(widget.tool, _start!, _current!)); _start = null; _current = null; });\n                _persistDrawings();
              }
            },
            child: CustomPaint(
              painter: _ChartDrawingPainter(drawings: _drawings,
                preview: _start != null && _current != null ? _Drawing(widget.tool, _start!, _current!) : null),
              child: const SizedBox.expand(),
            ),
          )),
          Positioned(top: 5, left: 5, child: Row(children: [
            IconButton(tooltip: 'پاک‌کردن ترسیمات', visualDensity: VisualDensity.compact,
              onPressed: _drawings.isEmpty ? null : () { setState(() => _drawings.clear()); _persistDrawings(); },
              icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 19)),
            Text('${_drawings.length} ترسیم, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ])),
          if (widget.tool == 'pointer')
            const Positioned(left: 0, right: 0, bottom: 10,
              child: Text('ابزار رسم را انتخاب کنید و روی بوم بکشید',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10))),
        ]),
      );
    }),
  );
}

class _Drawing {
  final String tool;
  final Offset start, end;
  const _Drawing(this.tool, this.start, this.end);
}

class _ChartDrawingPainter extends CustomPainter {
  final List<_Drawing> drawings;
  final _Drawing? preview;
  const _ChartDrawingPainter({required this.drawings, this.preview});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withValues(alpha: .08)..strokeWidth = 1;
    for (var i = 1; i < 6; i++) canvas.drawLine(Offset(0, size.height*i/6), Offset(size.width, size.height*i/6), grid);
    for (var i = 1; i < 8; i++) canvas.drawLine(Offset(size.width*i/8, 0), Offset(size.width*i/8, size.height), grid);
    for (final d in [...drawings, if (preview != null) preview!]) {
      final a = Offset(d.start.dx*size.width, d.start.dy*size.height);
      final b = Offset(d.end.dx*size.width, d.end.dy*size.height);
      final p = Paint()..color = const Color(0xFF26A69A)..strokeWidth = 1.7..style = PaintingStyle.stroke;
      switch (d.tool) {
        case 'horizontal': canvas.drawLine(Offset(0,a.dy), Offset(size.width,a.dy), p); break;
        case 'vertical': canvas.drawLine(Offset(a.dx,0), Offset(a.dx,size.height), p); break;
        case 'rectangle': canvas.drawRect(Rect.fromPoints(a,b), p); break;
        case 'fib':
          canvas.drawLine(a,b,p);
          for (final level in const [0.0,.236,.382,.5,.618,.786,1.0]) {
            final y=a.dy+(b.dy-a.dy)*level;
            canvas.drawLine(Offset(a.dx,y),Offset(b.dx,y),Paint()..color=Colors.amber..strokeWidth=1);
          }
          break;
        case 'ruler':
          canvas.drawLine(a,b,Paint()..color=Colors.orangeAccent..strokeWidth=1.7);
          final tp=TextPainter(text: TextSpan(text:'${((b-a).distance/size.height*100).toStringAsFixed(1)}% ارتفاع بوم',
            style: const TextStyle(color:Colors.orangeAccent,fontSize:10)),textDirection:TextDirection.rtl)..layout();
          tp.paint(canvas,Offset((a.dx+b.dx)/2,(a.dy+b.dy)/2)+const Offset(4,4));
          break;
        case 'trend': canvas.drawLine(a,b,p); break;
      }
    }
  }
  @override
  bool shouldRepaint(covariant _ChartDrawingPainter oldDelegate) => true;
}
