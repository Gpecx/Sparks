import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/tools/symmetrical_components_screen.dart';
import 'package:spark_app/screens/tools/per_unit_screen.dart';
import 'package:spark_app/screens/tools/idmt_curves_screen.dart';
import 'package:spark_app/screens/tools/rtc_rtp_screen.dart';
import 'package:spark_app/screens/tools/differential_balance_screen.dart';
import 'package:spark_app/screens/tools/short_circuit_screen.dart';
import 'package:spark_app/screens/tools/voltage_drop_screen.dart';
import 'package:spark_app/screens/tools/power_factor_screen.dart';
import 'package:spark_app/screens/tools/ct_saturation_screen.dart';
import 'package:spark_app/screens/tools/coordination_screen.dart';
import 'package:spark_app/screens/tools/distance_protection_screen.dart';
import 'package:spark_app/screens/tools/ground_grid_screen.dart';
import 'package:spark_app/screens/tools/signal_scaling_screen.dart';
import 'package:spark_app/screens/tools/equipment_current_screen.dart';
import 'package:spark_app/screens/tools/power_triangle_screen.dart';
import 'package:spark_app/screens/tools/thermal_severity_screen.dart';
import 'package:spark_app/screens/tools/commissioning_screen.dart';
import 'package:spark_app/screens/tools/ons_voltage_screen.dart';
import 'package:spark_app/screens/tools/power_quality_screen.dart';
import 'package:spark_app/screens/tools/network_cable_screen.dart';

class _ToolConfig {
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final Color color;
  final Color gradientEnd;
  final WidgetBuilder builder;

  const _ToolConfig({
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.gradientEnd,
    required this.builder,
  });
}

