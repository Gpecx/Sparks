import 'dart:math' as math;

// Diferencial percentual com restrição (função 87) — característica de
// operação Idiff × Irest com dupla inclinação (slope dual).
//
// DIFERENTE do "Balanço Diferencial (87T)" existente, que calcula o balanço de
// TAP (razão das correntes secundárias entre enrolamentos para ajustar o TAP).
// Aqui o foco é a CARACTERÍSTICA DE RESTRIÇÃO: dado o par de correntes dos
// enrolamentos numa condição (carga, falta passante ou interna), decide se o
// relé OPERA ou RESTRINGE e mostra o ponto no plano Idiff × Irest.
//
// Convenções (correntes já referidas à mesma base, em pu de I_nom ou em A):
//   Idiff  = |I1 + I2|                 (soma fasorial; ~0 em passante ideal)
//   Irest  depende da convenção do fabricante:
//     • média:   (|I1| + |I2|) / 2     (SEL, GE típico)
//     • máximo:  max(|I1|, |I2|)
//     • soma:    |I1| + |I2|
//
// Característica de dupla inclinação (dual slope):
//   pickup (Ipu) até Irest = joelho1 (k1)         → limiar = pickup
//   entre k1 e k2: limiar = pickup + slope1·(Irest − k1)
//   acima de k2:   limiar = pickup + slope1·(k2 − k1) + slope2·(Irest − k2)
// Opera quando Idiff > limiar.

enum RestraintConvention { average, maximum, sum }

class DifferentialOperatingPoint {
  final double idiff; // corrente diferencial
  final double irest; // corrente de restrição
  final double threshold; // limiar da característica em irest
  final bool operates; // Idiff > limiar
  final double margin; // idiff - threshold (positivo = opera)

  const DifferentialOperatingPoint({
    required this.idiff,
    required this.irest,
    required this.threshold,
    required this.operates,
    required this.margin,
  });
}

// Magnitude de uma corrente dada por módulo e ângulo (graus).
double _re(double mag, double angDeg) => mag * math.cos(angDeg * math.pi / 180);
double _im(double mag, double angDeg) => mag * math.sin(angDeg * math.pi / 180);

// Corrente diferencial (soma fasorial) de dois enrolamentos.
double diffCurrent({
  required double i1, required double ang1,
  required double i2, required double ang2,
}) {
  final re = _re(i1, ang1) + _re(i2, ang2);
  final im = _im(i1, ang1) + _im(i2, ang2);
  return math.sqrt(re * re + im * im);
}

// Corrente de restrição conforme a convenção.
double restraintCurrent({
  required double i1,
  required double i2,
  required RestraintConvention convention,
}) {
  final a = i1.abs();
  final b = i2.abs();
  switch (convention) {
    case RestraintConvention.average:
      return (a + b) / 2.0;
    case RestraintConvention.maximum:
      return math.max(a, b);
    case RestraintConvention.sum:
      return a + b;
  }
}

// Limiar da característica de dupla inclinação para uma dada Irest.
double dualSlopeThreshold({
  required double irest,
  required double pickup,
  required double slope1,
  required double slope2,
  required double knee1,
  required double knee2,
}) {
  if (irest <= knee1) return pickup;
  if (irest <= knee2) {
    return pickup + slope1 * (irest - knee1);
  }
  return pickup + slope1 * (knee2 - knee1) + slope2 * (irest - knee2);
}

// Avalia o ponto de operação completo.
DifferentialOperatingPoint evaluateDifferential({
  required double i1, required double ang1,
  required double i2, required double ang2,
  required RestraintConvention convention,
  required double pickup,
  required double slope1,
  required double slope2,
  required double knee1,
  required double knee2,
}) {
  final idiff = diffCurrent(i1: i1, ang1: ang1, i2: i2, ang2: ang2);
  final irest = restraintCurrent(i1: i1, i2: i2, convention: convention);
  final threshold = dualSlopeThreshold(
    irest: irest,
    pickup: pickup,
    slope1: slope1,
    slope2: slope2,
    knee1: knee1,
    knee2: knee2,
  );
  final margin = idiff - threshold;
  return DifferentialOperatingPoint(
    idiff: idiff,
    irest: irest,
    threshold: threshold,
    operates: idiff > threshold,
    margin: margin,
  );
}
