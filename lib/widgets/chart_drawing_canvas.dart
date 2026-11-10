import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChartDrawingCanvas extends StatefulWidget {
  final String tool;
  final String storageScope;

  const ChartDrawingCanvas({
    super.key,
    required this.tool,
    this.storageScope = 'default',
  });

  @override
  State<ChartDrawingCanvas> createState() => _ChartDrawingCanvasState();
}

class _ChartDrawingCanvasState extends State<ChartDrawingCanvas> {
  final List<_Drawing> _drawings = [];
  Offset? _start;
  Offset? _current;
  bool _loaded = false;
  int? _selectedIndex;
  Offset? _moveOrigin;
  _Drawing? _moveDrawing;

  String get _storageKey =>
      'lbank_chart_drawings_v2_${widget.storageScope}';

  @override
  void initState() {
    super.initState();
    _restoreDrawings();
  }

  @override
  void didUpdateWidget(covariant ChartDrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageScope != widget.storageScope) {
      _drawings.clear();
      _loaded = false;
      _restoreDrawings();
    }
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
            ..addAll(decoded.whereType<Map>().map(_Drawing.fromJson));
        }
      }
    } catch (_) {
      // Invalid saved drawings should never prevent chart use.
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _persistDrawings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_drawings.map((d) => d.toJson()).toList()),
    );
  }

  Offset _normalize(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0),
    (point.dy / size.height).clamp(0.0, 1.0),
  );

  Future<void> _addText(Offset point, Size size) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        title: const Text('افزودن متن',
          style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'متن موردنظر را وارد کن',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => _drawings.add(_Drawing(
      'text', _normalize(point, size), _normalize(point, size), label: value,
    )));
    _persistDrawings();
  }

  int? _hitTest(Offset point, Size size) {
    const tolerance = 18.0;
    for (var i = _drawings.length - 1; i >= 0; i--) {
      final d = _drawings[i];
      final a = Offset(d.start.dx * size.width, d.start.dy * size.height);
      final b = Offset(d.end.dx * size.width, d.end.dy * size.height);
      final rect = Rect.fromPoints(a, b).inflate(tolerance);
      if (rect.contains(point) || (point - a).distance <= tolerance ||
          (point - b).distance <= tolerance) return i;
    }
    return null;
  }

  void _onTap(Offset point, Size size) {
    if (widget.tool == 'pointer') {
      setState(() => _selectedIndex = _hitTest(point, size));
      return;
    }
    if (widget.tool == 'text') {
      _addText(point, size);
      return;
    }
    if (widget.tool == 'pin') {
      setState(() => _drawings.add(_Drawing(
        'pin', _normalize(point, size), _normalize(point, size),
      )));
      _persistDrawings();
    }
  }

  void _onPanStart(DragStartDetails details, Size size) {
    if (widget.tool == 'pointer') {
      final index = _hitTest(details.localPosition, size);
      setState(() {
        _selectedIndex = index;
        _moveOrigin = details.localPosition;
        _moveDrawing = index == null ? null : _drawings[index];
      });
      return;
    }
    if (widget.tool == 'text' || widget.tool == 'pin') return;
    setState(() {
      _start = _normalize(details.localPosition, size);
      _current = _start;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (widget.tool == 'pointer' && _moveOrigin != null &&
        _moveDrawing != null && _selectedIndex != null) {
      final delta = details.localPosition - _moveOrigin!;
      final original = _moveDrawing!;
      final dx = delta.dx / size.width;
      final dy = delta.dy / size.height;
      final moved = _Drawing(
        original.tool,
        Offset((original.start.dx + dx).clamp(0.0, 1.0),
            (original.start.dy + dy).clamp(0.0, 1.0)),
        Offset((original.end.dx + dx).clamp(0.0, 1.0),
            (original.end.dy + dy).clamp(0.0, 1.0)),
        label: original.label,
      );
      setState(() => _drawings[_selectedIndex!] = moved);
      _moveOrigin = details.localPosition;
      _moveDrawing = moved;
      return;
    }
    if (_start == null) return;
    setState(() => _current = _normalize(details.localPosition, size));
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.tool == 'pointer') {
      if (_moveDrawing != null) _persistDrawings();
      _moveOrigin = null;
      _moveDrawing = null;
      return;
    }
    if (_start == null || _current == null) return;
    setState(() {
      _drawings.add(_Drawing(widget.tool, _start!, _current!));
      _start = null;
      _current = null;
    });
    _persistDrawings();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (!_loaded) return const SizedBox.expand();
      return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) => _onTap(details.localPosition, size),
          onPanStart: (details) => _onPanStart(details, size),
          onPanUpdate: (details) => _onPanUpdate(details, size),
          onPanEnd: _onPanEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _ChartDrawingPainter(
                  drawings: _drawings,
                  selectedIndex: _selectedIndex,
                  preview: _start != null && _current != null
                      ? _Drawing(widget.tool, _start!, _current!)
                      : null,
                ),
              ),
              if (_drawings.isNotEmpty)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${_drawings.length} ترسیم',
                        style: const TextStyle(color: Colors.white70, fontSize: 9)),
                    ),
                  ),
                ),
              Positioned(
                top: 2,
                left: 2,
                child: Material(
                  color: Colors.black.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(6),
                  child: IconButton(
                    tooltip: 'پاک‌کردن ترسیمات این نماد و تایم‌فریم',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                    onPressed: _drawings.isEmpty ? null : () {
                      setState(_drawings.clear);
                      _persistDrawings();
                    },
                    icon: const Icon(Icons.delete_outline,
                      color: Colors.white70, size: 17),
                  ),
                ),
              ),
            ],
          ),
      );
    });
  }
}

