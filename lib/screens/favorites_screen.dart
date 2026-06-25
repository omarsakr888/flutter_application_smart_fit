import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';

import '../providers/favorites_provider.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/smart_fit_app_bar.dart';
import '../widgets/smart_fit_drawer.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final isAr = scope.locale.languageCode == 'ar';
    final favState = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: SmartFitAppBar(title: isAr ? 'المفضلة' : 'Favorites'),
      drawer: const SmartFitDrawer(),
      body: favState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: AppColors.teal,
                    unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    indicatorColor: AppColors.teal,
                    tabs: [
                      Tab(text: isAr ? 'التمارين' : 'Workouts'),
                      Tab(text: isAr ? 'الوصفات' : 'Recipes'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildWorkoutsList(context, ref, favState.workouts, isAr),
                        _buildMealsList(context, ref, favState.meals, isAr),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWorkoutsList(BuildContext context, WidgetRef ref, List workouts, bool isAr) {
    if (workouts.isEmpty) {
      return Center(
        child: Text(
          isAr ? 'لا توجد تمارين مفضلة بعد.' : 'No favorite workouts yet.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workouts.length,
      itemBuilder: (ctx, i) {
        final w = workouts[i];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(w.dayLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(w.focusZone),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
              onPressed: () => ref.read(favoritesProvider.notifier).toggleWorkout(w),
            ),
            onTap: () {
              // Usually we'd open a workout detail. We can just go to Workout Hub for now.
              context.go(AppRoutes.workoutHub);
            },
          ),
        );
      },
    );
  }

  Widget _buildMealsList(BuildContext context, WidgetRef ref, List meals, bool isAr) {
    if (meals.isEmpty) {
      return Center(
        child: Text(
          isAr ? 'لا توجد وصفات مفضلة بعد.' : 'No favorite recipes yet.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meals.length,
      itemBuilder: (ctx, i) {
        final m = meals[i];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _buildMealThumbnail(context, m.imageUrl, m.slotName),
            title: Text(m.recipeName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${m.caloriesPerServing.toInt()} kcal - ${m.proteinG.toInt()}g P'),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
              onPressed: () => ref.read(favoritesProvider.notifier).toggleMeal(m),
            ),
            onTap: () {
              context.push(AppRoutes.recipeDetail, extra: m);
            },
          ),
        );
      },
    );
  }

  String _fallbackAssetFor(String slotTitle) {
    final clean = slotTitle.toLowerCase();
    if (clean.contains('breakfast')) return 'assets/images/breakfast.png';
    if (clean.contains('lunch')) return 'assets/images/lunch.png';
    if (clean.contains('dinner')) return 'assets/images/dinner.png';
    if (clean.contains('snack')) return 'assets/images/snack.png';
    if (clean.contains('protein')) return 'assets/images/protein_meal.png';
    return 'assets/images/healthy_food.png';
  }

  Widget _buildMealThumbnail(BuildContext context, String? imageUrl, String slotName) {
    const size = 48.0;
    final fallbackAsset = _fallbackAssetFor(slotName);

    Widget imageWidget;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 96,
        cacheHeight: 96,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.teal),
              ),
            ),
          );
        },
        errorBuilder: (context, err, stack) {
          return Image.asset(fallbackAsset, width: size, height: size, fit: BoxFit.cover);
        },
      );
    } else {
      imageWidget = Image.asset(fallbackAsset, width: size, height: size, fit: BoxFit.cover);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageWidget,
    );
  }
}
