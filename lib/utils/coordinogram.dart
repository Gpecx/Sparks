import 'package:spark_app/utils/idmt_curves.dart';

// Coordenograma — comparação/sobreposição de curvas de sobrecorrente (51).
// Reusa o motor IdmtCurve (mesma equação generalizada). Aqui só se compõe a
// definição de cada relé na tela e a checagem de intervalo de coordenação (CTI)
// num ponto de corrente comum.

class CoordRelay {
  final String label;
  final IdmtCurve curve;
  final double pickupA; // I> em ampères primários
  final double td; // dial de tempo

  const CoordRelay({
    required this.label,
    required this.curve,
    required this.pickupA,
    required this.td,
  });

  // Tempo de atuação (s) para uma corrente de falta em ampères primários.
  // Retorna null se a corrente não sensibiliza o relé (I ≤ pickup).
  double? timeAtCurrent(double faultCurrentA) {
    if (pickupA <= 0 || faultCurrentA <= pickupA) return null;
    final t = curve.timeForMultiple(faultCurrentA / pickupA, td);
    if (t.isNaN || t.isInfinite || t < 0) return null;
    return t;
  }
}

class CtiCheck {
  final double faultCurrentA;
  final double? mainTime; // relé principal (jusante)
  final double? backupTime; // relé retaguarda (montante)
  final double? margin; // backup - main
  final double requiredCti;
  final bool ok;

  const CtiCheck({
    required this.faultCurrentA,
    required this.mainTime,
    required this.backupTime,
    required this.margin,
    required this.requiredCti,
    required this.ok,
  });
}

// Verifica o CTI entre o relé principal (jusante) e o de retaguarda (montante)
// numa corrente de falta. O de retaguarda deve atuar DEPOIS, com margem ≥ CTI.
CtiCheck checkCti({
  required CoordRelay main,
  required CoordRelay backup,
  required double faultCurrentA,
  double requiredCti = 0.3,
}) {
  final tMain = main.timeAtCurrent(faultCurrentA);
  final tBackup = backup.timeAtCurrent(faultCurrentA);
  double? margin;
  bool ok = false;
  if (tMain != null && tBackup != null) {
    margin = tBackup - tMain;
    ok = margin >= requiredCti;
  }
  return CtiCheck(
    faultCurrentA: faultCurrentA,
    mainTime: tMain,
    backupTime: tBackup,
    margin: margin,
    requiredCti: requiredCti,
    ok: ok,
  );
}
