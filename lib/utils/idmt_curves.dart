import 'dart:math' as math;

// Curvas IDMT (função 51) — equação generalizada:
//   t = (A·Td + K1) / (M^P − Q) + B·Td + K2,  com M = I_teste / I_pickup
// Coeficientes extraídos do app SRPD. Três curvas foram corrigidas para os
// valores normativos IEC/IEEE (o fonte original tinha erros de digitação):
//   IEEE MI:    A = 0,0515 (fonte: 0,515)
//   BS142 STI:  A = 0,05   (fonte: 50)
//   Tab II VI:  P = 2      (fonte: 0,02)

class IdmtCurve {
  final String id;
  final String name;
  final String family;
  final double a;
  final double p;
  final double q;
  final double b;
  final double k1;
  final double k2;

  const IdmtCurve({
    required this.id,
    required this.name,
    required this.family,
    required this.a,
    required this.p,
    this.q = 1,
    this.b = 0,
    this.k1 = 0,
    this.k2 = 0,
  });

  double timeForMultiple(double m, double td) {
    return (a * td + k1) / (math.pow(m, p) - q) + b * td + k2;
  }

  double timeForCurrent({
    required double iTest,
    required double iPickup,
    required double td,
  }) {
    return timeForMultiple(iTest / iPickup, td);
  }
}

