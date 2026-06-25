import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_scope.dart';
import '../models/plan_result.dart';
import '../models/user_profile.dart';
import '../router/app_routes.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';
import '../utils/responsive_utils.dart';
import '../widgets/ai_chat_fab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DashboardData? _dashboard;
  PlanResult? _plan;

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
        padding: EdgeInsets.symmetric(vertical: context.heightPct(0.02)),
        children: [
          // ── Profile summary card ──────────────────────────────────────────
          _SectionHeader('Your Profile', isDark),
          _ProfileCard(dashboard: d, plan: p, isDark: isDark),
          const SizedBox(height: 8),
          // ── Preferences ───────────────────────────────────────────────────
          _SectionHeader('Preferences', isDark),
          _SettingsTile(
            icon: Icons.palette_outlined,
            iconColor: Colors.purple,
            title: 'Theme',
            subtitle: _themeModeString(AppScope.of(context).themeMode),
            isDark: isDark,
            onTap: () => _showThemePicker(context),
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

  String _themeModeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }

  void _showThemePicker(BuildContext context) {
    final scope = AppScope.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                'Select Theme',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: Text('System Default'.tr(context)),
                trailing: scope.themeMode == ThemeMode.system ? const Icon(Icons.check, color: AppColors.teal) : null,
                onTap: () {
                  scope.setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: Text('Light Mode'.tr(context)),
                trailing: scope.themeMode == ThemeMode.light ? const Icon(Icons.check, color: AppColors.teal) : null,
                onTap: () {
                  scope.setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text('Dark Mode'.tr(context)),
                trailing: scope.themeMode == ThemeMode.dark ? const Icon(Icons.check, color: AppColors.teal) : null,
                onTap: () {
                  scope.setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log out?'.tr(context)),
        content: Text('You will be returned to the login screen.'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr(context)),
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

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.dashboard,
    required this.plan,
    required this.isDark,
  });

  final DashboardData? dashboard;
  final PlanResult? plan;
  final bool isDark;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _imagePath = prefs.getString('profile_image_path');
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', pickedFile.path);
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.dashboard?.userName ?? '';
    final streak = widget.dashboard?.streak ?? 0;
    final calories = widget.plan?.targetCaloriesKcal.round();
    final protein = widget.plan?.macros.proteinG.round();
    final carbs = widget.plan?.macros.carbsG.round();
    final fat = widget.plan?.macros.fatG.round();
    final focus = widget.plan?.focusZone ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.widthPct(0.04), vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1F1F20) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDark ? const Color(0xFF2A2A2D) : const Color(0xFFE4E9E5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: widget.dashboard == null && widget.plan == null
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
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.teal,
                            backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
                            child: _imagePath == null ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ) : null,
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
                                      color: widget.isDark
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
                                        color: widget.isDark
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
                              color: widget.isDark
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
                        color: widget.isDark
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
                              isDark: widget.isDark),
                          _StatChip(
                              label: 'Protein',
                              value: '${protein ?? 0}g',
                              isDark: widget.isDark),
                          _StatChip(
                              label: 'Carbs',
                              value: '${carbs ?? 0}g',
                              isDark: widget.isDark),
                          _StatChip(
                              label: 'Fat',
                              value: '${fat ?? 0}g',
                              isDark: widget.isDark),
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
