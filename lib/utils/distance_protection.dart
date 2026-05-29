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
