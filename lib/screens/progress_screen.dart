import 'package:fl_chart/fl_chart.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await UserService.instance.getProgress();
      if (mounted) setState(() { _progress = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showExportSnackbar(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$format export coming soon'),
        backgroundColor: AppColors.teal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _fmtScanDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${_months[d.month - 1].toUpperCase()} ${d.year}';
    } catch (_) {
      return iso;
    }
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
      backgroundColor:
          isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF4F4F4),
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
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.teal))
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          20, isDark ? 24 : 0, 20, 34),
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
                          // ── Live charts section ──────────────────────────
                          if (p != null && p.scanDates.length >= 2) ...[
                            _SectionTitle('Body Composition Charts', isDark),
                            const SizedBox(height: 16),
                            _ChartCard(
                              title: 'Weight (kg)',
                              values: p.weightHistory,
                              dates: p.scanDates,
                              color: AppColors.teal,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 20),
                            _ChartCard(
                              title: 'Body Fat %',
                              values: p.pbfHistory,
                              dates: p.scanDates,
                              color: const Color(0xFFB80000),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 20),
                            _ChartCard(
                              title: 'Skeletal Muscle Mass (kg)',
                              values: p.smmHistory,
                              dates: p.scanDates,
                              color: const Color(0xFF1565C0),
                              isDark: isDark,
                            ),
                            SizedBox(height: isDark ? 30 : 42),
                          ] else ...[
                            _EmptyChartsCard(isDark: isDark),
                            SizedBox(height: isDark ? 30 : 42),
                          ],
                          // ── Stat cards ───────────────────────────────────
                          Row(
                            children: [
                              Expanded(child: _StatCard.fatLost(value: fatLost)),
                              const SizedBox(width: 20),
                              Expanded(
                                  child: _StatCard.muscleGained(
                                      value: muscleGained)),
                            ],
                          ),
                          SizedBox(height: isDark ? 30 : 42),
                          _BeforeAfterCard(
                            firstDate: p != null && p.scanDates.isNotEmpty
                                ? _fmtScanDate(p.scanDates.first)
                                : 'First Scan',
                            lastDate: p != null && p.scanDates.length > 1
                                ? _fmtScanDate(p.scanDates.last)
                                : 'Latest Scan',
                          ),
                          SizedBox(height: isDark ? 30 : 38),
                          _ReportActions(onExport: _showExportSnackbar),
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

