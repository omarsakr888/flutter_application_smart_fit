import 'dart:async';
import 'package:flutter/material.dart';

class AnimatedSmartFitLogo extends StatefulWidget {
  final double size;
  final bool isDark;

  const AnimatedSmartFitLogo({
    super.key,
    this.size = 120,
    this.isDark = false,
  });

  @override
  State<AnimatedSmartFitLogo> createState() => _AnimatedSmartFitLogoState();
}

class _AnimatedSmartFitLogoState extends State<AnimatedSmartFitLogo>
    with TickerProviderStateMixin {
  late AnimationController _sDrawController;
  late AnimationController _zigzagDrawController;

  @override
  void initState() {
    super.initState();
    _sDrawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800), // ~1.5-2.0s reveal
    );
    _zigzagDrawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    // 1. One-time wiping reveal of the S
    _sDrawController.forward();

    // 2. Infinite ECG line loop
    while (mounted) {
      await _zigzagDrawController.forward(from: 0.0);
      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) break;
      _zigzagDrawController.reset();
    }
  }

  @override
  void dispose() {
    _sDrawController.dispose();
    _zigzagDrawController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sColor = widget.isDark ? Colors.white : Colors.black;
    final zigzagColor = const Color(0xFF8A1028);

    return AnimatedBuilder(
      animation: Listenable.merge([_sDrawController, _zigzagDrawController]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size * 1.2),
          painter: _SLogoPainter(
            sDrawProgress: _sDrawController.value,
            zigzagProgress: _zigzagDrawController.value,
            sColor: sColor,
            zigzagColor: zigzagColor,
          ),
        );
      },
    );
  }
}

class _SLogoPainter extends CustomPainter {
  final double sDrawProgress;
  final double zigzagProgress;
  final Color sColor;
  final Color zigzagColor;

  _SLogoPainter({
    required this.sDrawProgress,
    required this.zigzagProgress,
    required this.sColor,
    required this.zigzagColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // We use a saveLayer group to use the progressive stroke as a MASK (destination),
    // and draw the static S logo inside it using srcIn.
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());

    // 1. Destination Mask: Animated thick stroke that follows the S contour
    final maskPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.9 // Extra thick to fully cover the actual text bounds
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final revealPath = Path();
    revealPath.moveTo(w * 0.85, h * 0.1);
    revealPath.cubicTo(w * 0.85, -h * 0.1, w * 0.15, -h * 0.1, w * 0.15, h * 0.3);
    revealPath.cubicTo(w * 0.15, h * 0.7, w * 0.85, h * 0.3, w * 0.85, h * 0.7);
    revealPath.cubicTo(w * 0.85, h * 1.1, w * 0.15, h * 1.1, w * 0.15, h * 0.9);

    final metrics = revealPath.computeMetrics();
    final extractPath = Path();
    for (final metric in metrics) {
      extractPath.addPath(metric.extractPath(0.0, metric.length * sDrawProgress), Offset.zero);
    }
    canvas.drawPath(extractPath, maskPaint);

    // 2. Source: The Static Bold 'S' with the cutout.
    // BlendMode.srcIn means the Source is ONLY drawn where the Mask exists!
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint()..blendMode = BlendMode.srcIn);

    // 2a. Draw the solid static S
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          fontSize: h * 1.15,
          fontWeight: FontWeight.w900,
          color: sColor,
          height: 1.0,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final textOffset = Offset(
      (w - textPainter.width) / 2,
      (h - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    // 2b. Punch the static straight white center opening through the S
    // It's a clean horizontal opening, NOT shaped like the ECG line.
    final cutoutRect = Rect.fromLTRB(-w * 0.2, h * 0.44, w * 1.2, h * 0.56);
    final cutoutPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    canvas.drawRect(cutoutRect, cutoutPaint);

    // Close srcIn layer
    canvas.restore();
    // Close mask layer
    canvas.restore();

    // 3. Draw the continuously moving ECG heartbeat line.
    // It is a separate layer that passes straight through the white center opening.
    final ecgPaint = Paint()
      ..color = zigzagColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final zigzagPath = Path();
    final midY = h * 0.5;
    zigzagPath.moveTo(-w * 0.1, midY);
    zigzagPath.lineTo(w * 0.25, midY);
    zigzagPath.lineTo(w * 0.35, midY + h * 0.05); // dip down
    zigzagPath.lineTo(w * 0.45, midY - h * 0.12); // tall spike up
    zigzagPath.lineTo(w * 0.55, midY + h * 0.12); // deep spike down
    zigzagPath.lineTo(w * 0.65, midY - h * 0.05); // small recovery
    zigzagPath.lineTo(w * 0.75, midY);
    zigzagPath.lineTo(w * 1.1, midY);

    final zMetrics = zigzagPath.computeMetrics();
    final zExtractPath = Path();
    for (final metric in zMetrics) {
      zExtractPath.addPath(metric.extractPath(0.0, metric.length * zigzagProgress), Offset.zero);
    }
    canvas.drawPath(zExtractPath, ecgPaint);
  }

  @override
  bool shouldRepaint(covariant _SLogoPainter oldDelegate) {
    return oldDelegate.sDrawProgress != sDrawProgress ||
           oldDelegate.zigzagProgress != zigzagProgress;
  }
}
