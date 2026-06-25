import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/plan_result.dart';

final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(FavoritesNotifier.new);

class FavoritesState {
  final List<WorkoutDay> workouts;
  final List<MealSlot> meals;
  final bool isLoading;

  FavoritesState({
    this.workouts = const [],
    this.meals = const [],
    this.isLoading = true,
  });

  FavoritesState copyWith({
    List<WorkoutDay>? workouts,
    List<MealSlot>? meals,
    bool? isLoading,
  }) {
    return FavoritesState(
      workouts: workouts ?? this.workouts,
      meals: meals ?? this.meals,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FavoritesNotifier extends Notifier<FavoritesState> {
  @override
  FavoritesState build() {
    _load();
    return FavoritesState();
  }

  static const _workoutsKey = 'fav_workouts';
  static const _mealsKey = 'fav_meals';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final wJson = prefs.getStringList(_workoutsKey) ?? [];
    final workouts = wJson.map((e) => WorkoutDay.fromJson(jsonDecode(e))).toList();

    final mJson = prefs.getStringList(_mealsKey) ?? [];
    final meals = mJson.map((e) => MealSlot.fromJson(jsonDecode(e))).toList();

    state = state.copyWith(workouts: workouts, meals: meals, isLoading: false);
  }

  Future<void> toggleWorkout(WorkoutDay workout) async {
    final isFav = isWorkoutFavorite(workout);
    List<WorkoutDay> updated;
    if (isFav) {
      updated = state.workouts.where((w) => w.dayLabel != workout.dayLabel || w.focusZone != workout.focusZone).toList();
    } else {
      updated = [...state.workouts, workout];
    }
    state = state.copyWith(workouts: updated);
    await _saveWorkouts(updated);
  }

  Future<void> toggleMeal(MealSlot meal) async {
    final isFav = isMealFavorite(meal);
    List<MealSlot> updated;
    if (isFav) {
      updated = state.meals.where((m) => m.recipeName != meal.recipeName).toList();
    } else {
      updated = [...state.meals, meal];
    }
    state = state.copyWith(meals: updated);
    await _saveMeals(updated);
  }

  bool isWorkoutFavorite(WorkoutDay workout) {
    return state.workouts.any((w) => w.dayLabel == workout.dayLabel && w.focusZone == workout.focusZone);
  }

  bool isMealFavorite(MealSlot meal) {
    return state.meals.any((m) => m.recipeName == meal.recipeName);
  }

  Future<void> _saveWorkouts(List<WorkoutDay> workouts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = workouts.map((w) => jsonEncode(w.toJson())).toList();
    await prefs.setStringList(_workoutsKey, jsonList);
  }

  Future<void> _saveMeals(List<MealSlot> meals) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = meals.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(_mealsKey, jsonList);
  }
}
