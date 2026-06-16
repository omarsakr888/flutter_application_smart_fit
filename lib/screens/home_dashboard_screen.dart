import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../models/user_profile.dart';
import '../router/app_routes.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_chat_fab.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DashboardData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await UserService.instance.getDashboard();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load dashboard data. Check your connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final d = _data;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _SettingsDrawer(dashboardData: d),
      bottomNavigationBar: const _BottomNav(),
      floatingActionButton: const AiChatFab(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_loading)
              LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.teal,
                backgroundColor: AppColors.teal.withValues(alpha: 0.12),
              ),
            _DashboardHeader(
              isDark: isDark,
              userName: d?.userName ?? '',
              streak: d?.streak ?? 5,
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
              onSettingsTap: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEDEFF0),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, isDark ? 58 : 26, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _CaloriesCard(
                            fraction: d?.caloriesFraction ?? 0.73,
                            consumed: d?.caloriesConsumedInt ?? 1642,
                            target: d?.caloriesTargetInt ?? 2240,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _HydrationCard(
                            cups: d?.hydrationCups ?? 5,
                            total: d?.hydrationTarget ?? 8,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isDark ? 28 : 32),
                    if (isDark)
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.go(AppRoutes.workoutHub),
                              child: _ActionCard.workoutDark(
                                subtitle: d?.todayWorkoutLabel ?? 'Push Day',
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.go(AppRoutes.nutrition),
                              child: _ActionCard.mealDark(
                                subtitle: d?.nextMeal ?? 'Lunch',
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.workoutHub),
                        child: _ActionCard.workoutLight(
                          subtitle: d?.todayWorkoutLabel ?? 'Push Day',
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.nutrition),
                        child: _ActionCard.mealLight(subtitle: d?.nextMeal ?? 'Lunch'),
                      ),
                    ],
                    SizedBox(height: isDark ? 28 : 34),
                    _RecoveryCard(
                      insight: d?.recoveryInsight ??
                          (isDark
                              ? 'Your ECW Ratio is slightly elevated today. Prioritize hydration and consider an extra 500ml of water before your session.'
                              : 'Your current ECW Ratio suggests mild inflammation. Increase water intake by 2 cups today to optimize recovery.'),
                    ),
                    SizedBox(height: isDark ? 48 : 34),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Achievements',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.achievements),
                          child: Text(
                            'View All',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isDark ? const Color(0xFF2DB994) : AppColors.teal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _AchievementRow(),
                    const SizedBox(height: 34),
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

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.isDark,
    required this.userName,
    required this.streak,
    required this.onLight,
    required this.onDark,
    required this.onSettingsTap,
  });

  final bool isDark;
  final String userName;
  final int streak;
  final VoidCallback onLight;
  final VoidCallback onDark;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final isAr = scope.locale.languageCode == 'ar';

    return SizedBox(
      height: isDark ? 112 : 98,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, isDark ? 0 : 12, 20, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'صباح الخير' : 'Good morning',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isDark ? const Color(0xFF777777) : const Color(0xFF111827),
                      fontWeight: isDark ? FontWeight.w300 : FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userName.isEmpty ? (isAr ? 'يا بطل' : 'there') : userName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: isDark ? Colors.white : AppColors.teal,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  _StreakPill(days: streak),
                  const SizedBox(width: 18),
                  _ThemeSegment(isDark: isDark, onLight: onLight, onDark: onDark),
                  const SizedBox(width: 18),
                  _AvatarCircle(initial: userName.isNotEmpty ? userName[0].toUpperCase() : 'U'),
                  const SizedBox(width: 18),
                  _SettingsButton(onTap: onSettingsTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B2818) : const Color(0xFFFFF7EF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF604026) : const Color(0xFFF4E6D9),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDark ? 18 : 22,
          vertical: isDark ? 9 : 10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded,
                color: Colors.orange, size: isDark ? 28 : 30),
            const SizedBox(width: 8),
            Text(
              '$days Day\nStreak',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDark ? const Color(0xFFFFB04A) : const Color(0xFFA64724),
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
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
        color: isDark ? const Color(0xFF202927) : const Color(0xEEF0F4EF),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idle = isDark ? Colors.white38 : const Color(0xFF8B9299);

    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, color: selected ? Colors.white : idle, size: 28),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 31,
      backgroundColor: AppColors.teal,
      child: Text(
        initial,
        style: const TextStyle(
            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({
    required this.fraction,
    required this.consumed,
    required this.target,
  });

  final double fraction;
  final int consumed;
  final int target;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFF8B8E8E) : const Color(0xFF333A3C);
    final pct = (fraction * 100).round();

    return _MetricShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: isDark ? 136 : 128,
            height: isDark ? 136 : 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: isDark ? 14 : 11,
                  strokeCap: StrokeCap.butt,
                  color: isDark ? const Color(0xFF2DB994) : AppColors.teal,
                  backgroundColor:
                      isDark ? const Color(0xFF303030) : const Color(0xFFE4ECE8),
                ),
                Text(
                  '$pct%',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          SizedBox(height: isDark ? 26 : 34),
          Text(
            isDark ? 'Calories' : 'CALORIES',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w400,
                  letterSpacing: isDark ? 0 : 0.4,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_fmt(consumed)} / ${_fmt(target)}',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            isDark ? 'kcal remaining' : 'kcal',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      isDark ? const Color(0xFF7F807F) : Colors.black,
                ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return '$n';
  }
}

