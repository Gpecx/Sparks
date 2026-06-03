import 'dart:math' as math;
import 'package:spark_app/utils/idmt_curves.dart';

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
//   • O setor de operação tem abertura "sectorOpening" centrada no MTA. Por
//     padrão 180° (±90° do MTA), que é o caso clássico de cos(θ − MTA) > 0.
//   • Quando o usuário seleciona "Reverse", o setor é espelhado em 180°.
//   • Margem angular ao limite = (sectorOpening/2) − |θ − MTA|.
//
// Característica de tempo:
//   • Definite Time: tempo fixo (ms) após o pickup ser ultrapassado.
//   • IDMT: curvas IEC/IEEE/ANSI/etc com fórmula
//       t = (A·Td + K1) / (M^P − Q) + B·Td + K2,  com M = I_op / I_pickup
//
// 67  (fase):    I_op = I_fase;  pol. típica = tensão de quadratura, MTA +30/+45/+60°.
// 67N (neutro):  I_op = 3I0;     pol. por 3V0 (MTA ~ −45/−60°) ou por 3I0.

enum CharacteristicType { definiteTime, idmt }

enum DirectionMode { nonDirectional, forward, reverse }

enum FaultType { phaseToPhase, phaseToNeutral }

enum PolarizationKind { voltage3V0, current3I0, voltageQuadrature }

/// Fase protegida pelo elemento 67 (quando em modo trifásico).
enum ProtectedPhase { a, b, c }

extension ProtectedPhaseX on ProtectedPhase {
  String get label {
    switch (this) {
      case ProtectedPhase.a:
        return 'A';
      case ProtectedPhase.b:
        return 'B';
      case ProtectedPhase.c:
        return 'C';
    }
  }

  /// Descrição em texto da equação de polarização por quadratura.
  /// Ex.: "V_PA = V_B − V_C"
  String get polarizationFormula {
    switch (this) {
      case ProtectedPhase.a:
        return 'V_PA = V_B − V_C';
      case ProtectedPhase.b:
        return 'V_PB = V_C − V_A';
      case ProtectedPhase.c:
        return 'V_PC = V_A − V_B';
    }
  }
}

/// Tensão de polarização por quadratura para o elemento da fase indicada.
///
/// Esquema clássico usado em 67/21:
/// • Fase A: V_PA = V_B − V_C
/// • Fase B: V_PB = V_C − V_A
/// • Fase C: V_PC = V_A − V_B
///
/// Em sistema equilibrado com FP=1, essa tensão fica exatamente 90° atrás da
/// tensão de fase protegida — daí o nome "quadratura". Durante uma falta na
/// própria fase A, V_A pode colapsar quase para zero, mas V_B e V_C continuam
/// sãs → a polarização permanece estável.
({double mag, double ang}) quadraturePolarization({
  required ProtectedPhase phase,
  required double va, required double angVa,
  required double vb, required double angVb,
  required double vc, required double angVc,
}) {
  double re(double m, double a) => m * math.cos(a * math.pi / 180.0);
  double im(double m, double a) => m * math.sin(a * math.pi / 180.0);

  double dRe;
  double dIm;
  switch (phase) {
    case ProtectedPhase.a:
      dRe = re(vb, angVb) - re(vc, angVc);
      dIm = im(vb, angVb) - im(vc, angVc);
      break;
    case ProtectedPhase.b:
      dRe = re(vc, angVc) - re(va, angVa);
      dIm = im(vc, angVc) - im(va, angVa);
      break;
    case ProtectedPhase.c:
      dRe = re(va, angVa) - re(vb, angVb);
      dIm = im(va, angVa) - im(vb, angVb);
      break;
  }
  final mag = math.sqrt(dRe * dRe + dIm * dIm);
  final ang = math.atan2(dIm, dRe) * 180.0 / math.pi;
  return (mag: mag, ang: ang);
}