// ── Charts ────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.isDark);

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
      );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.values,
    required this.dates,
    required this.color,
    required this.isDark,
  });

  final String title;
  final List<double> values;
  final List<String> dates;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    final count = values.length;
    for (var i = 0; i < count; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    final minY = (values.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

    final cardBg = isDark ? const Color(0xFF1F1F20) : Colors.white;
    final gridColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    final labelColor =
        isDark ? Colors.white38 : const Color(0xFF9CA3AF);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: (maxY - minY) / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: gridColor,
                      strokeWidth: 1,
                    ),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (v, meta) => Text(
                          v.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 10, color: labelColor),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: count <= 4
                            ? 1
                            : (count / 4).ceilToDouble(),
                        getTitlesWidget: (v, meta) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= dates.length) {
                            return const SizedBox.shrink();
                          }
                          final d = dates[idx];
                          final parts = d.split('-');
                          final label = parts.length == 3
                              ? '${parts[1]}/${parts[2]}'
                              : d;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: TextStyle(
                                  fontSize: 9, color: labelColor),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: color,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: color,
                          strokeWidth: 2,
                          strokeColor: cardBg,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map(
                            (s) => LineTooltipItem(
                              s.y.toStringAsFixed(1),
                              TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChartsCard extends StatelessWidget {
  const _EmptyChartsCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F20) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.insert_chart_outlined_rounded,
              size: 52,
              color: isDark ? Colors.white24 : const Color(0xFFCDD0D5),
            ),
            const SizedBox(height: 16),
            Text(
              'No scan data yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : const Color(0xFF667085),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete at least 2 InBody scans to see\nyour body composition charts.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

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
        padding:
            EdgeInsets.fromLTRB(20, isDark ? 10 : 26, 20, isDark ? 10 : 24),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Menu',
              onPressed: () {},
              icon: Icon(Icons.menu_rounded,
                  color: isDark ? Colors.white70 : AppColors.teal, size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Progress',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: isDark
                          ? const Color(0xFF31D39E)
                          : AppColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'Achievements',
              onPressed: () => context.push(AppRoutes.achievements),
              icon: Icon(
                Icons.emoji_events_outlined,
                color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
                size: 28,
              ),
            ),
            if (isDark)
              IconButton(
                tooltip: 'Light theme',
                onPressed: onLight,
                icon: const Icon(Icons.dark_mode_rounded,
                    color: Color(0xFF31D39E), size: 34),
              )
            else
              _ThemeSegment(
                  isDark: isDark, onLight: onLight, onDark: onDark),
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
            _ThemeButton(
                selected: !isDark,
                icon: Icons.wb_sunny_outlined,
                onTap: onLight),
            const SizedBox(width: 4),
            _ThemeButton(
                selected: isDark,
                icon: Icons.dark_mode_rounded,
                onTap: onDark),
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

// ── Stat Cards ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  _StatCard.fatLost({double? value})
      : label = 'FAT LOST',
        displayValue = '${(value ?? -2.3).abs().toStringAsFixed(1)} kg',
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
        padding: EdgeInsets.symmetric(
            horizontal: isDark ? 24 : 28, vertical: isDark ? 30 : 28),
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
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
                    'VS PREVIOUS SCAN',
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: const Color(0xFF72747B),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          displayValue,
                          maxLines: 1,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
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

// ── Before / After card ───────────────────────────────────────────────────────

class _BeforeAfterCard extends StatelessWidget {
  const _BeforeAfterCard({
    required this.firstDate,
    required this.lastDate,
  });

  final String firstDate;
  final String lastDate;

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
                    CustomPaint(
                        painter: _BeforeAfterPainter(isDark: isDark)),
                    Center(
                      child: Container(
                        width: 4,
                        color:
                            isDark ? const Color(0xFF31D39E) : AppColors.teal,
                      ),
                    ),
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF31D39E)
                              : AppColors.teal,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white,
                              width: isDark ? 0 : 3),
                        ),
                        child: SizedBox(
                          width: isDark ? 28 : 34,
                          height: isDark ? 42 : 58,
                          child: Icon(Icons.swap_vert_rounded,
                              color: Colors.white,
                              size: isDark ? 20 : 25),
                        ),
                      ),
                    ),
                    Positioned(
                      left: isDark ? 18 : 16,
                      bottom: isDark ? 18 : 16,
                      child: _DatePill(
                          label: firstDate,
                          dark: isDark,
                          before: true),
                    ),
                    Positioned(
                      right: isDark ? 18 : 16,
                      bottom: isDark ? 18 : 16,
                      child: _DatePill(
                          label: lastDate,
                          dark: isDark,
                          before: false),
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
    final leftRect =
        Rect.fromLTWH(0, 0, size.width / 2, size.height);
    final rightRect =
        Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);
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
    _drawPerson(canvas,
        Offset(size.width * 0.25, size.height * 0.52),
        isDark ? Colors.black87 : const Color(0xFF707070), 0.72);
    _drawPerson(canvas,
        Offset(size.width * 0.76, size.height * 0.48),
        isDark ? const Color(0xFFB89173) : const Color(0xFFE4C0A2), 0.88);
  }

  void _drawPerson(
      Canvas canvas, Offset center, Color color, double scale) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8 * scale;
    canvas.drawCircle(
        center.translate(0, -42 * scale), 12 * scale,
        Paint()..color = color);
    canvas.drawLine(center.translate(0, -28 * scale),
        center.translate(0, 22 * scale), paint);
    canvas.drawLine(center.translate(-22 * scale, -8 * scale),
        center.translate(22 * scale, -8 * scale), paint);
    canvas.drawLine(center.translate(0, 18 * scale),
        center.translate(-22 * scale, 58 * scale), paint);
    canvas.drawLine(center.translate(0, 18 * scale),
        center.translate(22 * scale, 58 * scale), paint);
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
            ? (dark
                ? Colors.black.withValues(alpha: 0.68)
                : Colors.white.withValues(alpha: 0.9))
            : AppColors.teal,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: dark ? 18 : 16, vertical: dark ? 10 : 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              before
                  ? Icons.person_outline_rounded
                  : Icons.accessibility_new_rounded,
              size: 17,
              color: before && !dark ? Colors.blue : Colors.white,
            ),
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

// ── Report actions ────────────────────────────────────────────────────────────

class _ReportActions extends StatelessWidget {
  const _ReportActions({required this.onExport});

  final void Function(String format) onExport;

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
            onTap: () => onExport('PDF'),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _ReportButton(
            label: 'Excel Report',
            icon: Icons.insert_chart_outlined_rounded,
            primary: false,
            dark: isDark,
            onTap: () => onExport('Excel'),
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
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dark ? 58 : 70,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: dark
              ? (primary ? Colors.transparent : const Color(0xFF1F1F20))
              : Colors.white,
          foregroundColor: primary
              ? AppColors.teal
              : (dark ? Colors.white70 : const Color(0xFF555861)),
          side: BorderSide(
              color: primary
                  ? AppColors.teal
                  : (dark ? const Color(0xFF1F1F20) : Colors.white)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dark ? 8 : 10)),
        ),
        icon: Icon(icon),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: primary
                      ? AppColors.teal
                      : (dark ? Colors.white70 : const Color(0xFF555861)),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _NavSpec(Icons.home_outlined, 'HOME', false,
          () => context.go(AppRoutes.homeDashboard)),
      _NavSpec(Icons.fitness_center_rounded, 'WORKOUT', false,
          () => context.go(AppRoutes.workoutHub)),
      _NavSpec(Icons.restaurant_rounded, 'NUTRITION', false,
          () => context.go(AppRoutes.nutrition)),
      _NavSpec(Icons.insert_chart_outlined_rounded, 'PROGRESS', true, () {}),
      _NavSpec(Icons.smart_toy_outlined, 'COACH', false,
          () => context.go(AppRoutes.aiCoach)),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090A) : Colors.white,
        border: Border(
            top: BorderSide(
                color: isDark
                    ? const Color(0xFF242426)
                    : const Color(0xFFEDEFF0))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: isDark ? 88 : 84,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [for (final item in items) _NavItem(item: item)],
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
    final idle =
        isDark ? const Color(0xFF72747B) : const Color(0xFFA0A2AA);
    final color = item.selected ? active : idle;

    return Material(
      color: item.selected
          ? active.withValues(alpha: isDark ? 0.13 : 0.08)
          : Colors.transparent,
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
