import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../localization/app_strings.dart';
import '../theme/app_colors.dart';

/// Lightweight stub screen so routing works while you flesh out ~15 flows.
/// Replace with real pages and keep URLs in [AppRoutes].
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.landing);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: Text('Back'.tr(context)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.landing),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal),
              ),
              child: Text('Landing'.tr(context)),
            ),
          ],
        ),
      ),
    );
  }
}
