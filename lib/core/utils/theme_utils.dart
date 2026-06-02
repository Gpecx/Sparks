import 'package:flutter/material.dart';

class ThemeUtils {
  static const List<Map<String, dynamic>> _defaultThemeConfig = [
    {'color': Color(0xFF00C402), 'gradientEnd': Color(0xFF007A01), 'icon': Icons.bolt},
    {'color': Color(0xFF22C55E), 'gradientEnd': Color(0xFF15803D), 'icon': Icons.memory},
    {'color': Color(0xFF2DD4BF), 'gradientEnd': Color(0xFF0F766E), 'icon': Icons.gavel},
    {'color': Color(0xFF84CC16), 'gradientEnd': Color(0xFF3F6212), 'icon': Icons.lightbulb},
    {'color': Color(0xFF4ADE80), 'gradientEnd': Color(0xFF166534), 'icon': Icons.layers},
    {'color': Color(0xFF34D399), 'gradientEnd': Color(0xFF065F46), 'icon': Icons.science},
  ];

  /// Analisa o texto (título/subtítulo) e retorna um ícone adequado
  /// de acordo com a semântica da palavra, aplicando as cores nativas do Spark.
  static Map<String, dynamic> getThemeForContent(String text, {int? fallbackIndex}) {
    final lowerText = text.toLowerCase();
    IconData? icon;

    // ── IDENTIFICAÇÃO SEMÂNTICA POR PALAVRAS-CHAVE ──
    
    // 1. Equipamentos SPCS
    if (lowerText.contains('equipamentos spcs') || (lowerText.contains('equipamento') && lowerText.contains('spcs'))) {
      icon = Icons.dns_outlined; // Painel elétrico / rack de servidores
    }
    // 2. Automação
    else if (lowerText.contains('automação') && !lowerText.contains('spcs')) {
      icon = Icons.precision_manufacturing_outlined; // Braço robótico
    }
    // 3. Protocolos de Comunicação SPCS
    else if (lowerText.contains('protocolos') || lowerText.contains('comunicação')) {
      icon = Icons.hub_outlined; // Rede com pontos (network node)
    }
    // 4. Comissionamento SPCS
    else if (lowerText.contains('comissionamento')) {
      icon = Icons.fact_check_outlined; // Prancheta com checkmarks
    }
    // 5. Instalações Elétricas Industriais
    else if (lowerText.contains('instalações elétricas') || lowerText.contains('industrial')) {
      icon = Icons.electric_bolt; // Raio de energia sólido
    }
    // 6. SPDA (Sistema de Proteção Contra Descargas Atmosféricas)
    else if (lowerText.contains('spda') || lowerText.contains('descargas atmosféricas')) {
      icon = Icons.umbrella_outlined; // Guarda-chuva simples
    }
    // 7. Qualidade da Energia
    else if (lowerText.contains('qualidade da energia') || lowerText.contains('qualidade')) {
      icon = Icons.speed_outlined; // Medidor analógico (gauge)
    }
    // 8. Termografia Infravermelha
    else if (lowerText.contains('termografia') || lowerText.contains('infravermelha')) {
      icon = Icons.thermostat_outlined; // Termômetro clássico
    }
    // 9. Estudos Elétricos
    else if (lowerText.contains('estudos elétricos') || lowerText.contains('estudo')) {
      icon = Icons.architecture; // Compasso de desenho técnico
    }
    // 10. Proteção de Sistemas Elétricos
    else if (lowerText.contains('proteção')) {
      icon = Icons.shield_outlined; // Escudo de segurança
    }
    
    // Fallbacks para outras categorias
    else if (lowerText.contains('subestação') || lowerText.contains('linha') || lowerText.contains('transmissão') || lowerText.contains('distribuição')) {
      icon = Icons.account_tree_outlined; 
    }
    else if (lowerText.contains('manutenção') || lowerText.contains('transformador') || lowerText.contains('gerador') || lowerText.contains('motor')) {
      icon = Icons.engineering_outlined;
    }
    else if (lowerText.contains('aterramento') || lowerText.contains('malha')) {
      icon = Icons.grid_on_outlined;
    }
    else if (lowerText.contains('renovável') || lowerText.contains('solar') || lowerText.contains('eólica') || lowerText.contains('geração')) {
      icon = Icons.solar_power_outlined;
    }
    else if (lowerText.contains('norma') || lowerText.contains('segurança') || lowerText.contains('nr') || lowerText.contains('regulamentação')) {
      icon = Icons.health_and_safety_outlined;
    }
    else if (lowerText.contains('telecom') || lowerText.contains('fibra') || lowerText.contains('óptica')) {
      icon = Icons.cable_outlined;
    }
    else if (lowerText.contains('fundamento') || lowerText.contains('básico') || lowerText.contains('introdução')) {
      icon = Icons.lightbulb_outline;
    }
    else if (lowerText.contains('elétrica') || lowerText.contains('energia') || lowerText.contains('tensão') || lowerText.contains('corrente')) {
      icon = Icons.electric_bolt_outlined;
    }

    // Calcula um índice determinístico para a cor baseada no fallbackIndex ou num hash do texto
    // Dessa forma, a mesma categoria sempre terá a mesma cor da paleta do Spark.
    int hash = 0;
    if (text.isNotEmpty) {
      for (final code in text.codeUnits) {
        hash += code;
      }
    }
    final colorIndex = fallbackIndex ?? hash;
    
    final themeConfig = _defaultThemeConfig[colorIndex % _defaultThemeConfig.length];

    return {
      'icon': icon ?? themeConfig['icon'],
      'color': themeConfig['color'],
      'gradientEnd': themeConfig['gradientEnd'],
    };
  }
}
