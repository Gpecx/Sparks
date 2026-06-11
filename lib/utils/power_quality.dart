import 'dart:math' as math;

// Análise rápida de qualidade de energia: carregamento de transformador e
// desequilíbrio de tensão (base PRODIST Módulo 8).

// ── Carregamento de transformador ───────────────────────────────
// Carregamento% = S_medida / S_nominal · 100
//   S trifásica (kVA) = √3 · V_LL(kV) · I(A)
class TransformerLoading {
  final double apparentKva; // S medida
  final double loadingPercent;

  const TransformerLoading({
    required this.apparentKva,
    required this.loadingPercent,
  });
}

TransformerLoading transformerLoading({
  required double vLLkv,
  required double currentA,
  required double ratedKva,
}) {
  final s = math.sqrt(3) * vLLkv * currentA; // kVA
  final pct = ratedKva > 0 ? s / ratedKva * 100.0 : double.nan;
  return TransformerLoading(apparentKva: s, loadingPercent: pct);
}

// ── Desequilíbrio de tensão ──────────────────────────────────────

// PRODIST Módulo 8: FD% = (V_sequência_negativa / V_sequência_positiva) · 100
// Recebe os módulos e ângulos (graus) das tensões de fase.
double voltageUnbalanceProdist({
  required double va, required double angA,
  required double vb, required double angB,
  required double vc, required double angC,
}) {
  // operador a = 1∠120°
  const deg = math.pi / 180.0;
  double cosd(double d) => math.cos(d * deg);
  double sind(double d) => math.sin(d * deg);

  // fasores em retangular
  final ax = va * cosd(angA), ay = va * sind(angA);
  final bx = vb * cosd(angB), by = vb * sind(angB);
  final cx = vc * cosd(angC), cy = vc * sind(angC);

  // a = 1∠120, a² = 1∠240
  final aRe = cosd(120), aIm = sind(120);
  final a2Re = cosd(240), a2Im = sind(240);

  // multiplicação complexa helper: (x1,y1)*(x2,y2)
  List<double> mul(double x1, double y1, double x2, double y2) =>
      [x1 * x2 - y1 * y2, x1 * y2 + y1 * x2];

  // V1 = (Va + a·Vb + a²·Vc)/3
  final ab = mul(aRe, aIm, bx, by);
  final a2c = mul(a2Re, a2Im, cx, cy);
  final v1Re = (ax + ab[0] + a2c[0]) / 3;
  final v1Im = (ay + ab[1] + a2c[1]) / 3;

  // V2 = (Va + a²·Vb + a·Vc)/3
  final a2b = mul(a2Re, a2Im, bx, by);
  final ac = mul(aRe, aIm, cx, cy);
  final v2Re = (ax + a2b[0] + ac[0]) / 3;
  final v2Im = (ay + a2b[1] + ac[1]) / 3;

  final v1 = math.sqrt(v1Re * v1Re + v1Im * v1Im);
  final v2 = math.sqrt(v2Re * v2Re + v2Im * v2Im);
  return v1 > 0 ? v2 / v1 * 100.0 : double.nan;
}

// Aproximada (CIGRÉ/NEMA), só a partir dos módulos das 3 tensões de linha.
//   FD% ≈ 82 · √( (1 − √(3 − 6β)) / (1 + √(3 − 6β)) ),  β = (V1⁴+V2⁴+V3⁴)/(V1²+V2²+V3²)²
double voltageUnbalanceApprox({
  required double v1,
  required double v2,
  required double v3,
}) {
  final s2 = v1 * v1 + v2 * v2 + v3 * v3;
  final s4 = math.pow(v1, 4) + math.pow(v2, 4) + math.pow(v3, 4);
  if (s2 == 0) return double.nan;
  final beta = s4 / (s2 * s2);
  final inner = 3 - 6 * beta;
  if (inner < 0) return double.nan;
  final root = math.sqrt(inner);
  final ratio = (1 - root) / (1 + root);
  if (ratio < 0) return double.nan;
  return 82.0 * math.sqrt(ratio);
}

// Desequilíbrio simples pelo desvio máximo da média (NEMA LV unbalance).
//   % = (maior desvio absoluto da média / média) · 100
double maxDeviationUnbalance({
  required double v1,
  required double v2,
  required double v3,
}) {
  final mean = (v1 + v2 + v3) / 3.0;
  if (mean == 0) return double.nan;
  final dev = [
    (v1 - mean).abs(),
    (v2 - mean).abs(),
    (v3 - mean).abs(),
  ].reduce(math.max);
  return dev / mean * 100.0;
}