const _catConversoes = 'Conversões & Análise';
const _catTI = 'Transformadores de Instrumentação';
const _catFaltas = 'Curto-Circuito & Faltas';
const _catReles = 'Proteção (Relés)';
const _catSistema = 'Sistema de Potência';
const _catAterramento = 'Aterramento & Segurança';
const _catEquip = 'Equipamentos';
const _catAutomacao = 'Automação & Instrumentação';
const _catTermografia = 'Termografia & Manutenção';
const _catComissionamento = 'Comissionamento & Ensaios';
const _catQualidade = 'Qualidade de Energia';
const _catRedes = 'Redes & Comunicação';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  final List<_ToolConfig> _tools = [
    _ToolConfig(
      title: 'Componentes Simétricas',
      description: 'Decompor e sintetizar fasores ABC ↔ sequências 0/1/2',
      category: _catConversoes,
      icon: Icons.change_circle_outlined,
      color: const Color(0xFF00C402),
      gradientEnd: const Color(0xFF007A01),
      builder: (_) => const SymmetricalComponentsScreen(),
    ),
    _ToolConfig(
      title: 'Valor por Unidade (PU)',
      description: 'Bases, conversão real ↔ pu e mudança de base',
      category: _catConversoes,
      icon: Icons.straighten_outlined,
      color: const Color(0xFF2DD4BF),
      gradientEnd: const Color(0xFF0F766E),
      builder: (_) => const PerUnitScreen(),
    ),
    _ToolConfig(
      title: 'Triângulo de Potências',
      description: 'Converte entre P (kW), Q (kvar), S (kVA) e FP',
      category: _catConversoes,
      icon: Icons.change_history,
      color: const Color(0xFF14B8A6),
      gradientEnd: const Color(0xFF115E59),
      builder: (_) => const PowerTriangleScreen(),
    ),
    _ToolConfig(
      title: 'Tensão pu — Base ONS × TP',
      description: 'Converte pu do estudo ONS para V no secundário do TP',
      category: _catConversoes,
      icon: Icons.swap_vert,
      color: const Color(0xFF38BDF8),
      gradientEnd: const Color(0xFF0369A1),
      builder: (_) => const OnsVoltageScreen(),
    ),
    _ToolConfig(
      title: 'RTC / RTP',
      description: 'Relação de transformação de TC e TP + conversões',
      category: _catTI,
      icon: Icons.transform,
      color: const Color(0xFF22C55E),
      gradientEnd: const Color(0xFF15803D),
      builder: (_) => const RtcRtpScreen(),
    ),
    _ToolConfig(
      title: 'Saturação de TC',
      description: 'Burden, tensão de joelho e verificação de saturação',
      category: _catTI,
      icon: Icons.warning_amber_outlined,
      color: const Color(0xFF16A34A),
      gradientEnd: const Color(0xFF14532D),
      builder: (_) => const CtSaturationScreen(),
    ),
    _ToolConfig(
      title: 'Curto-Circuito',
      description: 'Correntes 3φ, bifásica e monofásica-terra (Z1/Z2/Z0)',
      category: _catFaltas,
      icon: Icons.bolt,
      color: const Color(0xFF34D399),
      gradientEnd: const Color(0xFF065F46),
      builder: (_) => const ShortCircuitScreen(),
    ),
    _ToolConfig(
      title: 'Curvas de Sobrecorrente (51)',
      description: 'Tempo de atuação IDMT + gráfico, ~57 curvas IEC/IEEE/ANSI',
      category: _catReles,
      icon: Icons.show_chart,
      color: const Color(0xFF84CC16),
      gradientEnd: const Color(0xFF3F6212),
      builder: (_) => const IdmtCurvesScreen(),
    ),
    _ToolConfig(
      title: 'Balanço Diferencial (87T)',
      description: 'Coeficiente de balanço dos enrolamentos do transformador',
      category: _catReles,
      icon: Icons.balance,
      color: const Color(0xFF4ADE80),
      gradientEnd: const Color(0xFF166534),
      builder: (_) => const DifferentialBalanceScreen(),
    ),
    _ToolConfig(
      title: 'Coordenação / Seletividade',
      description: 'Margem CTI entre relé principal e de retaguarda (51)',
      category: _catReles,
      icon: Icons.compare_arrows,
      color: const Color(0xFF65A30D),
      gradientEnd: const Color(0xFF365314),
      builder: (_) => const CoordinationScreen(),
    ),
    _ToolConfig(
      title: 'Proteção de Distância (21)',
      description: 'Alcance das zonas Z1/Z2/Z3 (primário e secundário)',
      category: _catReles,
      icon: Icons.social_distance_outlined,
      color: const Color(0xFF15803D),
      gradientEnd: const Color(0xFF14532D),
      builder: (_) => const DistanceProtectionScreen(),
    ),
    _ToolConfig(
      title: 'Queda de Tensão',
      description: 'ΔV e ΔV% em alimentador trifásico',
      category: _catSistema,
      icon: Icons.trending_down,
      color: const Color(0xFF22D3EE),
      gradientEnd: const Color(0xFF0E7490),
      builder: (_) => const VoltageDropScreen(),
    ),
    _ToolConfig(
      title: 'Correção de Fator de Potência',
      description: 'Dimensiona o banco de capacitores (kvar)',
      category: _catSistema,
      icon: Icons.offline_bolt_outlined,
      color: const Color(0xFF10B981),
      gradientEnd: const Color(0xFF047857),
      builder: (_) => const PowerFactorScreen(),
    ),
    _ToolConfig(
      title: 'Malha de Aterramento (IEEE 80)',
      description: 'Tensões de toque e passo toleráveis + GPR',
      category: _catAterramento,
      icon: Icons.safety_check_outlined,
      color: const Color(0xFFCA8A04),
      gradientEnd: const Color(0xFF713F12),
      builder: (_) => const GroundGridScreen(),
    ),
    _ToolConfig(
      title: 'Qualidade de Energia',
      description: 'Carregamento de trafo e desequilíbrio (PRODIST Mód. 8)',
      category: _catQualidade,
      icon: Icons.insights_outlined,
      color: const Color(0xFFA855F7),
      gradientEnd: const Color(0xFF6B21A8),
      builder: (_) => const PowerQualityScreen(),
    ),
    _ToolConfig(
      title: 'Cabos de Rede (RJ-45)',
      description: 'Pinagem T568A/B + tabela de categorias de cabo',
      category: _catRedes,
      icon: Icons.lan_outlined,
      color: const Color(0xFF06B6D4),
      gradientEnd: const Color(0xFF0E7490),
      builder: (_) => const NetworkCableScreen(),
    ),
    _ToolConfig(
      title: 'Corrente Nominal',
      description: 'In de transformador e motor + inrush / partida',
      category: _catEquip,
      icon: Icons.electrical_services,
      color: const Color(0xFF22C55E),
      gradientEnd: const Color(0xFF15803D),
      builder: (_) => const EquipmentCurrentScreen(),
    ),
    _ToolConfig(
      title: 'Escalonamento 4–20 mA',
      description: 'Converte sinal de instrumentação ↔ grandeza de engenharia',
      category: _catAutomacao,
      icon: Icons.sensors,
      color: const Color(0xFF06B6D4),
      gradientEnd: const Color(0xFF0E7490),
      builder: (_) => const SignalScalingScreen(),
    ),
    _ToolConfig(
      title: 'Severidade Térmica',
      description: 'Classifica anomalia por ΔT + correção por carga',
      category: _catTermografia,
      icon: Icons.thermostat,
      color: const Color(0xFFF97316),
      gradientEnd: const Color(0xFF9A3412),
      builder: (_) => const ThermalSeverityScreen(),
    ),
    _ToolConfig(
      title: 'Comissionamento / Ensaios',
      description: 'Tolerância de ensaio (pass/fail) e injeção secundária',
      category: _catComissionamento,
      icon: Icons.fact_check_outlined,
      color: const Color(0xFF84CC16),
      gradientEnd: const Color(0xFF3F6212),
      builder: (_) => const CommissioningScreen(),
    ),
  ];

  List<String> get _categories {
    final seen = <String>[];
    for (final t in _tools) {
      if (!seen.contains(t.category)) seen.add(t.category);
    }
    return seen;
  }

  void _open(_ToolConfig tool) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: tool.builder));
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FERRAMENTAS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Calculadoras de engenharia para Proteção e Controle',
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const hPad = 16.0;
                      const spacing = 14.0;
                      final columns = constraints.maxWidth >= 600 ? 2 : 1;
                      final cardWidth = (constraints.maxWidth -
                              hPad * 2 -
                              spacing * (columns - 1)) /
                          columns;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          for (final category in _categories) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(4, 14, 4, 10),
                              child: Text(
                                category.toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                for (final tool in _tools
                                    .where((t) => t.category == category))
                                  SizedBox(
                                    width: cardWidth,
                                    height: 148,
                                    child: _ToolCard(
                                      tool: tool,
                                      onTap: () => _open(tool),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final _ToolConfig tool;
  final VoidCallback onTap;

  const _ToolCard({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tool.title}. ${tool.description}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  tool.color.withValues(alpha: 0.15),
                  tool.gradientEnd.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: tool.color.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: tool.color.withValues(alpha: 0.1),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tool.color, tool.gradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: tool.color.withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(tool.icon, color: Colors.white, size: 24),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        color: tool.color.withValues(alpha: 0.6),
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tool.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      tool.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
