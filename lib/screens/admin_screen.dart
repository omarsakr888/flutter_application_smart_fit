import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../theme/app_colors.dart';

// ── Focus zone palette ────────────────────────────────────────────────────────

const _zoneColors = {
  'Upper Body Strength': Color(0xFF2563EB),
  'Lower Body Power': Color(0xFF16A34A),
  'Core Stability': Color(0xFFD97706),
  'Balanced/Recovery': Color(0xFF7C3AED),
};

Color _zoneColor(String label) =>
    _zoneColors.entries
        .firstWhere(
          (e) => label.toLowerCase().contains(e.key.toLowerCase().split(' ').first.toLowerCase()),
          orElse: () => const MapEntry('', AppColors.teal),
        )
        .value;

// ── Screen ────────────────────────────────────────────────────────────────────

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _selected = 0;

  AdminStats? _stats;
  AdminMlAnalytics? _ml;
  List<AdminUser> _users = [];
  List<AdminScan> _scans = [];
  int _totalUsers = 0;
  int _totalScans = 0;

  bool _loading = true;
  String? _error;

  static const _tabs = ['Overview', 'Users', 'ML Analytics', 'Scans'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (_tab.indexIsChanging) setState(() => _selected = _tab.index);
      });
    _fetchAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AdminService.instance.getStats(),
        AdminService.instance.getMlAnalytics(),
        AdminService.instance.getUsers(limit: 50),
        AdminService.instance.getScans(limit: 40),
      ]);
      if (!mounted) return;
      final usersResult = results[2] as ({int total, List<AdminUser> users});
      final scansResult = results[3] as ({int total, List<AdminScan> scans});
      setState(() {
        _stats = results[0] as AdminStats;
        _ml = results[1] as AdminMlAnalytics;
        _users = usersResult.users;
        _totalUsers = usersResult.total;
        _scans = scansResult.scans;
        _totalScans = scansResult.total;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090A) : const Color(0xFFF4F4F4);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;

        return Scaffold(
          backgroundColor: bg,
          body: wide
              ? _WideLayout(
                  isDark: isDark,
                  selected: _selected,
                  onSelect: (i) { setState(() => _selected = i); _tab.index = i; },
                  loading: _loading,
                  error: _error,
                  onRetry: _fetchAll,
                  stats: _stats,
                  ml: _ml,
                  users: _users,
                  totalUsers: _totalUsers,
                  scans: _scans,
                  totalScans: _totalScans,
                )
              : _NarrowLayout(
                  isDark: isDark,
                  tab: _tab,
                  loading: _loading,
                  error: _error,
                  onRetry: _fetchAll,
                  stats: _stats,
                  ml: _ml,
                  users: _users,
                  totalUsers: _totalUsers,
                  scans: _scans,
                  totalScans: _totalScans,
                ),
        );
      },
    );
  }
}

// ── Narrow (phone) ────────────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.isDark,
    required this.tab,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.stats,
    required this.ml,
    required this.users,
    required this.totalUsers,
    required this.scans,
    required this.totalScans,
  });

  final bool isDark;
  final TabController tab;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final AdminStats? stats;
  final AdminMlAnalytics? ml;
  final List<AdminUser> users;
  final int totalUsers;
  final List<AdminScan> scans;
  final int totalScans;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(isDark: isDark, onRefresh: onRetry),
        _AdminTabBar(tab: tab, isDark: isDark),
        Expanded(
          child: _Body(
            loading: loading,
            error: error,
            onRetry: onRetry,
            tab: tab,
            isDark: isDark,
            stats: stats,
            ml: ml,
            users: users,
            totalUsers: totalUsers,
            scans: scans,
            totalScans: totalScans,
          ),
        ),
      ],
    );
  }
}

