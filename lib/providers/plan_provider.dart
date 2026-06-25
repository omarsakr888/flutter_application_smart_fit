import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ocr_result.dart';
import '../models/plan_result.dart';
import '../services/scan_service.dart';

class PlanState {
  final PlanResult? plan;
  final String? error;
  final bool isLoading;

  const PlanState({
    this.plan,
    this.error,
    this.isLoading = false,
  });

  PlanState copyWith({
    PlanResult? plan,
    String? error,
    bool? isLoading,
  }) {
    return PlanState(
      plan: plan ?? this.plan,
      error: error, // Can be null
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PlanNotifier extends Notifier<PlanState> {
  @override
  PlanState build() {
    return const PlanState();
  }

  Future<void> generatePlan(OcrExtractResult? ocr) async {
    if (ocr == null) {
      state = state.copyWith(error: 'No scan data available.', isLoading: false);
      return;
    }

    state = const PlanState(isLoading: true);

    try {
      final plan = await ScanService.instance.generatePlan(ocr);
      state = state.copyWith(plan: plan, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void reset() {
    state = const PlanState();
  }
}

final planProvider = NotifierProvider<PlanNotifier, PlanState>(() {
  return PlanNotifier();
});
