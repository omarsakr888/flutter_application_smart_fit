import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../router/app_routes.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class SmartFitDrawer extends StatefulWidget {
  const SmartFitDrawer({super.key});

  @override
  State<SmartFitDrawer> createState() => _SmartFitDrawerState();
}

class _SmartFitDrawerState extends State<SmartFitDrawer> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final dashboard = await UserService.instance.getDashboard();
      if (mounted && dashboard != null) {
        setState(() {
          _userName = dashboard.userName;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scope = AppScope.of(context);
    final isAr = scope.locale.languageCode == 'ar';

    final bg = isDark ? const Color(0xFF121517) : Colors.white;
    final iconColor = isDark ? const Color(0xFF31D39E) : AppColors.teal;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.teal,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
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
                          isAr ? 'مرحباً' : 'Hello,',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        Text(
                          _userName.isNotEmpty ? _userName : (isAr ? 'مستخدم' : 'User'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200, height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _DrawerTile(
                    icon: Icons.dashboard_rounded,
                    title: isAr ? 'لوحة القيادة' : 'Dashboard',
                    color: iconColor,
                    textColor: textColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.homeDashboard);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.fitness_center_rounded,
                    title: isAr ? 'خطة التمرين' : 'Workout Plan',
                    color: iconColor,
                    textColor: textColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.workoutHub);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.restaurant_menu_rounded,
                    title: isAr ? 'خطة التغذية' : 'Nutrition Plan',
                    color: iconColor,
                    textColor: textColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.nutrition);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.favorite_rounded,
                    title: isAr ? 'المفضلة' : 'Favorites',
                    color: iconColor,
                    textColor: textColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.favorites);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.person_rounded,
                    title: isAr ? 'ملفي الشخصي' : 'My Profile',
                    color: iconColor,
                    textColor: textColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.profileSetup);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.settings_rounded,
                    title: isAr ? 'الإعدادات' : 'Settings',
                    color: iconColor,
                    textColor: textColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.settings);
                    },
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_rounded,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    title: Text(
                      isDark ? (isAr ? 'الوضع الفاتح' : 'Light Mode') : (isAr ? 'الوضع الداكن' : 'Dark Mode'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      scope.setThemeBrightness(isDark ? Brightness.light : Brightness.dark);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.language_rounded,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    title: Text(
                      isAr ? 'English' : 'العربية',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    onTap: () => scope.toggleLocaleEnAr(),
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

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
