import 'dart:math' as math;

// Base de impedância (Ω): Z_base = V_base² / S_base
// V_base em kV, S_base em MVA → resultado em Ω
double impedanceBase({required double sBaseMva, required double vBaseKv}) {
  return (vBaseKv * vBaseKv) / sBaseMva;
}

// Base de corrente (A) trifásico: I_base = S_base / (√3 · V_base)
// S_base em MVA, V_base em kV → resultado em A
double currentBase({required double sBaseMva, required double vBaseKv}) {
  return (sBaseMva * 1e6) / (math.sqrt(3) * vBaseKv * 1e3);
}

double zPuFromReal({
  required double zRealOhm,
  required double sBaseMva,
  required double vBaseKv,
}) {
  return zRealOhm / impedanceBase(sBaseMva: sBaseMva, vBaseKv: vBaseKv);
}

double zRealFromPu({
  required double zPu,
  required double sBaseMva,
  required double vBaseKv,
}) {
  return zPu * impedanceBase(sBaseMva: sBaseMva, vBaseKv: vBaseKv);
}

// Mudança de base de impedância em PU
// Z_pu_novo = Z_pu_velho × (S_novo/S_velho) × (V_velho/V_novo)²
double changeImpedanceBase({
  required double zPuOld,
  required double sBaseOldMva,
  required double vBaseOldKv,
  required double sBaseNewMva,
  required double vBaseNewKv,
}) {
  return zPuOld *
      (sBaseNewMva / sBaseOldMva) *
      math.pow(vBaseOldKv / vBaseNewKv, 2).toDouble();
}
