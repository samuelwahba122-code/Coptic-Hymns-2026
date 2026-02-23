import 'dart:ui';
import 'package:flutter/material.dart';

class HazzatBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  const HazzatBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/hazzat_paper.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Convenience wrapper so you can write `Hazzat(child: ...)`.
class Hazzat extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const Hazzat({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return HazzatBackground(
      padding: padding,
      borderRadius: radius,
      child: child,
    );
  }
}