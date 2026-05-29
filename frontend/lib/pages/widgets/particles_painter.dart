import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppParticle {
  final double x, size, speed, opacity;
  double y;
  AppParticle({required this.x, required this.y, required this.size, required this.speed, required this.opacity});
  static List<AppParticle> generate(int n, math.Random r) => List.generate(n, (_) => AppParticle(x: r.nextDouble(), y: r.nextDouble(), size: r.nextDouble() * 7 + 3, speed: r.nextDouble() * 0.25 + 0.08, opacity: r.nextDouble() * 0.35 + 0.08));
}

class _Painter extends CustomPainter {
  final List<AppParticle> p;
  final double progress;
  const _Painter({required this.p, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    for (final pt in p) {
      final y = (pt.y + progress * pt.speed) % 1.0;
      canvas.drawCircle(Offset(pt.x * size.width, y * size.height), pt.size, Paint()..color = Colors.white.withOpacity(pt.opacity));
    }
  }
  @override bool shouldRepaint(_Painter old) => old.progress != progress;
}

class ParticlesLayer extends StatefulWidget {
  final int count;
  const ParticlesLayer({Key? key, this.count = 16}) : super(key: key);
  @override State<ParticlesLayer> createState() => _ParticlesLayerState();
}
class _ParticlesLayerState extends State<ParticlesLayer> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late List<AppParticle> _p;
  @override void initState() { super.initState(); _p = AppParticle.generate(widget.count, math.Random()); _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => CustomPaint(
      painter: _Painter(p: _p, progress: _c.value),
      size: Size.infinite, // ✅ الإصلاح هنا
    ),
  );
}

class ShimmerText extends StatefulWidget {
  final String text; final TextStyle style;
  const ShimmerText({Key? key, required this.text, required this.style}) : super(key: key);
  @override State<ShimmerText> createState() => _ShimmerTextState();
}
class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _a;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(); _a = Tween<double>(begin: -2.0, end: 2.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _a, builder: (_, __) => ShaderMask(shaderCallback: (b) => LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: const [Colors.white, Color(0xFFE0E7FF), Colors.white, Colors.white], stops: [0.0, (_a.value + 2) / 4, (_a.value + 2.3) / 4, 1.0]).createShader(b), child: Text(widget.text, style: widget.style)));
}

class PulseContainer extends StatefulWidget {
  final Widget child; final double minScale, maxScale;
  const PulseContainer({Key? key, required this.child, this.minScale = 0.95, this.maxScale = 1.05}) : super(key: key);
  @override State<PulseContainer> createState() => _PulseContainerState();
}
class _PulseContainerState extends State<PulseContainer> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _s;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true); _s = Tween<double>(begin: widget.minScale, end: widget.maxScale).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ScaleTransition(scale: _s, child: widget.child);
}