const List<IdmtCurve> idmtCurves = [
  // ── IEC Padrão ───────────────────────────────────────────────
  IdmtCurve(id: 'iec_inversa', name: 'IEC - Normal Inversa', family: 'IEC Padrão', a: 0.14, p: 0.02),
  IdmtCurve(id: 'iec_muito_inversa', name: 'IEC - Muito Inversa', family: 'IEC Padrão', a: 13.5, p: 1),
  IdmtCurve(id: 'iec_extre_inversa', name: 'IEC - Extremamente Inversa', family: 'IEC Padrão', a: 80, p: 2),

  // ── IEEE ─────────────────────────────────────────────────────
  IdmtCurve(id: 'ieee_mi', name: 'IEEE - Moderadamente Inversa', family: 'IEEE', a: 0.0515, p: 0.02, b: 0.114),
  IdmtCurve(id: 'ieee_vi', name: 'IEEE - Muito Inversa', family: 'IEEE', a: 19.61, p: 2, b: 0.491),
  IdmtCurve(id: 'ieee_ei', name: 'IEEE - Extremamente Inversa', family: 'IEEE', a: 28.2, p: 2, b: 0.1217),

  // ── ANSI ─────────────────────────────────────────────────────
  IdmtCurve(id: 'ansi_ni', name: 'ANSI - NI', family: 'ANSI', a: 8.934, p: 2.094, b: 0.1797),
  IdmtCurve(id: 'ansi_vi', name: 'ANSI - VI', family: 'ANSI', a: 3.922, p: 2, b: 0.0982),
  IdmtCurve(id: 'ansi_ei', name: 'ANSI - EI', family: 'ANSI', a: 5.64, p: 2, b: 0.02434),
  IdmtCurve(id: 'ansi_li', name: 'ANSI - LI', family: 'ANSI', a: 5.614, p: 1, b: 2.186),

  // ── IEC/BS142 ────────────────────────────────────────────────
  IdmtCurve(id: 'bs142_ni', name: 'IEC /BS142 NI', family: 'IEC/BS142', a: 0.14, p: 0.02),
  IdmtCurve(id: 'bs142_vi', name: 'IEC /BS142 VI', family: 'IEC/BS142', a: 13.5, p: 1),
  IdmtCurve(id: 'bs142_ei', name: 'IEC /BS142 EI', family: 'IEC/BS142', a: 80, p: 2),
  IdmtCurve(id: 'bs142_lti', name: 'IEC /BS142 LTI', family: 'IEC/BS142', a: 120, p: 1),
  IdmtCurve(id: 'bs142_sti', name: 'IEC /BS142 STI', family: 'IEC/BS142', a: 0.05, p: 0.04),

  // ── IEEE Tab I (ABB) ─────────────────────────────────────────
  IdmtCurve(id: 'tab1_mi', name: 'IEEE Tab I MI - ABB', family: 'IEEE Tab I (ABB)', a: 0.047, p: 0.02, b: 0.183),
  IdmtCurve(id: 'tab1_vi', name: 'IEEE Tab I VI - ABB', family: 'IEEE Tab I (ABB)', a: 18.92, p: 2, b: 0.492),
  IdmtCurve(id: 'tab1_ei', name: 'IEEE Tab I EI - ABB', family: 'IEEE Tab I (ABB)', a: 28.08, p: 2, b: 0.13),

  // ── IEEE Tab II (GE) ─────────────────────────────────────────
  IdmtCurve(id: 'tab2_mi', name: 'IEEE Tab II MI - GE', family: 'IEEE Tab II (GE)', a: 0.056, p: 0.02, b: 0.045),
  IdmtCurve(id: 'tab2_vi', name: 'IEEE Tab II VI - GE', family: 'IEEE Tab II (GE)', a: 0.02029, p: 2, b: 0.489),
  IdmtCurve(id: 'tab2_ei', name: 'IEEE Tab II EI - GE', family: 'IEEE Tab II (GE)', a: 20.33, p: 2, b: 0.081),

  // ── ABB ──────────────────────────────────────────────────────
  IdmtCurve(id: 'abb_ei', name: 'ABB EI', family: 'ABB', a: 6.407, p: 2, b: 0.025),
  IdmtCurve(id: 'abb_ri', name: 'ABB RI', family: 'ABB', a: -4.237, p: -1, q: 1.436),
  IdmtCurve(id: 'abb_vi', name: 'ABB VI', family: 'ABB', a: 2.855, p: 2, b: 0.0712),
  IdmtCurve(id: 'abb_mi', name: 'ABB MI', family: 'ABB', a: 0.0086, p: 0.02, b: 0.0185),
  IdmtCurve(id: 'abb_sti', name: 'ABB STI', family: 'ABB', a: 0.0017, p: 0.02, b: 0.0037),
  IdmtCurve(id: 'abb_stei', name: 'ABB STEI', family: 'ABB', a: 1.281, p: 2, b: 0.005),
  IdmtCurve(id: 'abb_ltei', name: 'ABB LTEI', family: 'ABB', a: 64.07, p: 2, b: 0.25),
  IdmtCurve(id: 'abb_ltvi', name: 'ABB LTVI', family: 'ABB', a: 28.55, p: 2, b: 0.712),
  IdmtCurve(id: 'abb_lti', name: 'ABB LTI', family: 'ABB', a: 0.086, p: 0.02, b: 0.185),
  IdmtCurve(id: 'abb_rcl', name: 'ABB RCL', family: 'ABB', a: 4.211, p: 1.8, q: 0.35, b: 0.013),

  // ── ABB 1997 CO ──────────────────────────────────────────────
  IdmtCurve(id: 'abbco2', name: 'ABB 1997 CO-2', family: 'ABB 1997 CO', a: 0.1052, p: 0.8, b: 0.0262),
  IdmtCurve(id: 'abbco5', name: 'ABB 1997 CO-5', family: 'ABB 1997 CO', a: 4.842, p: 1.1, b: 1.967),
  IdmtCurve(id: 'abbco6', name: 'ABB 1997 CO-6', family: 'ABB 1997 CO', a: 0.1052, p: 0.8, b: 0.0262),
  IdmtCurve(id: 'abbco7', name: 'ABB 1997 CO-7', family: 'ABB 1997 CO', a: 0.0094, p: 0.02, b: 0.0366),
  IdmtCurve(id: 'abbco8', name: 'ABB 1997 CO-8', family: 'ABB 1997 CO', a: 5.848, p: 2, b: 0.1654),
  IdmtCurve(id: 'abbco9', name: 'ABB 1997 CO-9', family: 'ABB 1997 CO', a: 4.12, p: 2, b: 0.0958),
  IdmtCurve(id: 'abbco11', name: 'ABB 1997 CO-11', family: 'ABB 1997 CO', a: 5.57, p: 2, b: 0.028),

  // ── GE DFP 100 ───────────────────────────────────────────────
  IdmtCurve(id: 'ge_dfp_i', name: 'GE DFP 100 I', family: 'GE DFP 100', a: 0.0103, p: 0.02, b: 0.0228),
  IdmtCurve(id: 'ge_dfp_vi', name: 'GE DFP 100 VI', family: 'GE DFP 100', a: 3.922, p: 2, b: 0.0982),
  IdmtCurve(id: 'ge_dfp_ei', name: 'GE DFP 100 EI', family: 'GE DFP 100', a: 5.64, p: 2, b: 0.0243),

  // ── Siemens ──────────────────────────────────────────────────
  IdmtCurve(id: 'sie_i', name: 'Siemens I', family: 'Siemens', a: 8.934, p: 2.094, b: 0.1797, k2: 0.028),
  IdmtCurve(id: 'sie_si', name: 'Siemens SI', family: 'Siemens', a: 0.2663, p: 1.297, b: 0.0339),
  IdmtCurve(id: 'sie_li', name: 'Siemens LI', family: 'Siemens', a: 5.614, p: 1, b: 2.186),
  IdmtCurve(id: 'sie_mi', name: 'Siemens MI', family: 'Siemens', a: 0.0103, p: 0.02, b: 0.0228),
  IdmtCurve(id: 'sie_vi', name: 'Siemens VI', family: 'Siemens', a: 3.922, p: 2, b: 0.0982),
  IdmtCurve(id: 'sie_ei', name: 'Siemens EI', family: 'Siemens', a: 5.64, p: 2, b: 0.0243),
  IdmtCurve(id: 'sie_di', name: 'Siemens DI', family: 'Siemens', a: 0.4797, p: 1.563, b: 0.2136),
  IdmtCurve(id: 'sie_i2t', name: 'Siemens I2T', family: 'Siemens', a: 50.7, p: 2, q: 0, k1: 10.14),
  IdmtCurve(id: 'sie_lti', name: 'Siemens LTI', family: 'Siemens', a: 120, p: 1),
  IdmtCurve(id: 'sie_ol', name: 'Siemens O/L', family: 'Siemens', a: 35, p: 2),

  // ── SEL ──────────────────────────────────────────────────────
  IdmtCurve(id: 'sel_u1', name: 'SEL MI - curva U1', family: 'SEL', a: 0.0104, p: 0.02, b: 0.0226),
  IdmtCurve(id: 'sel_u2', name: 'SEL NI - curva U2', family: 'SEL', a: 5.95, p: 2, b: 0.18),
  IdmtCurve(id: 'sel_u3', name: 'SEL VI - curva U3', family: 'SEL', a: 3.88, p: 2, b: 0.0963),
  IdmtCurve(id: 'sel_u4', name: 'SEL EI - curva U4', family: 'SEL', a: 5.67, p: 2, b: 0.0352),
  IdmtCurve(id: 'sel_u5', name: 'SEL STI - curva U5', family: 'SEL', a: 0.0034, p: 0.02, b: 0.0026),
  IdmtCurve(id: 'sel_251', name: 'SEL 251 MI - curva 1', family: 'SEL', a: 0.668, p: 1, b: 0.157),
];

List<String> get idmtFamilies {
  final seen = <String>[];
  for (final c in idmtCurves) {
    if (!seen.contains(c.family)) seen.add(c.family);
  }
  return seen;
}

// Tempo em segundos → "hh:mm:ss.cc" (centésimos), formato da ferramenta original.
String formatTripTime(double seconds) {
  if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '—';
  final totalCentis = (seconds * 100).round();
  final h = totalCentis ~/ 360000;
  final m = (totalCentis % 360000) ~/ 6000;
  final s = (totalCentis % 6000) ~/ 100;
  final cc = totalCentis % 100;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}.${two(cc)}';
}
