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

  CovenantModel copyWith({
    String? id,
    String? title,
    String? objective,
    String? reward,
    int? currentProgress,
    int? maxProgress,
    bool? isCompleted,
    String? trackingType,
  }) {
    return CovenantModel(
      id: id ?? this.id,
      title: title ?? this.title,
      objective: objective ?? this.objective,
      reward: reward ?? this.reward,
      currentProgress: currentProgress ?? this.currentProgress,
      maxProgress: maxProgress ?? this.maxProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      trackingType: trackingType ?? this.trackingType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'objective': objective,
      'reward': reward,
      'currentProgress': currentProgress,
      'maxProgress': maxProgress,
      'isCompleted': isCompleted,
      'trackingType': trackingType,
    };
  }

  factory CovenantModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return CovenantModel(
      id: docId ?? map['id'] ?? '',
      title: map['title'] ?? '',
      objective: map['objective'] ?? '',
      reward: map['reward'] ?? '',
      currentProgress: map['currentProgress']?.toInt() ?? 0,
      maxProgress: map['maxProgress']?.toInt() ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      trackingType: map['trackingType'] ?? '',
    );
  }
}
