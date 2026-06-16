import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../models/ocr_result.dart';
import '../router/app_routes.dart';
import '../services/scan_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_chat_fab.dart';

class AnalysisLoadingScreen extends StatefulWidget {
  const AnalysisLoadingScreen({super.key, this.ocrResult});

  final OcrExtractResult? ocrResult;

  static const _stepLabels = [
    'Reading InBody metrics',
    'Calculating Calorie Target',
    'Determining Macro Split',
    'Setting Intensity Multiplier',
    'Building Workout Split',
    'Assembling Meal Plan',
  ];

  @override
  State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
}

class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen> {
  int _activeStep = 0;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _startStepAnimation();
    _startAnalysis();
  }

  void _startStepAnimation() {
    // Advance the active step every 900 ms to simulate progress.
    _stepTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_activeStep < AnalysisLoadingScreen._stepLabels.length - 1) {
          _activeStep++;
        } else {
          t.cancel();
        }
      });
    });
  }

  List<_AnalysisStep> get _steps {
    return [
      for (var i = 0; i < AnalysisLoadingScreen._stepLabels.length; i++)
        _AnalysisStep(
          AnalysisLoadingScreen._stepLabels[i],
          i < _activeStep
              ? _StepState.done
              : i == _activeStep
                  ? _StepState.active
                  : _StepState.pending,
        ),
    ];
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final ocr = widget.ocrResult;
    if (ocr == null) {
      await Future<void>.delayed(const Duration(seconds: 6));
    } else {
      try {
        await ScanService.instance.generatePlan(ocr);
      } catch (_) {
        // Navigate to home even on error; home dashboard uses its own data
      }
    }
    if (mounted) context.go(AppRoutes.homeDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      bottomNavigationBar: isDark ? const _BottomNav() : null,
      floatingActionButton: const AiChatFab(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              isDark: isDark,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.inBodyScan);
                }
              },
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF262D2F) : const Color(0xFFEDEFF0),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, isDark ? 94 : 122, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: _LaserScanner()),
                    const SizedBox(height: 52),
                    Text(
                      'Analyzing your body data',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Your AI plan is being generated...',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? Colors.white60 : const Color(0xFF7B7D85),
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: isDark ? 94 : 64),
                    _StepsCard(steps: _steps),
                    SizedBox(height: isDark ? 48 : 62),
                    if (isDark) ...[
                      const _InsightCard(),
                      const SizedBox(height: 36),
                      const _MotionPanel(),
                    ] else ...[
                      const Row(
                        children: [
                          Expanded(
                            child: _SignalCard(
                              icon: Icons.insert_chart_outlined_rounded,
                              label: 'METRICS DEPTH',
                              progress: 0.67,
                            ),
                          ),
                          SizedBox(width: 30),
                          Expanded(
                            child: _SignalCard(
                              icon: Icons.psychology_outlined,
                              label: 'AI PRECISION',
                              progress: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 128),
                      const Center(child: _SecurePill()),
                    ],
                    SizedBox(height: isDark ? 92 : 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _AnalysisStep {
  const _AnalysisStep(this.label, this.state);

  final String label;
  final _StepState state;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isDark,
    required this.onBack,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isDark ? 92 : 116,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isDark ? 18 : 40, 8, isDark ? 28 : 36, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                size: isDark ? 28 : 34,
                color: themeAwareBackColor(context, isDark),
              ),
            ),
            const Spacer(),
            _ThemeSegment(
              isDark: isDark,
              onLight: onLight,
              onDark: onDark,
            ),
          ],
        ),
      ),
    );
  }

  Color themeAwareBackColor(BuildContext context, bool isDark) {
    return isDark ? Colors.white : Colors.black;
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
    required this.isDark,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    final compact = isDark;
    final bg = isDark ? const Color(0xFF202927) : const Color(0xFFF1F3F4);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF26312F) : const Color(0xFFF6F7F8),
          width: compact ? 0 : 4,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 4 : 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeButton(
              selected: !isDark,
              compact: compact,
              icon: Icons.wb_sunny_outlined,
              onTap: onLight,
            ),
            SizedBox(width: compact ? 5 : 8),
            _ThemeButton(
              selected: isDark,
              compact: compact,
              icon: Icons.dark_mode_rounded,
              onTap: onDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.selected,
    required this.compact,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final bool compact;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idle = isDark ? Colors.white38 : const Color(0xFF9AA0A7);

    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: compact ? 50 : 58,
          height: compact ? 50 : 58,
          child: Icon(
            icon,
            color: selected ? Colors.white : idle,
            size: compact ? 26 : 30,
          ),
        ),
      ),
    );
  }
}

