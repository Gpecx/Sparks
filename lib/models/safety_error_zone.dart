/// Modelo para zonas de erro na Simulação de Erros (Point and Click).
/// Coordenadas são proporcionais (0.0 a 1.0), permitindo
/// escalar para qualquer tamanho de tela ou nível de zoom.
class SafetyErrorZone {
  final String id;
  final double x; // Posição proporcional X (0.0 - 1.0)
  final double y; // Posição proporcional Y (0.0 - 1.0)
  final double width; // Largura proporcional (0.0 - 1.0)
  final double height; // Altura proporcional (0.0 - 1.0)
  final String description; // Descrição do erro (ex: "Fio exposto")
  final String category; // Categoria (ex: "EPI", "Instalação")
  bool isDiscovered;

  SafetyErrorZone({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.description,
    this.category = '',
    this.isDiscovered = false,
  });
}

/// Cenário completo para o laboratório.
class ErrorScenario {
  final String id;
  final String title;
  final String description;
  final int timeLimitSeconds;
  final List<SafetyErrorZone> errorZones;

  const ErrorScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.timeLimitSeconds,
    required this.errorZones,
  });
}