/// Estende `DirectionalResult` antigo com a decisão completa do 67:
/// pickup, direção, tempo de atuação.
class Directional67Result {
  final double relativeAngle;     // θ = ∠Iop − ∠pol (graus, em (−180, 180])
  final double torqueAngle;       // θ − MTA (graus, normalizado)
  final double angularMargin;     // (sectorOpening/2) − |torqueAngle| (graus)
  final bool inForwardSector;     // corrente cai no setor DIRETO
  final bool inSelectedSector;    // corrente cai no setor selecionado pelo usuário
  final bool abovePickup;         // |Iop| > pickup
  final bool operates;            // decisão final de trip
  final double? operatingTimeMs;  // tempo até o trip em ms (null se não opera)
  final String verdict;           // texto curto da decisão
  final String reason;            // explicação completa

  const Directional67Result({
    required this.relativeAngle,
    required this.torqueAngle,
    required this.angularMargin,
    required this.inForwardSector,
    required this.inSelectedSector,
    required this.abovePickup,
    required this.operates,
    required this.operatingTimeMs,
    required this.verdict,
    required this.reason,
  });
}

// Normaliza um ângulo em graus para o intervalo (−180, 180].
double normalizeDeg(double deg) {
  var a = deg % 360.0;
  if (a <= -180.0) a += 360.0;
  if (a > 180.0) a -= 360.0;
  return a;
}

/// MTA recomendado para o tipo de falta e elemento (67 ou 67N).
/// Valores tipicos da literatura/manuais de fabricante. Triagem.
double recommendedMta({
  required FaultType faultType,
  required bool isNeutral,
}) {
  if (isNeutral) {
    // 67N polarizado por 3V0:
    // - F-N puro: −45° (resistivo a indutivo)
    // - F-F-N (com componente residual): −60° em sistemas mais reatantes
    return faultType == FaultType.phaseToNeutral ? -45.0 : -60.0;
  }
  // 67 fase:
  // - F-N: +30° (típico em sistemas de média tensão)
  // - F-F: +60° (típico em alta tensão / curtos predominantemente reatantes)
  return faultType == FaultType.phaseToPhase ? 60.0 : 30.0;
}

/// Avaliação completa do elemento 67/67N: pickup + direção + tempo.
///
/// [characteristic]   Definite Time (tempo fixo) ou IDMT (curva).
/// [idmtCurve]        Curva selecionada quando characteristic == idmt.
/// [td]               Time dial (multiplicador) usado pela curva IDMT.
/// [definiteTimeMs]   Tempo fixo (ms) usado quando characteristic == definiteTime.
/// [direction]        Modo direcional desejado pelo usuário.
/// [mta]              Ângulo de máximo torque (graus, relativo à polarização).
/// [sectorOpening]    Abertura do setor (graus). Default 180° (±90° em torno do MTA).
/// [pickup]           Limiar de corrente de operação (mesma unidade de iOpMag).
/// [iOpMag], [iOpAng] Módulo e ângulo da corrente de operação.
/// [polMag], [polAng] Módulo e ângulo da grandeza de polarização.
Directional67Result evaluate67({
  required CharacteristicType characteristic,
  IdmtCurve? idmtCurve,
  double td = 1.0,
  double definiteTimeMs = 100.0,
  DirectionMode direction = DirectionMode.forward,
  required double mta,
  double sectorOpening = 180.0,
  required double pickup,
  required double iOpMag,
  required double iOpAng,
  required double polMag,
  required double polAng,
}) {
  final theta = normalizeDeg(iOpAng - polAng);
  final torqueAngle = normalizeDeg(theta - mta);
  final halfSector = sectorOpening / 2.0;
  final inForwardSector = torqueAngle.abs() <= halfSector + 1e-9;

  // Para "reverse", o setor é espelhado em 180°: testa o ângulo deslocado.
  final reverseDelta = normalizeDeg(theta - (mta + 180.0));
  final inReverseSector = reverseDelta.abs() <= halfSector + 1e-9;

  final bool inSelectedSector;
  switch (direction) {
    case DirectionMode.nonDirectional:
      inSelectedSector = true;
      break;
    case DirectionMode.forward:
      inSelectedSector = inForwardSector;
      break;
    case DirectionMode.reverse:
      inSelectedSector = inReverseSector;
      break;
  }

  final angularMargin = halfSector - torqueAngle.abs();
  final abovePickup = iOpMag > pickup;
  final operates = inSelectedSector && abovePickup;

  double? opTime;
  if (operates) {
    if (characteristic == CharacteristicType.definiteTime) {
      opTime = definiteTimeMs;
    } else if (idmtCurve != null && pickup > 0) {
      final m = iOpMag / pickup;
      if (m > 1.0) {
        final tSec = idmtCurve.timeForMultiple(m, td);
        if (tSec.isFinite && tSec > 0) {
          opTime = tSec * 1000.0;
        }
      }
    }
  }

  final verdict = _verdictFor(
    direction: direction,
    inSelectedSector: inSelectedSector,
    abovePickup: abovePickup,
    inForwardSector: inForwardSector,
    inReverseSector: inReverseSector,
  );

  final reason = _reasonFor(
    direction: direction,
    theta: theta,
    torqueAngle: torqueAngle,
    mta: mta,
    halfSector: halfSector,
    inSelectedSector: inSelectedSector,
    inForwardSector: inForwardSector,
    abovePickup: abovePickup,
    pickup: pickup,
    iOpMag: iOpMag,
    characteristic: characteristic,
    operatingTimeMs: opTime,
  );

  return Directional67Result(
    relativeAngle: theta,
    torqueAngle: torqueAngle,
    angularMargin: angularMargin,
    inForwardSector: inForwardSector,
    inSelectedSector: inSelectedSector,
    abovePickup: abovePickup,
    operates: operates,
    operatingTimeMs: opTime,
    verdict: verdict,
    reason: reason,
  );
}

