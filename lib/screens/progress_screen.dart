import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../models/user_profile.dart';
import '../router/app_routes.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressData? _progress;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await UserService.instance.getProgress();
      if (mounted && data != null) setState(() => _progress = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final p = _progress;

    final fatLost = p?.fatLostKg ?? -2.3;
    final muscleGained = p?.muscleGainedKg ?? 1.1;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(
              isDark: isDark,
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2A2A2A) : Colors.transparent,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, isDark ? 24 : 0, 20, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDark) ...[
                      Text(
                        'Progress & Analytics',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Track your fitness journey and upcoming\nmilestones.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white60,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 42),
                    ],
                    const _TransformationCard(),
                    SizedBox(height: isDark ? 30 : 42),
                    Row(
                      children: [
                        Expanded(child: _StatCard.fatLost(value: fatLost)),
                        const SizedBox(width: 20),
                        Expanded(child: _StatCard.muscleGained(value: muscleGained)),
                      ],
                    ),
                    SizedBox(height: isDark ? 30 : 42),
                    const _BeforeAfterCard(),
                    SizedBox(height: isDark ? 30 : 38),
                    const _ReportActions(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const _BottomNav(),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.isDark,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isDark ? 68 : 130,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, isDark ? 10 : 26, 20, isDark ? 10 : 24),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Menu',
              onPressed: () {},
              icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white70 : AppColors.teal, size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Progress',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (isDark)
              IconButton(
                tooltip: 'Light theme',
                onPressed: onLight,
                icon: const Icon(Icons.dark_mode_rounded, color: Color(0xFF31D39E), size: 34),
              )
            else
              _ThemeSegment(isDark: isDark, onLight: onLight, onDark: onDark),
          ],
        ),
      ),
    );
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeButton(selected: !isDark, icon: Icons.wb_sunny_outlined, onTap: onLight),
            const SizedBox(width: 4),
            _ThemeButton(selected: isDark, icon: Icons.dark_mode_rounded, onTap: onDark),
          ],
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            icon,
            color: selected ? Colors.white : const Color(0xFF6F727A),
            size: 31,
          ),
        ),
      ),
    );
  }
}

class _TransformationCard extends StatelessWidget {
  const _TransformationCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F20) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 12 : 14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isDark ? 28 : 30, isDark ? 30 : 36, isDark ? 28 : 30, isDark ? 28 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Predictive\nTransformation\nCurve',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
                Icon(
                  isDark ? Icons.auto_graph_rounded : Icons.info_outline_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF9B9EA5),
                  size: isDark ? 34 : 36,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Goal: 68 kg - Estimated: Aug 2025',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.teal,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isDark ? 32 : 44),
            SizedBox(
              height: isDark ? 158 : 210,
              child: CustomPaint(painter: _CurvePainter(isDark: isDark)),
            ),
            const SizedBox(height: 24),
            Divider(color: isDark ? const Color(0xFF2B2B2D) : const Color(0xFFF0F0F0)),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.circle, color: AppColors.teal, size: 19),
                const SizedBox(width: 10),
                Text('Actual', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.white70 : const Color(0xFF6D7078))),
                const SizedBox(width: 28),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? AppColors.teal.withValues(alpha: 0.6) : const Color(0xFFC5C7CB)),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Predicted', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.white70 : const Color(0xFF6D7078))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  const _CurvePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final actual = Paint()..color = isDark ? const Color(0xFF0FA07C) : AppColors.teal;
    final predictedFill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = isDark ? const Color(0xFF777A73) : const Color(0xFFD1D3D6);

    final values = isDark
        ? [0.44, 0.5, 0.62, 0.56, 0.72, 0.84, 0.78, 0.94, 1.0, 1.0, 1.05, 1.08]
        : [1.0, 0.93, 0.87, 0.81, 0.74, 0.68, 0.63, 0.59, 0.55, 0.5, 0.45, 0.38];
    final count = values.length;
    final gap = isDark ? 9.0 : 7.0;
    final barW = (size.width - gap * (count - 1)) / count;
    final maxH = size.height * 0.85;

    for (var i = 0; i < count; i++) {
      final x = i * (barW + gap);
      final h = maxH * values[i].clamp(0.25, 1.0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barW, h),
        Radius.circular(isDark ? 2 : 3),
      );
      if (i < 9) {
        canvas.drawRRect(rect, actual);
      } else if (isDark) {
        final stripePaint = Paint()..color = const Color(0xFF6F746F);
        canvas.drawRRect(rect, Paint()..color = const Color(0xFF26312D));
        for (var y = rect.top + 3; y < rect.bottom; y += 8) {
          canvas.drawRect(Rect.fromLTWH(rect.left, y, rect.width, 3), stripePaint);
        }
        canvas.drawRRect(rect, predictedFill);
      } else {
        canvas.drawRRect(rect, predictedFill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatCard extends StatelessWidget {
  _StatCard.fatLost({double? value})
      : label = 'FAT LOST',
        displayValue = '${(value ?? -2.3).toStringAsFixed(1)} kg',
        color = const Color(0xFFB80000),
        icon = Icons.show_chart_rounded;

  _StatCard.muscleGained({double? value})
      : label = 'MUSCLE\nGAINED',
        displayValue = '+${(value ?? 1.1).toStringAsFixed(1)} kg',
        color = AppColors.teal,
        icon = Icons.trending_up_rounded;

  final String label;
  final String displayValue;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F20) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 10 : 14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDark ? 24 : 28, vertical: isDark ? 30 : 28),
        child: isDark
            ? Column(
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFB4B5BC),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayValue,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, color: color, size: 30),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'VS PREVIOUS MONTH',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF777A80),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.replaceAll('\n', ' '),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF72747B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          displayValue,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(icon, color: color, size: 40),
                ],
              ),
      ),
    );
  }
}

