import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../theme/app_colors.dart';

class SmartFitAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SmartFitAppBar({
    super.key,
    this.title,
    this.actions,
  });

  final String? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scope = AppScope.of(context);
    final isAr = scope.locale.languageCode == 'ar';

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF09090A) : Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(
          Icons.menu_rounded,
          color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
          size: 28,
        ),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: title != null
          ? Text(
              title!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
                ),
                const SizedBox(width: 8),
                Text(
                  'Smart Fit',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
      actions: actions ??
          [
            IconButton(
              tooltip: isDark ? 'Light theme' : 'Dark theme',
              onPressed: () {
                scope.setThemeBrightness(
                    isDark ? Brightness.light : Brightness.dark);
              },
              icon: Icon(
                isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_rounded,
                color: isDark ? const Color(0xFF31D39E) : const Color(0xFF6D7079),
                size: 26,
              ),
            ),
            IconButton(
              tooltip: isAr ? 'Switch to English' : 'Switch to Arabic',
              onPressed: () => scope.toggleLocaleEnAr(),
              icon: Icon(
                Icons.language_rounded,
                color: isDark ? const Color(0xFF31D39E) : const Color(0xFF6D7079),
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
          ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