class _HydrationCard extends StatelessWidget {
  const _HydrationCard({required this.cups, required this.total});

  final int cups;
  final int total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _MetricShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: isDark ? 18 : 14,
            runSpacing: 14,
            children: [
              for (var i = 0; i < total; i++)
                Icon(
                  Icons.water_drop_outlined,
                  color: i < cups
                      ? (isDark ? const Color(0xFF2DB994) : AppColors.teal)
                      : (isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFDDE2DF)),
                  size: isDark ? 37 : 35,
                ),
            ],
          ),
          SizedBox(height: isDark ? 38 : 42),
          Text(
            isDark ? 'Hydration' : 'HYDRATION',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? const Color(0xFF8B8E8E) : const Color(0xFF333A3C),
                  fontWeight: FontWeight.w400,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            isDark ? '$cups / $total' : '$cups / $total cups',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          if (isDark) ...[
            const SizedBox(height: 8),
            Text(
              'cups today',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF7F807F),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricShell extends StatelessWidget {
  const _MetricShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 14 : 15),
        border:
            Border.all(color: isDark ? const Color(0xFF343434) : const Color(0xFFE2E5E5)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: SizedBox(height: isDark ? 368 : 352, child: child),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard.workoutLight({String? subtitle})
      : title = 'Start Workout',
        _subtitle = subtitle ?? 'Push Day',
        compact = false,
        selected = true,
        light = true,
        icon = Icons.fitness_center_rounded;

  const _ActionCard.mealLight({String? subtitle})
      : title = 'Next Meal',
        _subtitle = subtitle ?? 'Lunch',
        compact = false,
        selected = false,
        light = true,
        icon = Icons.restaurant_rounded;

  const _ActionCard.workoutDark({String? subtitle})
      : title = 'START\nWORKOUT',
        _subtitle = subtitle ?? 'Push Day',
        compact = true,
        selected = true,
        light = false,
        icon = Icons.fitness_center_rounded;

  const _ActionCard.mealDark({String? subtitle})
      : title = 'NEXT MEAL',
        _subtitle = subtitle ?? 'Lunch',
        compact = true,
        selected = false,
        light = false,
        icon = Icons.restaurant_rounded;

  final String title;
  final String _subtitle;
  final bool compact;
  final bool selected;
  final bool light;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (light ? AppColors.teal : const Color(0xFF2DB994))
        : (light ? const Color(0xFF7B7B7B) : const Color(0xFF282828));
    final iconBg = selected
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: light ? 0.1 : 0.06);
    final muted = light ? Colors.white70 : const Color(0xFF777B78);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 14 : 15),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 28 : 24),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(compact ? 10 : 18),
              ),
              child: SizedBox(
                width: compact ? 72 : 76,
                height: compact ? 72 : 76,
                child: Icon(icon, color: Colors.white, size: compact ? 36 : 38),
              ),
            ),
            SizedBox(width: compact ? 22 : 26),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: compact
                              ? (selected ? Colors.white : muted)
                              : Colors.white,
                          fontWeight:
                              compact ? FontWeight.w800 : FontWeight.w400,
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight:
                              compact ? FontWeight.w400 : FontWeight.w300,
                        ),
                  ),
                ],
              ),
            ),
            if (!compact)
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 38),
          ],
        ),
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.insight});

  final String insight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C260A) : const Color(0xFFFFFCED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? const Color(0xFF5D4B12) : const Color(0xFFF7DF6E)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, isDark ? 30 : 24, 28, isDark ? 30 : 26),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF4A400A) : const Color(0xFFFFEE9B),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 76,
                height: 76,
                child: Icon(Icons.lightbulb_outline_rounded,
                    color: Color(0xFFE8D11A), size: 38),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: isDark
                          ? 'Recovery Insight\n'
                          : 'Smart Tip: Recovery Alert\n',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFE4D419)
                            : const Color(0xFF7A2E1C),
                      ),
                    ),
                    TextSpan(text: insight),
                  ],
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isDark
                          ? const Color(0xFFE4D419)
                          : const Color(0xFF7A2E1C),
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _Achievement(
          label: 'First Scan',
          icon: Icons.emoji_events_rounded,
          color: AppColors.teal,
          unlocked: true),
      _Achievement(
          label: '5-Day Streak',
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFF7A2A),
          unlocked: true),
      _Achievement(
          label: 'Muscle Gainer',
          icon: Icons.lock_outline_rounded,
          color: isDark ? const Color(0xFF202020) : const Color(0xFFF7F7F7),
          unlocked: false),
      _Achievement(
          label: isDark ? 'Meal Master' : '',
          icon: Icons.lock_outline_rounded,
          color: isDark ? const Color(0xFF202020) : const Color(0xFFF7F7F7),
          unlocked: false),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _AchievementBadge(item: item),
            const SizedBox(width: 28),
          ],
        ],
      ),
    );
  }
}

