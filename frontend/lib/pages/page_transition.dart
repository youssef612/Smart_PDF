import 'package:flutter/material.dart';

enum PageTransitionType { slideFromRight, slideFromLeft, fade, scale }

class PageTransition extends PageRouteBuilder {
  final Widget child;
  final PageTransitionType type;
  final Duration duration;

  PageTransition({
    required this.child,
    this.type = PageTransitionType.slideFromRight,
    this.duration = const Duration(milliseconds: 400),
  }) : super(
    transitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    switch (type) {
      case PageTransitionType.slideFromRight:
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      case PageTransitionType.slideFromLeft:
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      case PageTransitionType.fade:
        return FadeTransition(opacity: animation, child: child);
      case PageTransitionType.scale:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
    }
  }
}