class _LaserScanner extends StatefulWidget {
  const _LaserScanner();

  @override
  State<_LaserScanner> createState() => _LaserScannerState();
}

class _LaserScannerState extends State<_LaserScanner> with SingleTickerProviderStateMixin {
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
      width: 160,
      height: 160,
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
              Icons.document_scanner_outlined,
              color: isDark ? Colors.white24 : Colors.black12,
              size: 72,
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Align(
                alignment: Alignment(0, -1.0 + (_controller.value * 2.0)),
                child: child,
              );
            },
            child: Container(
              height: 3,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.teal,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.8),
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps});

  final List<_AnalysisStep> steps;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 14 : 24),
        border: Border.all(
          color: isDark ? const Color(0xFF141C19) : const Color(0xFFECEEEF),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isDark ? 38 : 48, 34, 28, 34),
        child: Column(
          children: [
            for (final step in steps) ...[
              _StepRow(step: step),
              if (step != steps.last) const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final _AnalysisStep step;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doneColor = isDark ? const Color(0xFF6ED8BE) : AppColors.teal;
    final muted = isDark ? const Color(0xFF676D7A) : const Color(0xFFD4D5D8);
    final doneText = isDark ? const Color(0xFF7E8390) : const Color(0xFF9DA0A6);

    final icon = switch (step.state) {
      _StepState.done => Icon(
          Icons.check_circle_outline_rounded,
          color: doneColor,
          size: isDark ? 29 : 42,
        ),
      _StepState.active => Icon(
          Icons.circle,
          color: isDark ? AppColors.teal : const Color(0xFF7CC6B9),
          size: isDark ? 18 : 20,
        ),
      _StepState.pending => Icon(
          Icons.circle_outlined,
          color: muted,
          size: isDark ? 16 : 17,
        ),
    };

    final textColor = switch (step.state) {
      _StepState.done => doneText,
      _StepState.active => Theme.of(context).colorScheme.onSurface,
      _StepState.pending => muted,
    };

    return Row(
      children: [
        SizedBox(width: isDark ? 34 : 44, child: Center(child: icon)),
        SizedBox(width: isDark ? 20 : 24),
        Expanded(
          child: Text(
            step.label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: textColor,
                  fontWeight:
                      step.state == _StepState.active ? FontWeight.w700 : FontWeight.w400,
                  decoration:
                      step.state == _StepState.done ? TextDecoration.lineThrough : null,
                  decorationColor: textColor,
                ),
          ),
        ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.icon,
    required this.label,
    required this.progress,
  });

  final IconData icon;
  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEEEF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 30, 30, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Icon(icon, color: AppColors.teal, size: 36),
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: AppColors.teal,
                backgroundColor: const Color(0xFFF2F3F4),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFFA7A9AE),
                    letterSpacing: 0.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurePill extends StatelessWidget {
  const _SecurePill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFECEEEF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, color: Color(0xFF68D0BE), size: 12),
            const SizedBox(width: 14),
            Text(
              'Secure data processing active',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF777A82),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111A18),
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF17231F),
            const Color(0xFF111816),
            const Color(0xFF101015).withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 36, 30, 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const SizedBox(
                width: 68,
                height: 68,
                child: Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF6ED8BE), size: 34),
              ),
            ),
            const SizedBox(width: 26),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Did you know?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Smart Fit AI takes into account your circadian rhythm to suggest the optimal training window for peak testosterone levels.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MotionPanel extends StatelessWidget {
  const _MotionPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 180,
        child: CustomPaint(
          painter: _MotionPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MotionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF151718), Color(0xFF090A0B)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final streak = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = -4; i < 18; i++) {
      final start = Offset(i * 46.0, size.height + 20);
      final end = Offset(start.dx + 180, -20);
      canvas.drawLine(start, end, streak);
    }

    final speck = Paint()..color = Colors.white.withValues(alpha: 0.16);
    for (var i = 0; i < 42; i++) {
      final x = (i * 37) % size.width;
      final y = (i * 61) % size.height;
      canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), i.isEven ? 1.5 : 1, speck);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.dashboard_outlined, 'Dashboard', false),
      (Icons.fitness_center_rounded, 'Workouts', false),
      (Icons.smart_toy_outlined, 'AI\nCoach', true),
      (Icons.restaurant_rounded, 'Nutrition', false),
      (Icons.person_outline_rounded, 'Profile', false),
    ];

    return SizedBox(
      height: 96,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF111111)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final item in items)
              _NavItem(icon: item.$1, label: item.$2, selected: item.$3),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2DB994) : const Color(0xFF5B5C67);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF18191E) : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        width: 88,
        height: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    height: 1.1,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
