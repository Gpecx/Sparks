class CovenantModel {
  final String id;
  final String title;
  final String objective;
  final String reward;
  final int currentProgress;
  final int maxProgress;
  final bool isCompleted;
  final String trackingType; // 'days', 'battles', '%'
  final bool isSelected;    // true = ativo para a semana atual
  final String weekKey;     // ex: '2025-W17', vazio = nunca selecionado

  CovenantModel({
    required this.id,
    required this.title,
    required this.objective,
    required this.reward,
    required this.currentProgress,
    required this.maxProgress,
    required this.isCompleted,
    required this.trackingType,
    this.isSelected = false,
    this.weekKey = '',
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
    bool? isSelected,
    String? weekKey,
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
      isSelected: isSelected ?? this.isSelected,
      weekKey: weekKey ?? this.weekKey,
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
      'isSelected': isSelected,
      'weekKey': weekKey,
    };
  }

  /// Retorna a recompensa em XP com base no ID do pacto.
  /// Valores fixos para evitar inconsistências com dados legados do Firestore.
  static String _rewardFromId(String id) {
    switch (id) {
      case 'cov_disciplina':
        return '+250 XP';
      case 'cov_precisao':
        return '+200 XP';
      case 'cov_conhecimento':
        return '+150 XP';
      case 'cov_duelista':
        return '+300 XP';
      case 'cov_perfeccionista':
        return '+250 XP';
      case 'cov_dedicacao':
        return '+200 XP';
      default:
        // fallback: extrai apenas o número do campo salvo, se existir
        return id.isNotEmpty ? '+XP' : '';
    }
  }

  factory CovenantModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final id = docId ?? map['id'] ?? '';
    return CovenantModel(
      id: id,
      title: map['title'] ?? '',
      objective: map['objective'] ?? '',
      reward: _rewardFromId(id), // sempre derivado do ID, ignora valor do Firestore
      currentProgress: map['currentProgress']?.toInt() ?? 0,
      maxProgress: map['maxProgress']?.toInt() ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      trackingType: map['trackingType'] ?? '',
      isSelected: map['isSelected'] ?? false,
      weekKey: map['weekKey'] ?? '',
    );
  }
}
