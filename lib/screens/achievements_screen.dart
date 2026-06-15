import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_chat_fab.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<AchievementData> _achievements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final list = await UserService.instance.getAchievements();
      if (mounted) setState(() { _achievements = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final earnedCount = _achievements.where((a) => a.earned).length;

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
          'Achievements',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Text(
                    '$earnedCount / ${_achievements.length}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _achievements.isEmpty
              ? _EmptyState(isDark: isDark)
              : RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _fetch,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: _achievements.length,
                    itemBuilder: (_, i) => _BadgeCard(
                      achievement: _achievements[i],
                      isDark: isDark,
                    ),
                  ),
                ),
    );
  }
}

// ── Badge card ────────────────────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.achievement, required this.isDark});

  final AchievementData achievement;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final earned = achievement.earned;
    final cardBg = isDark ? const Color(0xFF1F1F20) : Colors.white;
    final iconEmoji = _emojiForType(achievement.type);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: earned
            ? Border.all(
                color: AppColors.teal.withValues(alpha: 0.45), width: 1.5)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: earned
                        ? AppColors.teal.withValues(alpha: 0.13)
                        : (isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF0F0F0)),
                  ),
                ),
                ColorFiltered(
                  colorFilter: earned
                      ? const ColorFilter.mode(
                          Colors.transparent, BlendMode.multiply)
                      : const ColorFilter.matrix([
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      1, 0,
                        ]),
                  child: Text(
                    iconEmoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
                if (!earned)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFE0E0E0),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child:
                            Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              achievement.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: earned
                        ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                        : (isDark ? Colors.white38 : Colors.grey),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    height: 1.35,
                  ),
            ),
            if (earned && achievement.earnedAt != null) ...[
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  child: Text(
                    _formatDate(achievement.earnedAt!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _emojiForType(String type) {
    return switch (type) {
      'first_scan' => '🔬',
      '7_day_streak' => '🔥',
      '30_day_streak' => '⚡',
      'muscle_gainer_2kg' => '💪',
      'fat_burner_5_percent' => '🏆',
      _ => '🎖️',
    };
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: isDark ? Colors.white24 : const Color(0xFFCDD0D5),
            ),
            const SizedBox(height: 20),
            Text(
              'No achievements yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white60 : const Color(0xFF667085),
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Complete workouts, log meals, and\nstay consistent to earn badges.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
