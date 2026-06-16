import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/ocr_result.dart';
import '../models/plan_result.dart';
import '../models/user_profile.dart';
import '../router/app_routes.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_chat_fab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DashboardData? _dashboard;
  PlanResult? _plan;

  static OcrExtractResult _buildDemoScan() {
    OcrFieldResult _f(double v) => OcrFieldResult(
          value: v,
          unit: '',
          confidence: 1.0,
          isImputed: false,
        );

    return OcrExtractResult(
      extractionId: 'demo-scan-001',
      fields: {
        'Age': _f(28),
        'Gender': _f(1),
        'Height': _f(175),
        'Weight': _f(78),
        'SMM_(Skeletal_Muscle_Mass)': _f(35),
        'BMR_(Basal_Metabolic_Rate)': _f(1750),
        'FFM_of_Trunk': _f(28),
        'TBW_(Total_Body_Water)': _f(45),
        'ECW/TBW': _f(0.38),
        '50kHz-Whole_Body_Phase_Angle': _f(5.7),
        'BFM_(Body_Fat_Mass)': _f(15),
        'PBF_(Percent_Body_Fat)': _f(19),
      },
      missingFields: const [],
      warnings: const [],
    );
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final results = await Future.wait([
        UserService.instance.getDashboard(),
        UserService.instance.getPlan(),
      ]);
      if (mounted) {
        setState(() {
          _dashboard = results[0] as DashboardData?;
          _plan = results[1] as PlanResult?;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = _dashboard;
    final p = _plan;

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF4F4F4),
      floatingActionButton: const AiChatFab(),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF09090A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── Profile summary card ──────────────────────────────────────────
          _SectionHeader('Your Profile', isDark),
          _ProfileCard(dashboard: d, plan: p, isDark: isDark),
          const SizedBox(height: 8),
          // ── Demo & testing ────────────────────────────────────────────────
          _SectionHeader('Demo & Testing', isDark),
          _SettingsTile(
            icon: Icons.science_outlined,
            iconColor: AppColors.teal,
            title: 'Load Sample Scan',
            subtitle: 'Open the AI analysis flow with demo InBody data',
            isDark: isDark,
            onTap: () {
              final demo = _buildDemoScan();
              context.push(AppRoutes.planGeneration, extra: demo);
            },
          ),
          const SizedBox(height: 8),
          _SectionHeader('Activity', isDark),
          _SettingsTile(
            icon: Icons.emoji_events_outlined,
            iconColor: const Color(0xFFD97706),
            title: 'Achievements',
            subtitle: 'View your earned badges and milestones',
            isDark: isDark,
            onTap: () => context.push(AppRoutes.achievements),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Account', isDark),
          _SettingsTile(
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFB80000),
            title: 'Log Out',
            subtitle: 'Sign out of your Smart Fit account',
            isDark: isDark,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: Color(0xFFB80000)),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.dashboard,
    required this.plan,
    required this.isDark,
  });

  final DashboardData? dashboard;
  final PlanResult? plan;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final name = dashboard?.userName ?? '';
    final streak = dashboard?.streak ?? 0;
    final calories = plan?.targetCaloriesKcal.round();
    final protein = plan?.macros.proteinG.round();
    final carbs = plan?.macros.carbsG.round();
    final fat = plan?.macros.fatG.round();
    final focus = plan?.focusZone ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F20) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2D) : const Color(0xFFE4E9E5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: dashboard == null && plan == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.teal),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.teal,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isNotEmpty ? name : 'User',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
                                    ),
                              ),
                              if (focus.isNotEmpty)
                                Text(
                                  focus,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isDark
                                            ? const Color(0xFF31D39E)
                                            : AppColors.teal,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        if (streak > 0)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3B2818)
                                  : const Color(0xFFFFF3E8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.local_fire_department_rounded,
                                      color: Colors.orange,
                                      size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$streak days',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: const Color(0xFFE07820),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (calories != null) ...[
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF2A2A2D)
                            : const Color(0xFFF0F1F2),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatChip(
                              label: 'Calories',
                              value: '$calories kcal',
                              isDark: isDark),
                          _StatChip(
                              label: 'Protein',
                              value: '${protein ?? 0}g',
                              isDark: isDark),
                          _StatChip(
                              label: 'Carbs',
                              value: '${carbs ?? 0}g',
                              isDark: isDark),
                          _StatChip(
                              label: 'Fat',
                              value: '${fat ?? 0}g',
                              isDark: isDark),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.isDark});

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.isDark);

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: isDark ? const Color(0xFF1F1F20) : Colors.white,
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A),
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF9CA3AF),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
