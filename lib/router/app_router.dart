import 'package:go_router/go_router.dart';

import '../models/ocr_result.dart';
import '../models/plan_result.dart';
import '../screens/plan_generation_screen.dart';
import '../screens/create_account_screen.dart';
import '../screens/home_dashboard_screen.dart';
import '../screens/inbody_scan_screen.dart';
import '../screens/landing_screen.dart';
import '../screens/login_screen.dart';
import '../screens/nutrition_screen.dart';
import '../screens/preferences_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/achievements_screen.dart';
import '../screens/ai_coach_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/recipe_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/workout_hub_screen.dart';
import '../screens/exercise_detail_screen.dart';
import '../models/exercise_view_data.dart';
import 'app_routes.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.landing,
    routes: [
      GoRoute(
        path: AppRoutes.landing,
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: AppRoutes.getStarted,
        builder: (context, state) => const CreateAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.logIn,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetupStep2,
        builder: (context, state) => const PreferencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.inBodyScan,
        builder: (context, state) => const InBodyScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.planGeneration,
        builder: (context, state) => PlanGenerationScreen(
          ocrResult: state.extra is OcrExtractResult
              ? state.extra as OcrExtractResult
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.analysisLoading,
        builder: (context, state) => PlanGenerationScreen(
          ocrResult: state.extra is OcrExtractResult
              ? state.extra as OcrExtractResult
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.homeDashboard,
        builder: (context, state) => const HomeDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.workoutHub,
        builder: (context, state) => const WorkoutHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.nutrition,
        builder: (context, state) => const NutritionScreen(),
      ),
      GoRoute(
        path: AppRoutes.recipeDetail,
        builder: (context, state) => RecipeDetailScreen(
          meal: state.extra is MealSlot ? state.extra as MealSlot : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.progress,
        builder: (context, state) => const ProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiCoach,
        builder: (context, state) => const AiCoachScreen(),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.exerciseDetail,
        builder: (context, state) => ExerciseDetailScreen(
          exercise: state.extra is ExerciseViewData ? state.extra as ExerciseViewData : null,
        ),
      ),
    ],
  );
}