class _Drawing {
  final String tool;
  final Offset start;
  final Offset end;
  final String? label;

  const _Drawing(this.tool, this.start, this.end, {this.label});

  factory _Drawing.fromJson(Map value) => _Drawing(
    value['tool']?.toString() ?? 'trendline',
    Offset((value['sx'] as num).toDouble(), (value['sy'] as num).toDouble()),
    Offset((value['ex'] as num).toDouble(), (value['ey'] as num).toDouble()),
    label: value['label']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'tool': tool,
    'sx': start.dx,
    'sy': start.dy,
    'ex': end.dx,
    'ey': end.dy,
    if (label != null) 'label': label,
  };
}

class _ChartDrawingPainter extends CustomPainter {
  final List<_Drawing> drawings;
  final _Drawing? preview;
  final int? selectedIndex;

  const _ChartDrawingPainter({
    required this.drawings, this.preview, this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final drawing in [...drawings, if (preview != null) preview!]) {
      final a = Offset(drawing.start.dx * size.width,
          drawing.start.dy * size.height);
      final b = Offset(drawing.end.dx * size.width,
          drawing.end.dy * size.height);
      final line = Paint()
        ..color = const Color(0xFFFFC857)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final secondary = Paint()
        ..color = const Color(0xFF26A69A)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      switch (drawing.tool) {
        case 'trendline':
          canvas.drawLine(a, b, line);
          break;
        case 'crossline':
          canvas.drawLine(Offset(a.dx, 0), Offset(a.dx, size.height), line);
          canvas.drawLine(Offset(0, a.dy), Offset(size.width, a.dy), line);
          break;
        case 'fib_retracement':
          canvas.drawLine(a, b, secondary);
          for (final level in const [0.0, .236, .382, .5, .618, .786, 1.0]) {
            final y = a.dy + (b.dy - a.dy) * level;
            canvas.drawLine(Offset(0, y), Offset(size.width, y),
                Paint()..color = const Color(0xFFFFC857)..strokeWidth = 1);
            _drawLabel(canvas, '${(level * 100).toStringAsFixed(1)}%',
                Offset(5, y - 13), const Color(0xFFFFC857));
          }
          break;
        case 'fibchannel':
          final delta = b - a;
          final normal = Offset(-delta.dy * .18, delta.dx * .18);
          canvas.drawLine(a, b, secondary);
          canvas.drawLine(a + normal, b + normal, line);
          canvas.drawLine(a - normal, b - normal, line);
          break;
        case 'date_price_range':
        case 'measure':
          canvas.drawLine(a, b, line);
          canvas.drawCircle(a, 3, line);
          canvas.drawCircle(b, 3, line);
          final dx = ((b.dx - a.dx) / size.width * 100).abs();
          final dy = ((b.dy - a.dy) / size.height * 100).abs();
          final label = drawing.tool == 'measure'
              ? 'X: $dx%  Y: $dy%'
              : 'محدوده زمان / قیمت';
          _drawLabel(canvas, label, (a + b) / 2 + const Offset(5, 5),
              const Color(0xFFFFC857));
          break;
        case 'text':
          _drawLabel(canvas, drawing.label ?? 'متن', a,
              const Color(0xFFFFFFFF));
          break;
        case 'pin':
          canvas.drawCircle(a, 7, Paint()..color = const Color(0xFFFFC857));
          canvas.drawCircle(a, 3, Paint()..color = const Color(0xFF131722));
          break;
      }
      final index = drawings.indexOf(drawing);
      if (index == selectedIndex) {
        final handle = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(a, 4, handle);
        canvas.drawCircle(b, 4, handle);
        final outline = Paint()
          ..color = const Color(0xFFFFC857)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawRect(Rect.fromPoints(a, b).inflate(5), outline);
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text,
        style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)])),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 220);
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _ChartDrawingPainter oldDelegate) => true;
}