// ── Wide (tablet/desktop) ─────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.isDark,
    required this.selected,
    required this.onSelect,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.stats,
    required this.ml,
    required this.users,
    required this.totalUsers,
    required this.scans,
    required this.totalScans,
  });

  final bool isDark;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final AdminStats? stats;
  final AdminMlAnalytics? ml;
  final List<AdminUser> users;
  final int totalUsers;
  final List<AdminScan> scans;
  final int totalScans;

  static const _nav = [
    ('Overview', Icons.dashboard_outlined, Icons.dashboard_rounded),
    ('Users', Icons.group_outlined, Icons.group_rounded),
    ('ML Analytics', Icons.analytics_outlined, Icons.analytics_rounded),
    ('Scans', Icons.document_scanner_outlined, Icons.document_scanner_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final sidebarBg = isDark ? const Color(0xFF111113) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2A2D) : const Color(0xFFE4E9E5);

    return Row(
      children: [
        // Sidebar
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: sidebarBg,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.shield_rounded, color: AppColors.teal, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                ..._nav.asMap().entries.map((entry) {
                  final i = entry.key;
                  final (label, outIcon, fillIcon) = entry.value;
                  final active = selected == i;
                  return _SidebarItem(
                    label: label,
                    icon: active ? fillIcon : outIcon,
                    active: active,
                    isDark: isDark,
                    onTap: () => onSelect(i),
                  );
                }),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: _RefreshButton(onRefresh: onRetry, isDark: isDark),
                ),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: Column(
            children: [
              _Header(isDark: isDark, onRefresh: onRetry, wide: true),
              Expanded(
                child: _TabContent(
                  index: selected,
                  loading: loading,
                  error: error,
                  onRetry: onRetry,
                  isDark: isDark,
                  stats: stats,
                  ml: ml,
                  users: users,
                  totalUsers: totalUsers,
                  scans: scans,
                  totalScans: totalScans,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active
            ? AppColors.teal.withValues(alpha: isDark ? 0.15 : 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active
                      ? AppColors.teal
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? AppColors.teal
                        : (isDark ? Colors.white70 : const Color(0xFF374151)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared header ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.onRefresh, this.wide = false});
  final bool isDark;
  final VoidCallback onRefresh;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF09090A) : const Color(0xFFF4F4F4),
        ),
        child: Row(
          children: [
            if (!wide)
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            if (wide) const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Smart Fit Admin',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            if (wide) _RefreshButton(onRefresh: onRefresh, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onRefresh, required this.isDark});
  final VoidCallback onRefresh;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Refresh'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.teal,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Tab bar (narrow) ──────────────────────────────────────────────────────────

class _AdminTabBar extends StatelessWidget {
  const _AdminTabBar({required this.tab, required this.isDark});
  final TabController tab;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF111113) : Colors.white,
      child: TabBar(
        controller: tab,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.teal,
        unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
        indicatorColor: AppColors.teal,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Users'),
          Tab(text: 'ML Analytics'),
          Tab(text: 'Scans'),
        ],
      ),
    );
  }
}

// ── Body (narrow uses TabBarView, wide uses indexed stack) ────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.tab,
    required this.isDark,
    required this.stats,
    required this.ml,
    required this.users,
    required this.totalUsers,
    required this.scans,
    required this.totalScans,
  });
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final TabController tab;
  final bool isDark;
  final AdminStats? stats;
  final AdminMlAnalytics? ml;
  final List<AdminUser> users;
  final int totalUsers;
  final List<AdminScan> scans;
  final int totalScans;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2),
      );
    }
    if (error != null) {
      return _ErrorView(message: error!, onRetry: onRetry);
    }
    return TabBarView(
      controller: tab,
      children: [
        _OverviewTab(stats: stats!, isDark: isDark),
        _UsersTab(users: users, total: totalUsers, isDark: isDark),
        _MlTab(ml: ml!, isDark: isDark),
        _ScansTab(scans: scans, total: totalScans, isDark: isDark),
      ],
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.index,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.isDark,
    required this.stats,
    required this.ml,
    required this.users,
    required this.totalUsers,
    required this.scans,
    required this.totalScans,
  });
  final int index;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final bool isDark;
  final AdminStats? stats;
  final AdminMlAnalytics? ml;
  final List<AdminUser> users;
  final int totalUsers;
  final List<AdminScan> scans;
  final int totalScans;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2),
      );
    }
    if (error != null) {
      return _ErrorView(message: error!, onRetry: onRetry);
    }
    return IndexedStack(
      index: index,
      children: [
        _OverviewTab(stats: stats!, isDark: isDark),
        _UsersTab(users: users, total: totalUsers, isDark: isDark),
        _MlTab(ml: ml!, isDark: isDark),
        _ScansTab(scans: scans, total: totalScans, isDark: isDark),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 1 — Overview
// ═══════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.stats, required this.isDark});
  final AdminStats stats;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Platform Statistics', isDark),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              label: 'Total Users',
              value: '${stats.totalUsers}',
              sub: '+${stats.newUsersToday} today',
              icon: Icons.group_rounded,
              accent: const Color(0xFF2563EB),
              isDark: isDark,
            ),
            _StatCard(
              label: 'InBody Scans',
              value: '${stats.totalScans}',
              sub: '+${stats.scansToday} today',
              icon: Icons.document_scanner_rounded,
              accent: AppColors.teal,
              isDark: isDark,
            ),
            _StatCard(
              label: 'Plans Generated',
              value: '${stats.totalPlans}',
              sub: '+${stats.plansToday} today',
              icon: Icons.fitness_center_rounded,
              accent: const Color(0xFF7C3AED),
              isDark: isDark,
            ),
            _StatCard(
              label: 'Workout Logs',
              value: '${stats.workoutLogsTotal}',
              sub: 'All time',
              icon: Icons.sports_gymnastics_rounded,
              accent: const Color(0xFFD97706),
              isDark: isDark,
            ),
            _StatCard(
              label: 'Meal Logs',
              value: '${stats.mealLogsTotal}',
              sub: 'All time',
              icon: Icons.restaurant_rounded,
              accent: const Color(0xFF16A34A),
              isDark: isDark,
            ),
            _StatCard(
              label: 'Hydration Logs',
              value: '${stats.hydrationLogsTotal}',
              sub: 'All time',
              icon: Icons.water_drop_rounded,
              accent: const Color(0xFF0891B2),
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionLabel('Today\'s Activity', isDark),
        const SizedBox(height: 10),
        _Card(
          isDark: isDark,
          child: Column(
            children: [
              _ActivityRow(
                label: 'New registrations',
                value: stats.newUsersToday,
                max: math.max(stats.newUsersToday, 10),
                accent: const Color(0xFF2563EB),
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _ActivityRow(
                label: 'Scans processed',
                value: stats.scansToday,
                max: math.max(stats.scansToday, 10),
                accent: AppColors.teal,
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _ActivityRow(
                label: 'Plans generated',
                value: stats.plansToday,
                max: math.max(stats.plansToday, 10),
                accent: const Color(0xFF7C3AED),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.label,
    required this.value,
    required this.max,
    required this.accent,
    required this.isDark,
  });
  final String label;
  final int value;
  final int max;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pct = max == 0 ? 0.0 : value / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: isDark
                ? const Color(0xFF2A2A2D)
                : const Color(0xFFE4E9E5),
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 2 — Users
// ═══════════════════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab({
    required this.users,
    required this.total,
    required this.isDark,
  });
  final List<AdminUser> users;
  final int total;
  final bool isDark;

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _query = '';

  List<AdminUser> get _filtered {
    if (_query.isEmpty) return widget.users;
    final q = _query.toLowerCase();
    return widget.users.where((u) {
      return u.email.toLowerCase().contains(q) ||
          u.name.toLowerCase().contains(q) ||
          (u.goal?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1F1F20)
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF2A2A2D)
                            : const Color(0xFFE4E9E5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF2A2A2D)
                            : const Color(0xFFE4E9E5),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${filtered.length} / ${widget.total}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No users found.',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _UserTile(
                    user: filtered[i],
                    isDark: isDark,
                  ),
                ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.isDark});
  final AdminUser user;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final initials = user.name.isNotEmpty
        ? user.name[0].toUpperCase()
        : user.email[0].toUpperCase();
    final goal = user.goal ?? '';
    final goalColor = _zoneColor(goal);

    return _Card(
      isDark: isDark,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.teal.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.teal,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isNotEmpty ? user.name : user.email,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                if (user.name.isNotEmpty)
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    if (goal.isNotEmpty)
                      _Chip(
                        label: goal,
                        color: goalColor,
                        isDark: isDark,
                      ),
                    if (user.dailyStreak > 0)
                      _Chip(
                        label: '🔥 ${user.dailyStreak}d',
                        color: const Color(0xFFD97706),
                        isDark: isDark,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CountBadge(
                label: 'scans',
                value: user.scanCount,
                isDark: isDark,
              ),
              const SizedBox(height: 4),
              _CountBadge(
                label: 'plans',
                value: user.planCount,
                isDark: isDark,
              ),
              const SizedBox(height: 4),
              _CountBadge(
                label: 'workouts',
                value: user.workoutCount,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 3 — ML Analytics
// ═══════════════════════════════════════════════════════════════════════════════

class _MlTab extends StatelessWidget {
  const _MlTab({required this.ml, required this.isDark});
  final AdminMlAnalytics ml;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary row ────────────────────────────────────────────────────
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              label: 'Scans Analyzed',
              value: '${ml.totalAnalyzed}',
              sub: 'Confirmed scans',
              icon: Icons.analytics_rounded,
              accent: AppColors.teal,
              isDark: isDark,
            ),
            _StatCard(
              label: 'Avg ML Confidence',
              value: '${ml.avgConfidencePct.toStringAsFixed(1)}%',
              sub: 'Stacking ensemble',
              icon: Icons.precision_manufacturing_rounded,
              accent: const Color(0xFF2563EB),
              isDark: isDark,
            ),
            _StatCard(
              label: 'Intensity Reduced',
              value: '${ml.intensityReducedCount}',
              sub: 'ECW/TBW or Phase°',
              icon: Icons.warning_amber_rounded,
              accent: const Color(0xFFD97706),
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // ── Focus Zone distribution ────────────────────────────────────────
        _SectionLabel('Focus Zone Distribution', isDark),
        const SizedBox(height: 10),
        _Card(
          isDark: isDark,
          child: Column(
            children: ml.focusZoneDistribution
                .map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _DistributionBar(
                        item: d,
                        color: _zoneColor(d.label),
                        isDark: isDark,
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        // ── Goal distribution ──────────────────────────────────────────────
        _SectionLabel('User Goal Distribution', isDark),
        const SizedBox(height: 10),
        _Card(
          isDark: isDark,
          child: Column(
            children: ml.goalDistribution
                .map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _DistributionBar(
                        item: d,
                        color: _zoneColor(d.label),
                        isDark: isDark,
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        // ── Feature averages ───────────────────────────────────────────────
        _SectionLabel('Average InBody Biomarkers', isDark),
        const SizedBox(height: 10),
        _Card(
          isDark: isDark,
          child: Column(
            children: ml.featureAverages
                .where((f) => f.avg != null && f.n > 0)
                .map((f) => _FeatureRow(feature: f, isDark: isDark))
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
        // ── Model architecture info ────────────────────────────────────────
        _SectionLabel('Model Architecture', isDark),
        const SizedBox(height: 10),
        _Card(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModelInfoRow('Type', 'Stacking Ensemble', isDark),
              _ModelInfoRow('Base Learners', 'XGBoost · LightGBM · CatBoost', isDark),
              _ModelInfoRow('Meta Learner', 'Logistic Regression', isDark),
              _ModelInfoRow('Classes', '4 Focus Zones', isDark),
              _ModelInfoRow('Input Features', '12 InBody + User Goal', isDark),
              _ModelInfoRow('Preprocessing', 'StandardScaler (joblib)', isDark),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.item,
    required this.color,
    required this.isDark,
  });
  final DistributionItem item;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.count}  (${item.pct}%)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (item.pct / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: isDark
                ? const Color(0xFF2A2A2D)
                : const Color(0xFFE4E9E5),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature, required this.isDark});
  final FeatureAverage feature;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature.label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Text(
            feature.avg != null
                ? '${feature.avg!.toStringAsFixed(1)} ${feature.unit}'
                : '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'n=${feature.n}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelInfoRow extends StatelessWidget {
  const _ModelInfoRow(this.label, this.value, this.isDark);
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 4 — Scans
// ═══════════════════════════════════════════════════════════════════════════════

class _ScansTab extends StatelessWidget {
  const _ScansTab({
    required this.scans,
    required this.total,
    required this.isDark,
  });
  final List<AdminScan> scans;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${scans.length} of $total scans',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: scans.isEmpty
              ? Center(
                  child: Text(
                    'No scans yet.',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: scans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ScanTile(
                    scan: scans[i],
                    isDark: isDark,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.scan, required this.isDark});
  final AdminScan scan;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final zone = scan.focusZone.isNotEmpty ? scan.focusZone : scan.persona;
    final zoneColor = zone.isNotEmpty ? _zoneColor(zone) : Colors.grey;
    final confPct = (scan.mlConfidence <= 1
            ? scan.mlConfidence * 100
            : scan.mlConfidence)
        .toStringAsFixed(1);
    final ocrPct = (scan.extractionConfidence * 100).toStringAsFixed(0);

    return _Card(
      isDark: isDark,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 64,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: zoneColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scan.userEmail,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusBadge(status: scan.status, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (zone.isNotEmpty)
                      _Chip(label: zone, color: zoneColor, isDark: isDark),
                    if (scan.reportType.isNotEmpty)
                      _Chip(
                        label: 'InBody ${scan.reportType}',
                        color: const Color(0xFF0891B2),
                        isDark: isDark,
                      ),
                    if (scan.intensityReduced)
                      _Chip(
                        label: '⚠ Reduced Intensity',
                        color: const Color(0xFFD97706),
                        isDark: isDark,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ScorePill(
                      label: 'ML',
                      value: '$confPct%',
                      color: AppColors.teal,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _ScorePill(
                      label: 'OCR',
                      value: '$ocrPct%',
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                    const Spacer(),
                    Text(
                      _shortDate(scan.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(String iso) {
    if (iso.length < 10) return iso;
    return iso.substring(0, 10);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isDark});
  final String status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'confirmed' => ('Confirmed', AppColors.teal),
      'pending_review' => ('Pending', const Color(0xFFD97706)),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  const _Card({
    required this.isDark,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final bool isDark;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F20) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2D) : const Color(0xFFE4E9E5),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.accent,
    required this.isDark,
  });
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;

    return SizedBox(
      width: math.max(140, math.min(width, 200)),
      child: _Card(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.isDark});
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.label,
    required this.value,
    required this.isDark,
  });
  final String label;
  final int value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.isDark);
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: isDark ? Colors.white54 : Colors.black45,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            ),
          ],
        ),
      ),
    );
  }
}
