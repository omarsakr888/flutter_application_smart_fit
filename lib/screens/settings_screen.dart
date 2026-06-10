import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/ocr_result.dart';
import '../router/app_routes.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF4F4F4),
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
          _SectionHeader('Demo & Testing', isDark),
          _SettingsTile(
            icon: Icons.science_outlined,
            iconColor: AppColors.teal,
            title: 'Load Sample Scan',
            subtitle: 'Open the AI analysis flow with demo InBody data',
            isDark: isDark,
            onTap: () {
              final demo = _buildDemoScan();
              context.push(AppRoutes.analysisLoading, extra: demo);
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