String _verdictFor({
  required DirectionMode direction,
  required bool inSelectedSector,
  required bool abovePickup,
  required bool inForwardSector,
  required bool inReverseSector,
}) {
  if (!abovePickup) return 'NÃO OPERA — corrente abaixo do pickup';
  switch (direction) {
    case DirectionMode.nonDirectional:
      return 'OPERA — modo não direcional, acima do pickup';
    case DirectionMode.forward:
      if (inForwardSector) return 'OPERA — falta DIRETA acima do pickup';
      return 'BLOQUEIA — falta REVERSA (ajuste = forward)';
    case DirectionMode.reverse:
      if (inReverseSector) return 'OPERA — falta REVERSA acima do pickup (ajuste = reverse)';
      return 'BLOQUEIA — falta direta (ajuste = reverse)';
  }
}

String _reasonFor({
  required DirectionMode direction,
  required double theta,
  required double torqueAngle,
  required double mta,
  required double halfSector,
  required bool inSelectedSector,
  required bool inForwardSector,
  required bool abovePickup,
  required double pickup,
  required double iOpMag,
  required CharacteristicType characteristic,
  required double? operatingTimeMs,
}) {
  final b = StringBuffer();
  b.write('θ = ∠Iop − ∠pol = ${theta.toStringAsFixed(1)}°. ');
  b.write('θ − MTA = ${torqueAngle.toStringAsFixed(1)}° ');
  b.write('(setor ±${halfSector.toStringAsFixed(0)}° em torno de MTA = ${mta.toStringAsFixed(1)}°). ');
  if (abovePickup) {
    b.write('Iop=${iOpMag.toStringAsFixed(3)} > pickup=${pickup.toStringAsFixed(3)}. ');
  } else {
    b.write('Iop=${iOpMag.toStringAsFixed(3)} ≤ pickup=${pickup.toStringAsFixed(3)}. ');
  }
  if (direction != DirectionMode.nonDirectional) {
    b.write(inSelectedSector
        ? 'Corrente DENTRO do setor selecionado. '
        : 'Corrente FORA do setor selecionado. ');
  }
  if (operatingTimeMs != null) {
    if (characteristic == CharacteristicType.definiteTime) {
      b.write('Tempo definite = ${operatingTimeMs.toStringAsFixed(0)} ms.');
    } else {
      b.write('Tempo IDMT = ${operatingTimeMs.toStringAsFixed(0)} ms.');
    }
  }
  return b.toString();
}

// ─── Compat. com versão anterior (mantida para não quebrar consumidores) ────

/// Resultado da avaliação direcional simples (versão clássica, ±90° do MTA).
class DirectionalResult {
  final double relativeAngle;
  final double torqueAngle;
  final double torque;
  final bool forward;
  final double angularMargin;
  final bool abovePickup;
  final bool operates;

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

// 3I0 = (Ia + Ib + Ic). Soma fasorial. Retorna módulo e ângulo.
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
