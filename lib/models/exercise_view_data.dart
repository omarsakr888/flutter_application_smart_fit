class ExerciseViewData {
  final String name;
  final String setsRepsLabel;
  final String targetMuscle;
  final String? notes;
  final String? dayLabel;
  final String? gifPath;

  const ExerciseViewData({
    required this.name,
    required this.setsRepsLabel,
    required this.targetMuscle,
    this.notes,
    this.dayLabel,
    this.gifPath,
  });
}
