import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/services/access_control_service.dart';
import 'package:spark_app/services/analytics_service.dart';
import 'package:spark_app/widgets/plan_widgets.dart';
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
import 'package:spark_app/screens/tools/iec61850_screen.dart';
import 'package:spark_app/screens/tools/modbus_register_screen.dart';
import 'package:spark_app/screens/tools/arc_flash_screen.dart';
import 'package:spark_app/screens/tools/restricted_differential_screen.dart';
import 'package:spark_app/screens/tools/directional_67_screen.dart';
import 'package:spark_app/screens/tools/spda_risk_screen.dart';
import 'package:spark_app/screens/tools/spda_calc_screen.dart';

class _ToolConfig {
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final Color color;
  final Color gradientEnd;
  final WidgetBuilder builder;

  /// ID estável p/ gating. Vazio = ferramenta paga (só planos pagos).
  /// As 3 do Free recebem os IDs de [kFreeToolIds].
  final String id;

  const _ToolConfig({
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.gradientEnd,
    required this.builder,
    this.id = '',
  });
}

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  String get _catConversoes => AppLocalizations.of(context)!.toolsCategoryConversions;
  String get _catTI => AppLocalizations.of(context)!.toolsCategoryTI;
  String get _catFaltas => AppLocalizations.of(context)!.toolsCategoryFaults;
  String get _catReles => AppLocalizations.of(context)!.toolsCategoryRelays;
  String get _catSistema => AppLocalizations.of(context)!.toolsCategoryPowerSystem;
  String get _catAterramento => AppLocalizations.of(context)!.toolsCategoryGrounding;
  String get _catEquip => AppLocalizations.of(context)!.toolsCategoryEquipment;
  String get _catAutomacao => AppLocalizations.of(context)!.toolsCategoryAutomation;
  String get _catTermografia => AppLocalizations.of(context)!.toolsCategoryThermography;
  String get _catComissionamento => AppLocalizations.of(context)!.toolsCategoryCommissioning;
  String get _catQualidade => AppLocalizations.of(context)!.toolsPowerQualityTitle;
  String get _catRedes => AppLocalizations.of(context)!.toolsCategoryNetworks;

  List<_ToolConfig> get _tools => [
    _ToolConfig(
      id: 'symmetrical_components',
      title: AppLocalizations.of(context)!.toolsSymmetricalComponentsTitle,
      description: AppLocalizations.of(context)!.toolsSymmetricalComponentsDesc,
      category: _catConversoes,
      icon: Icons.change_circle_outlined,
      color: AppColors.primary,
      gradientEnd: const Color(0xFF007A01),
      builder: (_) => const SymmetricalComponentsScreen(),
    ),
    _ToolConfig(
      id: 'per_unit',
      title: AppLocalizations.of(context)!.toolsPerUnitTitle,
      description: AppLocalizations.of(context)!.toolsPerUnitDesc,
      category: _catConversoes,
      icon: Icons.straighten_outlined,
      color: const Color(0xFF2DD4BF),
      gradientEnd: const Color(0xFF0F766E),
      builder: (_) => const PerUnitScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsPowerTriangleTitle,
      description: AppLocalizations.of(context)!.toolsPowerTriangleDesc,
      category: _catConversoes,
      icon: Icons.change_history,
      color: const Color(0xFF14B8A6),
      gradientEnd: const Color(0xFF115E59),
      builder: (_) => const PowerTriangleScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsOnsVoltageTitle,
      description: AppLocalizations.of(context)!.toolsOnsVoltageDesc,
      category: _catConversoes,
      icon: Icons.swap_vert,
      color: const Color(0xFF38BDF8),
      gradientEnd: const Color(0xFF0369A1),
      builder: (_) => const OnsVoltageScreen(),
    ),
    _ToolConfig(
      id: 'rtc_rtp',
      title: AppLocalizations.of(context)!.toolsRtcRtpTitle,
      description: AppLocalizations.of(context)!.toolsRtcRtpDesc,
      category: _catTI,
      icon: Icons.transform,
      color: const Color(0xFF22C55E),
      gradientEnd: const Color(0xFF15803D),
      builder: (_) => const RtcRtpScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsCtSaturationTitle,
      description: AppLocalizations.of(context)!.toolsCtSaturationDesc,
      category: _catTI,
      icon: Icons.warning_amber_outlined,
      color: const Color(0xFF16A34A),
      gradientEnd: const Color(0xFF14532D),
      builder: (_) => const CtSaturationScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsShortCircuitTitle,
      description: AppLocalizations.of(context)!.toolsShortCircuitDesc,
      category: _catFaltas,
      icon: Icons.bolt,
      color: const Color(0xFF34D399),
      gradientEnd: const Color(0xFF065F46),
      builder: (_) => const ShortCircuitScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsIdmtCurvesTitle,
      description: AppLocalizations.of(context)!.toolsIdmtCurvesDesc,
      category: _catReles,
      icon: Icons.show_chart,
      color: const Color(0xFF84CC16),
      gradientEnd: const Color(0xFF3F6212),
      builder: (_) => const IdmtCurvesScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsDifferentialBalanceTitle,
      description: AppLocalizations.of(context)!.toolsDifferentialBalanceDesc,
      category: _catReles,
      icon: Icons.balance,
      color: const Color(0xFF4ADE80),
      gradientEnd: const Color(0xFF166534),
      builder: (_) => const DifferentialBalanceScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsRestrictedDifferentialTitle,
      description: AppLocalizations.of(context)!.toolsRestrictedDifferentialDesc,
      category: _catReles,
      icon: Icons.show_chart_outlined,
      color: const Color(0xFF34D399),
      gradientEnd: const Color(0xFF065F46),
      builder: (_) => const RestrictedDifferentialScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsCoordinationTitle,
      description: AppLocalizations.of(context)!.toolsCoordinationDesc,
      category: _catReles,
      icon: Icons.compare_arrows,
      color: const Color(0xFF65A30D),
      gradientEnd: const Color(0xFF365314),
      builder: (_) => const CoordinationScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsDistanceProtectionTitle,
      description: AppLocalizations.of(context)!.toolsDistanceProtectionDesc,
      category: _catReles,
      icon: Icons.social_distance_outlined,
      color: const Color(0xFF15803D),
      gradientEnd: const Color(0xFF14532D),
      builder: (_) => const DistanceProtectionScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsDirectional67Title,
      description: AppLocalizations.of(context)!.toolsDirectional67Desc,
      category: _catReles,
      icon: Icons.explore_outlined,
      color: const Color(0xFF22C55E),
      gradientEnd: const Color(0xFF15803D),
      builder: (_) => const Directional67Screen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsVoltageDropTitle,
      description: AppLocalizations.of(context)!.toolsVoltageDropDesc,
      category: _catSistema,
      icon: Icons.trending_down,
      color: const Color(0xFF22D3EE),
      gradientEnd: const Color(0xFF0E7490),
      builder: (_) => const VoltageDropScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsPowerFactorTitle,
      description: AppLocalizations.of(context)!.toolsPowerFactorDesc,
      category: _catSistema,
      icon: Icons.offline_bolt_outlined,
      color: const Color(0xFF10B981),
      gradientEnd: const Color(0xFF047857),
      builder: (_) => const PowerFactorScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsGroundGridTitle,
      description: AppLocalizations.of(context)!.toolsGroundGridDesc,
      category: _catAterramento,
      icon: Icons.safety_check_outlined,
      color: const Color(0xFFCA8A04),
      gradientEnd: const Color(0xFF713F12),
      builder: (_) => const GroundGridScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsArcFlashTitle,
      description: AppLocalizations.of(context)!.toolsArcFlashDesc,
      category: _catAterramento,
      icon: Icons.local_fire_department_outlined,
      color: const Color(0xFFF97316),
      gradientEnd: const Color(0xFF9A3412),
      builder: (_) => const ArcFlashScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsSpdaRiskTitle,
      description: AppLocalizations.of(context)!.toolsSpdaRiskDesc,
      category: _catAterramento,
      icon: Icons.flash_on_outlined,
      color: const Color(0xFFEAB308),
      gradientEnd: const Color(0xFF854D0E),
      builder: (_) => const SpdaRiskScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsSpdaCalcTitle,
      description: AppLocalizations.of(context)!.toolsSpdaCalcDesc,
      category: _catAterramento,
      icon: Icons.bolt_outlined,
      color: const Color(0xFFF59E0B),
      gradientEnd: const Color(0xFF92400E),
      builder: (_) => const SpdaCalcScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsPowerQualityTitle,
      description: AppLocalizations.of(context)!.toolsPowerQualityDesc,
      category: _catQualidade,
      icon: Icons.insights_outlined,
      color: const Color(0xFFA855F7),
      gradientEnd: const Color(0xFF6B21A8),
      builder: (_) => const PowerQualityScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsNetworkCableTitle,
      description: AppLocalizations.of(context)!.toolsNetworkCableDesc,
      category: _catRedes,
      icon: Icons.lan_outlined,
      color: const Color(0xFF06B6D4),
      gradientEnd: const Color(0xFF0E7490),
      builder: (_) => const NetworkCableScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsIec61850Title,
      description: AppLocalizations.of(context)!.toolsIec61850Desc,
      category: _catRedes,
      icon: Icons.hub_outlined,
      color: const Color(0xFF0EA5E9),
      gradientEnd: const Color(0xFF075985),
      builder: (_) => const Iec61850Screen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsModbusRegisterTitle,
      description: AppLocalizations.of(context)!.toolsModbusRegisterDesc,
      category: _catRedes,
      icon: Icons.memory_outlined,
      color: const Color(0xFF0891B2),
      gradientEnd: const Color(0xFF155E75),
      builder: (_) => const ModbusRegisterScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsEquipmentCurrentTitle,
      description: AppLocalizations.of(context)!.toolsEquipmentCurrentDesc,
      category: _catEquip,
      icon: Icons.electrical_services,
      color: const Color(0xFF22C55E),
      gradientEnd: const Color(0xFF15803D),
      builder: (_) => const EquipmentCurrentScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsSignalScalingTitle,
      description: AppLocalizations.of(context)!.toolsSignalScalingDesc,
      category: _catAutomacao,
      icon: Icons.sensors,
      color: const Color(0xFF06B6D4),
      gradientEnd: const Color(0xFF0E7490),
      builder: (_) => const SignalScalingScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsThermalSeverityTitle,
      description: AppLocalizations.of(context)!.toolsThermalSeverityDesc,
      category: _catTermografia,
      icon: Icons.thermostat,
      color: const Color(0xFFF97316),
      gradientEnd: const Color(0xFF9A3412),
      builder: (_) => const ThermalSeverityScreen(),
    ),
    _ToolConfig(
      title: AppLocalizations.of(context)!.toolsCommissioningTitle,
      description: AppLocalizations.of(context)!.toolsCommissioningDesc,
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
    final access = ref.read(accessControlProvider);
    if (!access.canAccessTool(tool.id)) {
      AnalyticsService().logLockedFeatureAccessed(
          feature: 'tool', itemId: tool.id.isEmpty ? tool.title : tool.id);
      UpgradePromptBottomSheet.show(context, feature: 'tool', trigger: 'tool_locked');
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: tool.builder));
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(accessControlProvider);
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
                      Text(
                        AppLocalizations.of(context)!.toolsMainTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.toolsMainSubtitle,
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
                      const spacing = 12.0;
                      // Grade responsiva: alvo ~108px por tile, mín. 3 colunas.
                      final available = constraints.maxWidth - hPad * 2;
                      var columns = (available / 120).floor();
                      if (columns < 3) columns = 3;
                      final tileWidth =
                          (available - spacing * (columns - 1)) / columns;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          for (final category in _categories) ...[
                            _CategoryHeader(
                              title: category,
                              count: _tools
                                  .where((t) => t.category == category)
                                  .length,
                            ),
                            Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                for (final tool in _tools
                                    .where((t) => t.category == category))
                                  SizedBox(
                                    width: tileWidth,
                                    height: tileWidth,
                                    child: _ToolTile(
                                      tool: tool,
                                      locked: !access.canAccessTool(tool.id),
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

// Cabeçalho de uma categoria, com a contagem de ferramentas.
class _CategoryHeader extends StatelessWidget {
  final String title;
  final int count;

  const _CategoryHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.95),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tile quadrado (estilo launcher): ícone grande em destaque + título.
class _ToolTile extends StatelessWidget {
  final _ToolConfig tool;
  final VoidCallback onTap;
  final bool locked;

  const _ToolTile({required this.tool, required this.onTap, this.locked = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tool.title}. ${tool.description}${locked ? '. Bloqueado — exclusivo de planos pagos' : ''}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              Opacity(
                opacity: locked ? 0.55 : 1,
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
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tool.color, tool.gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: tool.color.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(tool.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: Text(
                      tool.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
                ),
                ),
                if (locked)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.6)),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: AppColors.primary, size: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
  }
}