class _Achievement {
  const _Achievement({
    required this.label,
    required this.icon,
    required this.color,
    required this.unlocked,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool unlocked;
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({required this.item});

  final _Achievement item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = item.unlocked
        ? item.color
        : (isDark ? const Color(0xFF242424) : const Color(0xFFF2F2F2));
    final iconColor = item.unlocked
        ? (item.color == AppColors.teal
            ? const Color(0xFFE9D25B)
            : Colors.orange)
        : (isDark ? const Color(0xFF444444) : const Color(0xFFD4D4D4));

    return SizedBox(
      width: isDark ? 104 : 112,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111514)
                      : color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Icon(item.icon, color: iconColor, size: 36),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: item.unlocked
                      ? Theme.of(context).colorScheme.onSurface
                      : (isDark
                          ? const Color(0xFF535353)
                          : const Color(0xFFC8C8C8)),
                ),
          ),
        ],
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
      _NavSpec(Icons.home_outlined, 'Home', true, () {}),
      _NavSpec(Icons.fitness_center_rounded, 'Workout', false,
          () => context.go(AppRoutes.workoutHub)),
      _NavSpec(Icons.restaurant_rounded, 'Nutrition', false,
          () => context.go(AppRoutes.nutrition)),
      _NavSpec(Icons.trending_up_rounded, 'Progress', false,
          () => context.go(AppRoutes.progress)),
      _NavSpec(Icons.smart_toy_outlined, 'Coach', false,
          () => context.go(AppRoutes.aiCoach)),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : Colors.white,
        border: Border(
            top: BorderSide(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFEDEFF0))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 84,
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
    final active = isDark ? const Color(0xFF2DB994) : AppColors.teal;
    final idle = isDark ? const Color(0xFF6E7772) : const Color(0xFF92A0AF);
    final color = item.selected ? active : idle;

    return Material(
      color: item.selected
          ? active.withValues(alpha: isDark ? 0.12 : 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 84,
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 28),
              const SizedBox(height: 5),
              Text(
                item.label,
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

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF202927) : const Color(0xEEF0F4EF),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            Icons.settings_rounded,
            color: isDark ? const Color(0xFF2DB994) : AppColors.teal,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({required this.dashboardData});

  final DashboardData? dashboardData;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = scope.locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = l.languageCode == 'ar';

    final name = dashboardData?.userName ?? '';

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF161617) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.teal,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : (isAr ? 'أهلاً بك' : 'Welcome'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr ? 'إعدادات سمارت فت' : 'Smart Fit Settings',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2A2A2D) : const Color(0xFFE4E9E5),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _DrawerHeaderLabel(title: isAr ? 'الملف البدني والحساب' : 'Account & Body Profile', isDark: isDark),
                  _DrawerTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: AppColors.teal,
                    title: isAr ? 'ملف التعريف والخطط' : 'Profile & Plans',
                    subtitle: isAr ? 'عرض احتياجات الطاقة والماكروز' : 'View energy targets & macros',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context); // close drawer
                      context.push(AppRoutes.settings);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.tune_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    title: isAr ? 'تعديل البيانات البدنية' : 'Edit Physical Metrics',
                    subtitle: isAr ? 'تحديث الوزن، الطول، والهدف الرئيسي' : 'Update weight, height, & primary goal',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context); // close drawer
                      context.push(AppRoutes.profileSetup);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.emoji_events_outlined,
                    iconColor: const Color(0xFFD97706),
                    title: isAr ? 'الإنجازات' : 'Achievements',
                    subtitle: isAr ? 'الأوسمة والملفات المحققة' : 'Milestones and badges earned',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context); // close drawer
                      context.push(AppRoutes.achievements);
                    },
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF2A2A2D) : const Color(0xFFE4E9E5),
                  ),
                  _DrawerHeaderLabel(title: isAr ? 'تفضيلات التطبيق' : 'App Preferences', isDark: isDark),
                  
                  // Language Toggle Tile
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Material(
                      color: isDark ? const Color(0xFF1F1F20) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          scope.toggleLocaleEnAr();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(Icons.language_rounded, color: Color(0xFF10B981), size: 22),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isAr ? 'لغة التطبيق' : 'App Language',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isAr ? 'العربية (تغيير للإنجليزية)' : 'English (Change to Arabic)',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.sync_rounded,
                                color: isDark ? Colors.white24 : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Theme Switch Tile
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Material(
                      color: isDark ? const Color(0xFF1F1F20) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                                  color: const Color(0xFF8B5CF6),
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAr ? 'الوضع الداكن' : 'Dark Theme',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAr ? 'تفعيل الوضع المظلم' : 'Toggle dark mode appearance',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: isDark,
                              activeTrackColor: AppColors.teal,
                              onChanged: (val) {
                                scope.setThemeBrightness(val ? Brightness.dark : Brightness.light);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF2A2A2D) : const Color(0xFFE4E9E5),
                  ),
                  _DrawerHeaderLabel(title: isAr ? 'الحساب' : 'Session', isDark: isDark),
                  _DrawerTile(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: isAr ? 'تسجيل الخروج' : 'Log Out',
                    subtitle: isAr ? 'إنهاء الجلسة الحالية والعودة' : 'Sign out of your account',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context); // close drawer
                      _confirmLogout(context, isAr);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, bool isAr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تسجيل الخروج؟' : 'Log out?'),
        content: Text(isAr ? 'سيتم إرجاعك إلى شاشة تسجيل الدخول.' : 'You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isAr ? 'خروج' : 'Log out',
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await AuthService.instance.logout();
      context.go(AppRoutes.logIn);
    }
  }
}

class _DrawerHeaderLabel extends StatelessWidget {
  const _DrawerHeaderLabel({required this.title, required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isDark ? const Color(0xFF1F1F20) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