class _BeforeAfterCard extends StatelessWidget {
  const _BeforeAfterCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F20) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 10 : 14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isDark ? 28 : 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Before / After',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            SizedBox(height: isDark ? 34 : 38),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: isDark ? 2.25 : 2.0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _BeforeAfterPainter(isDark: isDark)),
                    Center(
                      child: Container(width: 4, color: isDark ? const Color(0xFF31D39E) : AppColors.teal),
                    ),
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: isDark ? 0 : 3),
                        ),
                        child: SizedBox(
                          width: isDark ? 28 : 34,
                          height: isDark ? 42 : 58,
                          child: Icon(Icons.swap_vert_rounded, color: Colors.white, size: isDark ? 20 : 25),
                        ),
                      ),
                    ),
                    Positioned(
                      left: isDark ? 18 : 16,
                      bottom: isDark ? 18 : 16,
                      child: _DatePill(label: 'JAN 2025', dark: isDark, before: true),
                    ),
                    Positioned(
                      right: isDark ? 18 : 16,
                      bottom: isDark ? 18 : 16,
                      child: _DatePill(label: 'APR 2025', dark: isDark, before: false),
                    ),
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

class _BeforeAfterPainter extends CustomPainter {
  const _BeforeAfterPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final leftRect = Rect.fromLTWH(0, 0, size.width / 2, size.height);
    final rightRect = Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);
    canvas.drawRect(
      leftRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF101214), const Color(0xFF050505)]
              : [const Color(0xFFBDBDBD), const Color(0xFFE5E5E5)],
        ).createShader(leftRect),
    );
    canvas.drawRect(
      rightRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF093B31), const Color(0xFF0D0E0E)]
              : [const Color(0xFF0D6F61), const Color(0xFF95D0BF)],
        ).createShader(rightRect),
    );

    _drawPerson(canvas, Offset(size.width * 0.25, size.height * 0.52), isDark ? Colors.black87 : const Color(0xFF707070), 0.72);
    _drawPerson(canvas, Offset(size.width * 0.76, size.height * 0.48), isDark ? const Color(0xFFB89173) : const Color(0xFFE4C0A2), 0.88);
  }

  void _drawPerson(Canvas canvas, Offset center, Color color, double scale) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8 * scale;
    canvas.drawCircle(center.translate(0, -42 * scale), 12 * scale, Paint()..color = color);
    canvas.drawLine(center.translate(0, -28 * scale), center.translate(0, 22 * scale), paint);
    canvas.drawLine(center.translate(-22 * scale, -8 * scale), center.translate(22 * scale, -8 * scale), paint);
    canvas.drawLine(center.translate(0, 18 * scale), center.translate(-22 * scale, 58 * scale), paint);
    canvas.drawLine(center.translate(0, 18 * scale), center.translate(22 * scale, 58 * scale), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.label,
    required this.dark,
    required this.before,
  });

  final String label;
  final bool dark;
  final bool before;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: before
            ? (dark ? Colors.black.withValues(alpha: 0.68) : Colors.white.withValues(alpha: 0.9))
            : AppColors.teal,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dark ? 18 : 16, vertical: dark ? 10 : 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(before ? Icons.person_outline_rounded : Icons.accessibility_new_rounded, size: 17, color: before && !dark ? Colors.blue : Colors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: before && !dark ? Colors.black : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportActions extends StatelessWidget {
  const _ReportActions();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: _ReportButton(
            label: 'Export PDF',
            icon: Icons.description_outlined,
            primary: true,
            dark: isDark,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _ReportButton(
            label: 'Excel Report',
            icon: Icons.insert_chart_outlined_rounded,
            primary: false,
            dark: isDark,
          ),
        ),
      ],
    );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.dark,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dark ? 58 : 70,
      child: OutlinedButton.icon(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? (primary ? Colors.transparent : const Color(0xFF1F1F20)) : Colors.white,
          foregroundColor: primary ? AppColors.teal : (dark ? Colors.white70 : const Color(0xFF555861)),
          side: BorderSide(color: primary ? AppColors.teal : (dark ? const Color(0xFF1F1F20) : Colors.white)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dark ? 8 : 10)),
        ),
        icon: Icon(icon),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: primary ? AppColors.teal : (dark ? Colors.white70 : const Color(0xFF555861)),
              fontWeight: primary ? FontWeight.w500 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _NavSpec(Icons.home_outlined, 'HOME', false, () => context.go(AppRoutes.homeDashboard)),
      _NavSpec(Icons.fitness_center_rounded, 'WORKOUT', false, () => context.go(AppRoutes.workoutHub)),
      _NavSpec(Icons.restaurant_rounded, 'NUTRITION', false, () => context.go(AppRoutes.nutrition)),
      _NavSpec(Icons.insert_chart_outlined_rounded, 'PROGRESS', true, () {}),
      _NavSpec(Icons.person_outline_rounded, 'COACH', false, () {}),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF242426) : const Color(0xFFEDEFF0))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: isDark ? 88 : 84,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in items) _NavItem(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.icon, this.label, this.selected, this.onTap);

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item});

  final _NavSpec item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark ? const Color(0xFF31D39E) : AppColors.teal;
    final idle = isDark ? const Color(0xFF72747B) : const Color(0xFFA0A2AA);
    final color = item.selected ? active : idle;

    return Material(
      color: item.selected ? active.withValues(alpha: isDark ? 0.13 : 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 88,
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 28),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
