import 'package:flutter/material.dart';

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  // Premium Spring Curves
  static const Curve springCurve = Curves.easeOutQuart;
  static const Curve springCurveIn = Curves.easeInQuart;
  static const Curve springCurveInOut = Curves.easeInOutQuart;

  static Widget fade({
    required Widget child,
    Duration duration = medium,
    double begin = 0.0,
    double end = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: springCurve,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }

  static Widget slideAndFade({
    required Widget child,
    Duration duration = medium,
    Offset begin = const Offset(0, 20),
    Offset end = Offset.zero,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: springCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              begin.dx + (end.dx - begin.dx) * value,
              begin.dy + (end.dy - begin.dy) * value,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  static Widget scale({
    required Widget child,
    Duration duration = medium,
    double begin = 0.95,
    double end = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: springCurve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }
}

class GhostPageTransitionsBuilder extends PageTransitionsBuilder {
  const GhostPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: AppAnimations.springCurve,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AppAnimations.springCurve,
        )),
        child: child,
      ),
    );
  }
}
