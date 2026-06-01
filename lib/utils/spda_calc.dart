import 'dart:math' as math;

// Cálculos gerais de SPDA — NBR 5419-3 (triagem de campo).
//
// Cobre: raio da esfera rolante e nº de descidas; distância de segurança (s);
// corrente de impulso e seção mínima por nível; ângulo de proteção (Franklin).
//
// NÃO substitui o projeto de SPDA. Valores tabelados por nível de proteção
// (I a IV) conforme a norma.

// ── Parâmetros por nível de proteção (NBR 5419-3) ────────────────
class SpdaLevel {
  final String name; // 'I'..'IV'
  final double rollingSphereRadius; // m
  final double downConductorSpacing; // m (espaçamento típico entre descidas)
  final double impulseCurrentKa; // corrente de impulso (kA)

  const SpdaLevel(
    this.name,
    this.rollingSphereRadius,
    this.downConductorSpacing,
    this.impulseCurrentKa,
  );
}

const spdaLevels = <SpdaLevel>[
  SpdaLevel('I', 20, 10, 200),
  SpdaLevel('II', 30, 10, 150),
  SpdaLevel('III', 45, 15, 100),
  SpdaLevel('IV', 60, 20, 100),
];

SpdaLevel spdaLevelByName(String name) =>
    spdaLevels.firstWhere((l) => l.name == name, orElse: () => spdaLevels.first);

// ── Número de condutores de descida ──────────────────────────────
// N = perímetro / espaçamento do nível, com mínimo de 2 descidas.
int downConductors({
  required double perimeter,
  required SpdaLevel level,
}) {
  if (perimeter <= 0) return 2;
  final n = (perimeter / level.downConductorSpacing).ceil();
  return n < 2 ? 2 : n;
}

// ── Distância de segurança contra centelhamento (s) ──────────────
//   s = ki · (kc / km) · L
//     ki: depende do nível (I=0,08; II=0,06; III/IV=0,04)
//     kc: coef. de divisão da corrente (depende do nº de descidas/arranjo)
//     km: material do isolamento (ar=1; sólido=0,5)
//     L : comprimento ao longo do condutor até a equipotencialização (m)
double kiForLevel(String level) {
  switch (level) {
    case 'I':
      return 0.08;
    case 'II':
      return 0.06;
    default:
      return 0.04; // III e IV
  }
}

double safetyDistance({
  required String level,
  required double kc,
  required double km,
  required double length,
}) {
  if (km <= 0) return double.nan;
  return kiForLevel(level) * (kc / km) * length;
}

// ── Ângulo de proteção (método Franklin) ─────────────────────────
// A norma dá α em função da altura h e do nível (curvas do Anexo A da
// 5419-3). Aproximação por ajuste das curvas: α decresce com a altura.
// Modelo de triagem: α ≈ α0(nível) − k·h, limitado a ≥ 0.
double protectionAngleDeg({
  required String level,
  required double height,
}) {
  // α0 e inclinação aproximados por nível (graus; h em m).
  double a0, slope;
  switch (level) {
    case 'I':
      a0 = 71;
      slope = 1.5;
      break;
    case 'II':
      a0 = 72;
      slope = 1.25;
      break;
    case 'III':
      a0 = 76;
      slope = 1.0;
      break;
    default: // IV
      a0 = 79;
      slope = 0.9;
  }
  final a = a0 - slope * height;
  return a < 0 ? 0 : a;
}

// Raio de proteção no solo pelo método do ângulo: r = h · tan(α).
double protectionRadiusAtGround({
  required double height,
  required double angleDeg,
}) {
  return height * math.tan(angleDeg * math.pi / 180.0);
}

// ── Seção mínima de condutores (NBR 5419-3, Tabela) ──────────────
// Captação/descida em cobre: 16 mm² (mínimo geral); alumínio 25 mm²;
// aço galvanizado 50 mm². Aterramento em cobre: 50 mm².
class ConductorSection {
  final double airTerminationCopper; // mm²
  final double downConductorCopper; // mm²
  final double earthCopper; // mm²
  const ConductorSection({
    required this.airTerminationCopper,
    required this.downConductorCopper,
    required this.earthCopper,
  });
}

const conductorSectionCopper = ConductorSection(
  airTerminationCopper: 35, // captação (cobre) — valor usual de projeto
  downConductorCopper: 16, // descida (cobre) — mínimo
  earthCopper: 50, // aterramento (cobre)
);

class SpdaGeneralResult {
  final double rollingSphereRadius;
  final int downConductorCount;
  final double protectionAngle;
  final double protectionRadius;
  final double impulseCurrentKa;

  const SpdaGeneralResult({
    required this.rollingSphereRadius,
    required this.downConductorCount,
    required this.protectionAngle,
    required this.protectionRadius,
    required this.impulseCurrentKa,
  });
}

SpdaGeneralResult spdaGeneral({
  required String level,
  required double perimeter,
  required double height,
}) {
  final lvl = spdaLevelByName(level);
  final angle = protectionAngleDeg(level: level, height: height);
  return SpdaGeneralResult(
    rollingSphereRadius: lvl.rollingSphereRadius,
    downConductorCount: downConductors(perimeter: perimeter, level: lvl),
    protectionAngle: angle,
    protectionRadius: protectionRadiusAtGround(height: height, angleDeg: angle),
    impulseCurrentKa: lvl.impulseCurrentKa,
  );
}
