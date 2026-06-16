import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Animated laser-line scanner for loading states.
enum LaserScanAxis { vertical, horizontal }

class LaserScanner extends StatefulWidget {
  const LaserScanner({
    super.key,
    this.axis = LaserScanAxis.vertical,
    this.width = 160,
    this.height = 160,
    this.icon = Icons.document_scanner_outlined,
    this.iconSize = 72,
  });

  final LaserScanAxis axis;
  final double width;
  final double height;
  final IconData icon;
  final double iconSize;

  @override
  State<LaserScanner> createState() => _LaserScannerState();
}

class _LaserScannerState extends State<LaserScanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2220) : const Color(0xFFF2F4F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3B4642) : const Color(0xFFE2E6E8),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: Icon(
              widget.icon,
              color: isDark ? Colors.white24 : Colors.black12,
              size: widget.iconSize,
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (widget.axis == LaserScanAxis.vertical) {
                return Align(
                  alignment: Alignment(0, -1.0 + (_controller.value * 2.0)),
                  child: child,
                );
              }
              return Align(
                alignment: Alignment(-1.0 + (_controller.value * 2.0), 0),
                child: child,
              );
            },
            child: widget.axis == LaserScanAxis.vertical
                ? Container(
                    height: 3,
                    width: double.infinity,
                    decoration: _laserDecoration(),
                  )
                : Container(
                    width: 3,
                    height: double.infinity,
                    decoration: _laserDecoration(),
                  ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _laserDecoration() => BoxDecoration(
        color: AppColors.teal,
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.8),
            blurRadius: 10,
            spreadRadius: 3,
          ),
        ],
      );
}
