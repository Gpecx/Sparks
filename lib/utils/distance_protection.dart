import 'dart:math' as math;

// Ajuste de zonas da proteção de distância (21), por módulos de impedância.
//   Zona 1 = z1% · Z_linha                    (alcance subdimensionado, ~80–85%)
//   Zona 2 = Z_linha + fator2 · Z_adjacente    (cobre 100% da linha + parte da seguinte)
//   Zona 3 = Z_linha + fator3 · Z_adjacente    (retaguarda remota)
// Impedância secundária (vista pelo relé): Z_sec = Z_prim · (RTC / RTP).

class DistanceZones {
  final double z1;
  final double z2;
  final double z3;
  final double? z1Secondary;
  final double? z2Secondary;
  final double? z3Secondary;

  const DistanceZones({
    required this.z1,
    required this.z2,
    required this.z3,
    this.z1Secondary,
    this.z2Secondary,
    this.z3Secondary,
  });
}

DistanceZones distanceZones({
  required double lineImpedance,
  required double adjacentImpedance,
  double zone1Percent = 85,
  double zone2AdjacentFactor = 0.5,
  double zone3AdjacentFactor = 1.0,
  double? rtc,
  double? rtp,
}) {
  final z1 = zone1Percent / 100.0 * lineImpedance;
  final z2 = lineImpedance + zone2AdjacentFactor * adjacentImpedance;
  final z3 = lineImpedance + zone3AdjacentFactor * adjacentImpedance;

  final hasSecondary = rtc != null && rtp != null && rtp > 0;
  final ratio = hasSecondary ? rtc / rtp : null;

  return DistanceZones(
    z1: z1,
    z2: z2,
    z3: z3,
    z1Secondary: ratio == null ? null : z1 * ratio,
    z2Secondary: ratio == null ? null : z2 * ratio,
    z3Secondary: ratio == null ? null : z3 * ratio,
  );
}

// ── Característica mho no plano R-X ───────────────────────────────
// Modelo de campo (triagem): cada zona é um círculo mho que passa pela origem,
// com diâmetro = alcance da zona na direção do ângulo da linha (RCA). Uma
// impedância de falta Z_f = |Z_f|∠φ está DENTRO da zona quando a projeção de
// Z_f na direção da linha não passa do alcance:
//   |Z_f| ≤ alcance · cos(φ − θ_linha)   (e a projeção é positiva = à frente).

class ImpedanceVector {
  final double r; // resistência (Ω)
  final double x; // reatância (Ω)
  const ImpedanceVector(this.r, this.x);

  double get magnitude => math.sqrt(r * r + x * x);
  double get angleDeg => math.atan2(x, r) * 180.0 / math.pi;
}

// Constrói a impedância de falta a partir de módulo e ângulo (graus).
ImpedanceVector faultImpedance({
  required double magnitude,
  required double angleDeg,
}) {
  final rad = angleDeg * math.pi / 180.0;
  return ImpedanceVector(magnitude * math.cos(rad), magnitude * math.sin(rad));
}

// Verdadeiro se a falta cai dentro de um mho de dado alcance e ângulo de linha.
bool insideMho({
  required ImpedanceVector fault,
  required double reach,
  required double lineAngleDeg,
}) {
  final phi = fault.angleDeg;
  final proj = reach * math.cos((phi - lineAngleDeg) * math.pi / 180.0);
  if (proj <= 0) return false; // atrás do relé (reverso)
  return fault.magnitude <= proj + 1e-9;
}

// Qual a zona MAIS RÁPIDA (menor) que enxerga a falta: 1, 2, 3 ou 0 (nenhuma).
int fastestZoneSeeing({
  required ImpedanceVector fault,
  required double z1,
  required double z2,
  required double z3,
  required double lineAngleDeg,
}) {
  if (insideMho(fault: fault, reach: z1, lineAngleDeg: lineAngleDeg)) return 1;
  if (insideMho(fault: fault, reach: z2, lineAngleDeg: lineAngleDeg)) return 2;
  if (insideMho(fault: fault, reach: z3, lineAngleDeg: lineAngleDeg)) return 3;
  return 0;
}
