import 'package:flutter/material.dart';

/// Sistema de PATENTES do Duelo de Faíscas (PvP) — fonte única da verdade.
///
/// O ELO em si é apurado e gravado no servidor (Cloud Function `finalizeDuel`,
/// usando a fórmula clássica de ELO). Aqui ficam apenas as regras de exibição:
/// como o número de ELO vira patente + tier.
///
/// São 6 patentes. As 5 primeiras têm 3 tiers cada, na ordem convencional dos
/// games — entra-se no **III** (mais baixo) e sobe-se até o **I** (mais alto)
/// antes de promover. A 6ª (Mestre) é o topo aberto, sem tiers.
///
///   Iron III..I   →  0   – 799   (início do jogador: 0 = Iron III)
///   Bronze III..I →  800 – 1199
///   Silver III..I →  1200 – 1599
///   Platinum III..I → 1600 – 1999
///   Diamond III..I → 2000 – 2399
///   Mestre          → 2400+
class Patente {
  final String division; // 'Silver', 'Mestre', ...
  final String? tier; // 'I' | 'II' | 'III' | null (Mestre)
  final IconData icon;
  final Color color;
  final int elo;

  /// ELO em que começa o tier/patente atual.
  final int tierStart;

  /// ELO necessário para subir de tier/patente (`null` no Mestre).
  final int? nextThreshold;

  const Patente({
    required this.division,
    required this.tier,
    required this.icon,
    required this.color,
    required this.elo,
    required this.tierStart,
    required this.nextThreshold,
  });

  /// Rótulo completo, ex.: "Silver II" ou "Mestre".
  String get label => tier == null ? division : '$division $tier';

  bool get isMaster => tier == null;

  /// Progresso (0..1) dentro do tier atual — útil para barra de evolução.
  double get tierProgress {
    if (nextThreshold == null) return 1.0;
    final span = nextThreshold! - tierStart;
    if (span <= 0) return 1.0;
    return ((elo - tierStart) / span).clamp(0.0, 1.0);
  }

  /// Quantos pontos de ELO faltam para a próxima promoção (0 no Mestre).
  int get eloToNext =>
      nextThreshold == null ? 0 : (nextThreshold! - elo).clamp(0, 1 << 31);
}

class _Division {
  final String name;
  final int min;
  final int max; // exclusivo
  final IconData icon;
  final Color color;
  const _Division(this.name, this.min, this.max, this.icon, this.color);
}

abstract class RankUtils {
  /// ELO inicial de todo jogador (patente mais baixa: Iron III).
  static const int startingElo = 0;

  /// ELO a partir do qual o jogador é Mestre.
  static const int masterMin = 2400;

  static const List<_Division> _divisions = [
    _Division('Iron', 0, 800, Icons.security, Color(0xFF8A8F98)),
    _Division('Bronze', 800, 1200, Icons.shield, Color(0xFFCD7F32)),
    _Division('Silver', 1200, 1600, Icons.shield_moon, Color(0xFFC0C0C0)),
    _Division('Platinum', 1600, 2000, Icons.workspace_premium, Color(0xFF4FD1C5)),
    _Division('Diamond', 2000, masterMin, Icons.diamond, Color(0xFF6BC1FF)),
  ];

  /// Converte um ELO em sua patente (divisão + tier).
  static Patente fromElo(int rawElo) {
    final elo = rawElo < 0 ? 0 : rawElo;

    if (elo >= masterMin) {
      return Patente(
        division: 'Mestre',
        tier: null,
        icon: Icons.military_tech,
        color: const Color(0xFFFFD24A),
        elo: elo,
        tierStart: masterMin,
        nextThreshold: null,
      );
    }

    final d = _divisions.firstWhere(
      (d) => elo >= d.min && elo < d.max,
      orElse: () => _divisions.first,
    );

    // Cada divisão é dividida em 3 faixas iguais. Ordem convencional: a faixa
    // mais baixa é o tier III; a mais alta, o tier I.
    final width = d.max - d.min;
    final step = width / 3;
    final offset = elo - d.min;

    final String tier;
    final int tierStart;
    final int nextThreshold;
    if (offset < step) {
      tier = 'III';
      tierStart = d.min;
      nextThreshold = (d.min + step).round();
    } else if (offset < 2 * step) {
      tier = 'II';
      tierStart = (d.min + step).round();
      nextThreshold = (d.min + 2 * step).round();
    } else {
      tier = 'I';
      tierStart = (d.min + 2 * step).round();
      nextThreshold = d.max; // promove para a próxima divisão
    }

    return Patente(
      division: d.name,
      tier: tier,
      icon: d.icon,
      color: d.color,
      elo: elo,
      tierStart: tierStart,
      nextThreshold: nextThreshold,
    );
  }
}
