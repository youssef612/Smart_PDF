import 'dart:math';
import 'package:flutter/material.dart';
import 'package:project_flutter/services/api_service.dart';

// ─── Data Model ───────────────────────────────────────────────
class MindNode {
  final String label;
  final List<MindNode> children;
  MindNode({required this.label, required this.children});

  factory MindNode.fromJson(Map<String, dynamic> json) {
    final kids = (json['children'] as List? ?? [])
        .map((c) => MindNode.fromJson(c as Map<String, dynamic>))
        .toList();
    return MindNode(label: json['label'] ?? '', children: kids);
  }
}

// ─── Layout ───────────────────────────────────────────────────
class _NodeLayout {
  final MindNode node;
  Offset position;
  final int depth;
  final List<_NodeLayout> children;
  _NodeLayout({required this.node, required this.position,
    required this.depth, required this.children});
}

_NodeLayout _buildLayout(MindNode root) {
  const hGap = 220.0;
  const vGap = 60.0;

  double _subtreeHeight(MindNode n) {
    if (n.children.isEmpty) return vGap;
    return n.children.fold(0.0, (s, c) => s + _subtreeHeight(c));
  }

  _NodeLayout _build(MindNode n, int depth, double y) {
    final x = depth * hGap;
    final kids = <_NodeLayout>[];
    double cy = y;
    for (final c in n.children) {
      final h = _subtreeHeight(c);
      kids.add(_build(c, depth + 1, cy + h / 2 - vGap / 2));
      cy += h;
    }
    return _NodeLayout(
      node: n,
      position: Offset(x, y),
      depth: depth,
      children: kids,
    );
  }

  final root0 = _build(root, 0, _subtreeHeight(root) / 2);

  // center root vertically
  void _shift(_NodeLayout l, double dy) {
    l.position = l.position.translate(0, dy);
    for (final c in l.children) _shift(c, dy);
  }

  double minY = double.infinity;
  void _findMin(_NodeLayout l) {
    if (l.position.dy < minY) minY = l.position.dy;
    for (final c in l.children) _findMin(c);
  }
  _findMin(root0);
  _shift(root0, -minY + 40);
  return root0;
}

// ─── Painter ──────────────────────────────────────────────────
class _MindMapPainter extends CustomPainter {
  final _NodeLayout root;
  final List<Color> levelColors;
  _MindMapPainter(this.root, this.levelColors);

  final _linePaint = Paint()
    ..color = Colors.grey.shade300
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  void _drawEdges(Canvas c, _NodeLayout l) {
    for (final child in l.children) {
      final p1 = l.position + const Offset(90, 20);
      final p2 = child.position + const Offset(0, 20);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(p1.dx + 40, p1.dy, p2.dx - 40, p2.dy, p2.dx, p2.dy);
      c.drawPath(path, _linePaint);
      _drawEdges(c, child);
    }
  }

  void _drawNodes(Canvas c, Size s, _NodeLayout l) {
    final color = levelColors[l.depth % levelColors.length];
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(l.position.dx, l.position.dy,
          l.depth == 0 ? 120 : 100, 40),
      const Radius.circular(20),
    );
    c.drawRRect(rect, Paint()..color = color.withOpacity(0.15));
    c.drawRRect(rect, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    final tp = TextPainter(
      text: TextSpan(
        text: l.node.label,
        style: TextStyle(
          color: color.withOpacity(0.9),
          fontSize: l.depth == 0 ? 13 : 11,
          fontWeight: l.depth == 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: l.depth == 0 ? 110 : 90);
    tp.paint(c, l.position + Offset(
      (l.depth == 0 ? 120 : 100) / 2 - tp.width / 2,
      20 - tp.height / 2,
    ));

    for (final child in l.children) _drawNodes(c, s, child);
  }

  @override
  void paint(Canvas c, Size s) {
    _drawEdges(c, root);
    _drawNodes(c, s, root);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Page ─────────────────────────────────────────────────────
class MindMapPage extends StatefulWidget {
  final String? fileName;
  final String? fileId;
  const MindMapPage({Key? key, this.fileName, this.fileId}) : super(key: key);

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  bool       _isGenerating = false;
  MindNode?  _root;
  String?    _error;
  late String _selectedLanguage;

  final _transformCtrl = TransformationController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    _selectedLanguage = lang == 'ar' ? 'arabic' : 'english';
  }

  bool get isArabic => _selectedLanguage == 'arabic';

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (widget.fileId == null) return;
    setState(() { _isGenerating = true; _error = null; });
    try {
      final api = ApiService();
      final res = await api.dio.post(
        '/files/${widget.fileId}/mindmap',
      );
      if (res.data['success'] == true) {
        final node = MindNode.fromJson(
            res.data['data'] as Map<String, dynamic>);
        setState(() { _root = node; _isGenerating = false; });
      } else {
        setState(() {
          _error = res.data['message'] ?? 'Failed';
          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isGenerating = false; });
    }
  }

  static const _colors = [
    Color(0xFF6366F1), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isArabic ? 'خريطة ذهنية' : 'Mind Map',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        elevation: 0,
        actions: [
          if (_root != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _generate,
              tooltip: isArabic ? 'إعادة توليد' : 'Regenerate',
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isGenerating) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF6366F1)),
          const SizedBox(height: 20),
          Text(isArabic ? 'جاري بناء الخريطة الذهنية...' : 'Building mind map...',
              style: theme.textTheme.bodyMedium),
        ],
      ));
    }

    if (_error != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _generate,
              child: Text(isArabic ? 'إعادة المحاولة' : 'Retry')),
        ],
      ));
    }

    if (_root == null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.account_tree_rounded,
                size: 64, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            isArabic ? 'اضغط لبناء الخريطة الذهنية' : 'Tap to build mind map',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.fileName ?? '',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(isArabic ? 'توليد الخريطة' : 'Generate Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ));
    }

    final layout = _buildLayout(_root!);

    // حساب أبعاد الـ canvas
    double maxX = 0, maxY = 0;
    void _measure(_NodeLayout l) {
      if (l.position.dx + 120 > maxX) maxX = l.position.dx + 120;
      if (l.position.dy + 50 > maxY) maxY = l.position.dy + 50;
      for (final c in l.children) _measure(c);
    }
    _measure(layout);

    return InteractiveViewer(
      transformationController: _transformCtrl,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.3,
      maxScale: 3.0,
      child: SizedBox(
        width: maxX + 40,
        height: maxY + 40,
        child: CustomPaint(
          painter: _MindMapPainter(layout, _colors),
        ),
      ),
    );
  }
}
