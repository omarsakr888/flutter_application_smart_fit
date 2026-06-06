import 'package:go_router/go_router.dart';

import '../models/ocr_result.dart';
import '../screens/analysis_loading_screen.dart';
import '../screens/create_account_screen.dart';
import '../screens/home_dashboard_screen.dart';
import '../screens/inbody_scan_screen.dart';
import '../screens/landing_screen.dart';
import '../screens/login_screen.dart';
import '../screens/nutrition_screen.dart';
import '../screens/preferences_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/recipe_detail_screen.dart';
import '../screens/workout_hub_screen.dart';
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
        path: AppRoutes.analysisLoading,
        builder: (context, state) => AnalysisLoadingScreen(
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
        builder: (context, state) => const RecipeDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.progress,
        builder: (context, state) => const ProgressScreen(),
      ),
    ],
  );
}
