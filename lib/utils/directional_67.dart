import 'dart:math' as math;

// Elemento direcional de sobrecorrente — funções 67 (fase) e 67N (neutro/terra).
//
// Triagem de ajuste/diagnóstico de campo. NÃO substitui o estudo de proteção
// nem o manual do relé (cada fabricante tem convenções de sinal e de ângulo
// próprias). O objetivo é checar: dada a corrente de operação e a grandeza de
// polarização, o elemento enxerga a falta como DIRETA (opera) ou REVERSA
// (bloqueia/restringe), e onde o fasor cai em relação ao setor de operação.
//
// Princípio:
//   • Define-se a linha de máximo torque (MTA/RCA = relay characteristic angle)
//     como o ângulo, em relação à grandeza de polarização, no qual o conjugado
//     direcional é máximo.
//   • A corrente de operação é referida à polarização: θ = ∠I_op − ∠V_pol.
//   • O elemento opera quando θ cai dentro de ±90° em torno do MTA, ou seja,
//     quando cos(θ − MTA) > 0  (conjugado positivo).
//   • Margem angular ao limite = 90° − |θ − MTA| (positiva = dentro da zona).
//
// 67  (fase):    I_op = I_fase;     pol. típica = tensão de quadratura (V de
//                outra fase), MTA típico +30°/+45°/+60°.
// 67N (neutro):  I_op = 3I0;        pol. por tensão residual 3V0 (MTA ~ −45°/−60°)
//                ou por corrente 3I0 de uma fonte de aterramento.

enum PolarizationKind { voltage3V0, current3I0, voltageQuadrature }

class DirectionalResult {
  final double relativeAngle; // θ = ∠I_op − ∠pol, normalizado p/ (−180, 180]
  final double torqueAngle; // θ − MTA, normalizado
  final double torque; // cos(θ − MTA) · |I_op| · |pol| (sinal é o que importa)
  final bool forward; // conjugado positivo → falta direta (opera)
  final double angularMargin; // 90° − |θ − MTA| (graus); >0 dentro da zona
  final bool abovePickup; // |I_op| > pickup
  final bool operates; // forward && abovePickup

  const DirectionalResult({
    required this.relativeAngle,
    required this.torqueAngle,
    required this.torque,
    required this.forward,
    required this.angularMargin,
    required this.abovePickup,
    required this.operates,
  });
}

// Normaliza um ângulo em graus para o intervalo (−180, 180].
double normalizeDeg(double deg) {
  var a = deg % 360.0;
  if (a <= -180.0) a += 360.0;
  if (a > 180.0) a -= 360.0;
  return a;
}

// Avalia o elemento direcional.
//   iOpMag/iOpAng : módulo e ângulo da corrente de operação (I_fase ou 3I0)
//   polMag/polAng : módulo e ângulo da grandeza de polarização (3V0, 3I0, Vq)
//   mta           : ângulo de máximo torque (graus), relativo à polarização
//   pickup        : limiar de corrente de operação (mesma unidade de iOpMag)
DirectionalResult evaluateDirectional({
  required double iOpMag,
  required double iOpAng,
  required double polMag,
  required double polAng,
  required double mta,
  required double pickup,
}) {
  final theta = normalizeDeg(iOpAng - polAng);
  final torqueAngle = normalizeDeg(theta - mta);
  final cosT = math.cos(torqueAngle * math.pi / 180.0);
  final torque = cosT * iOpMag * polMag;
  // Fronteira (±90° do MTA, cosT ≈ 0) conta como NÃO operação. Tolerância
  // evita que cos(90°) ≈ 6e-17 (erro de float) seja lido como conjugado > 0.
  final forward = cosT > 1e-9;
  final angularMargin = 90.0 - torqueAngle.abs();
  final abovePickup = iOpMag > pickup;
  return DirectionalResult(
    relativeAngle: theta,
    torqueAngle: torqueAngle,
    torque: torque,
    forward: forward,
    angularMargin: angularMargin,
    abovePickup: abovePickup,
    operates: forward && abovePickup,
  );
}

// 3I0 = (Ia + Ib + Ic) / 1  → na prática, soma fasorial das três correntes.
// Aqui recebe módulos/ângulos das 3 fases e devolve módulo e ângulo de 3I0.
({double mag, double ang}) residualCurrent3I0({
  required double ia, required double angIa,
  required double ib, required double angIb,
  required double ic, required double angIc,
}) {
  double re(double m, double a) => m * math.cos(a * math.pi / 180.0);
  double im(double m, double a) => m * math.sin(a * math.pi / 180.0);
  final reSum = re(ia, angIa) + re(ib, angIb) + re(ic, angIc);
  final imSum = im(ia, angIa) + im(ib, angIb) + im(ic, angIc);
  final mag = math.sqrt(reSum * reSum + imSum * imSum);
  final ang = math.atan2(imSum, reSum) * 180.0 / math.pi;
  return (mag: mag, ang: ang);
}
