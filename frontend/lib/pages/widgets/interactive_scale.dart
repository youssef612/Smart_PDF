import 'package:flutter/material.dart';

class InteractiveScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const InteractiveScale({
    Key? key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  }) : super(key: key);

  @override
  State<InteractiveScale> createState() => _InteractiveScaleState();
}

class _InteractiveScaleState extends State<InteractiveScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      value: 1.0,
      lowerBound: widget.scale,
      upperBound: 1.0,
    );
    _animation = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _controller.reverse(),
      onTapUp: (_) => _controller.forward(),
      onTapCancel: () => _controller.forward(),
      child: ScaleTransition(
        scale: _animation,
        child: widget.child,
      ),
    );
  }
}
