import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/smart_fit_theme.dart';

class InBodyScanScreen extends StatefulWidget {
  const InBodyScanScreen({super.key});

  @override
  State<InBodyScanScreen> createState() => _InBodyScanScreenState();
}

class _InBodyScanScreenState extends State<InBodyScanScreen> {
  bool _uploaded = false;

  static const _metrics = [
    _Metric('Age', '28', 'yrs'),
    _Metric('Weight', '78.4', 'kg'),
    _Metric('Skeletal Muscle Mass', '38.2', 'kg'),
    _Metric('Body Fat Mass', '14.1', 'kg'),
    _Metric('Body Mass Index (BMI)', '25.2', 'kg/m2'),
    _Metric('Percent Body Fat (PBF)', '18.0', '%'),
    _Metric('Basal Metabolic Rate', '1842', 'kcal'),
    _Metric('Visceral Fat Level', '7', 'lvl'),
    _Metric('Total Body Water', '46.8', 'L'),
    _Metric('Lean Body Mass', '64.3', 'kg'),
    _Metric('Height', '176', 'cm'),
    _Metric('Protein', '12.4', 'kg'),
  ];

  void _markUploaded() => setState(() => _uploaded = true);

  void _confirm() {
    if (!_uploaded) return;
    context.push(AppRoutes.analysisLoading);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final ext = context.smartFitExt;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              isDark: isDark,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.profileSetupStep2);
                }
              },
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2C3335) : const Color(0xFFECEFF0),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, isDark ? 28 : 48, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Upload your InBody\nscan',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Supports InBody 120, 270, and 570',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? Colors.white70 : const Color(0xFF333A3C),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (_uploaded)
                      const _UploadedState()
                    else
                      _UploadState(onUpload: _markUploaded),
                    if (_uploaded) ...[
                      const SizedBox(height: 34),
                      _MetricsHeader(count: _metrics.length),
                      const SizedBox(height: 14),
                      for (final metric in _metrics) ...[
                        _MetricTile(metric: metric),
                        const SizedBox(height: 8),
                      ],
                    ] else ...[
                      const SizedBox(height: 78),
                      const _TipsCard(),
                    ],
                    SizedBox(height: isDark ? 64 : 22),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF29302F) : Colors.transparent,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  14 + MediaQuery.paddingOf(context).bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _uploaded
                          ? const Color(0xFF2DB994)
                          : AppColors.teal.withValues(alpha: 0.55),
                      disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.55),
                      disabledForegroundColor: Colors.white,
                      foregroundColor: Colors.white,
                      elevation: _uploaded ? 8 : 0,
                      shadowColor: AppColors.teal.withValues(alpha: 0.22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isDark ? 8 : 7),
                      ),
                    ),
                    onPressed: _uploaded ? _confirm : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confirm & Analyze',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.check_circle_outline_rounded, size: 28),
                      ],
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

class _Metric {
  const _Metric(this.label, this.value, this.unit);

  final String label;
  final String value;
  final String unit;
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
      height: isDark ? 52 : 92,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isDark ? 12 : 26, 6, isDark ? 18 : 36, 6),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                size: isDark ? 21 : 34,
                color: isDark ? Colors.white : const Color(0xFF667384),
              ),
            ),
            if (!isDark) ...[
              const SizedBox(width: 18),
              Text(
                'Smart Fit',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
            const Spacer(),
            _ThemeSegment(
              isDark: isDark,
              compact: isDark,
              onLight: onLight,
              onDark: onDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
    required this.isDark,
    required this.compact,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;
  final bool compact;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF202927) : const Color(0xFFF2F4F5);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF3B4642) : const Color(0xFFF6F7F8),
          width: compact ? 0.8 : 4,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 3 : 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeSegmentButton(
              selected: !isDark,
              compact: compact,
              icon: Icons.wb_sunny_outlined,
              onTap: onLight,
            ),
            SizedBox(width: compact ? 3 : 6),
            _ThemeSegmentButton(
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

class _ThemeSegmentButton extends StatelessWidget {
  const _ThemeSegmentButton({
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
    final idle = isDark ? Colors.white54 : const Color(0xFF8B97A8);

    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: compact ? 28 : 58,
          height: compact ? 28 : 58,
          child: Icon(
            icon,
            color: selected ? Colors.white : idle,
            size: compact ? 17 : 30,
          ),
        ),
      ),
    );
  }
}

class _UploadState extends StatelessWidget {
  const _UploadState({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = context.smartFitExt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFFF2F8F4),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onUpload,
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(
              painter: _DashedBorderPainter(),
              child: SizedBox(
                height: 330,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const SizedBox(
                        width: 96,
                        height: 96,
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.teal,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'Take a photo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Align the scan within the\ngrid',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: ext.mutedText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 34),
        TextButton.icon(
          onPressed: onUpload,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.teal,
            textStyle: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.file_upload_outlined, size: 30),
          label: const Text('Or upload from gallery'),
        ),
      ],
    );
  }
}

class _UploadedState extends StatelessWidget {
  const _UploadedState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2DB994)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.26),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF2DB994),
                      size: 23,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Scan uploaded successfully\nOCR extracted 12 metrics -\nplease verify below',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1.95,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _ScanPreviewPainter()),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF576160)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: Text(
                        'PREVIEW_SCAN_01.JPG',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 16,
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF2DB994), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'View Original',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF2DB994),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E3E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Icon(
                  Icons.description_outlined,
                  color: AppColors.teal,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips for success',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ensure lighting is even and text is sharp for the AI to analyze your metrics accurately.',
                    style: theme.textTheme.titleSmall?.copyWith(
                      height: 1.28,
                      color: const Color(0xFF1D2425),
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

class _MetricsHeader extends StatelessWidget {
  const _MetricsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'VERIFY & CORRECT VALUES',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.25,
                ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.23),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Text(
              '$count Metrics Found',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF2DB994),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF151D18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                metric.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Text(
              metric.value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF2DB994),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 34,
              child: Text(
                metric.unit,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB6C6BF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 9).clamp(0.0, metric.length).toDouble();
        final extract = metric.extractPath(distance, end);
        canvas.drawPath(extract, paint);
        distance += 17;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0D211F),
          Color(0xFF111514),
          Color(0xFF173A35),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final paper = Paint()..color = const Color(0xFF103B36).withValues(alpha: 0.82);
    final paperRect = Rect.fromLTWH(
      size.width * 0.23,
      size.height * 0.14,
      size.width * 0.58,
      size.height * 0.72,
    );
    canvas.save();
    canvas.translate(size.width * 0.04, size.height * 0.08);
    canvas.rotate(-0.23);
    canvas.drawRRect(
      RRect.fromRectAndRadius(paperRect, const Radius.circular(8)),
      paper,
    );

    final line = Paint()
      ..color = const Color(0xFF2DB994).withValues(alpha: 0.42)
      ..strokeWidth = 2;
    for (var i = 0; i < 9; i++) {
      final y = paperRect.top + 28 + (i * 16);
      canvas.drawLine(
        Offset(paperRect.left + 20, y),
        Offset(paperRect.right - 28, y),
        line,
      );
    }
    for (var i = 0; i < 5; i++) {
      final x = paperRect.left + 240 + (i * 16);
      final h = 18.0 + (i * 9);
      canvas.drawRect(
        Rect.fromLTWH(x, paperRect.bottom - h - 34, 9, h),
        Paint()..color = const Color(0xFF2DB994).withValues(alpha: 0.5),
      );
    }
    canvas.restore();

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
