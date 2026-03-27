class CovenantModel {
  final String id;
  final String title;
  final String objective;
  final String reward;
  final int currentProgress;
  final int maxProgress;
  final bool isCompleted;
  final String trackingType; // e.g. 'days', 'battles', 'completion'

  CovenantModel({
    required this.id,
    required this.title,
    required this.objective,
    required this.reward,
    required this.currentProgress,
    required this.maxProgress,
    required this.isCompleted,
    required this.trackingType,
  });
}
