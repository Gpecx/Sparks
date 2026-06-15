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

  /// Hash determinístico simples (estável entre execuções).
  static int _hash(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  /// Retorna uma **família de ícones equivalentes** para o conteúdo — todos
  /// representam o mesmo conceito (mantêm o contexto), mas dão variação
  /// visual. O primeiro item é o ícone "canônico" do conceito.
  ///
  /// As regras estão ordenadas da mais específica para a mais genérica —
  /// a primeira que casar vence. Retorna `null` se nada for reconhecido.
  static List<IconData>? _iconFamily(String text) {
    final t = text.toLowerCase();
    bool has(List<String> keys) => keys.any(t.contains);

    // ── Equipamentos SPCS (painel / rack) ──────────────────────────
    if (t.contains('equipamentos spcs') || (t.contains('equipamento') && t.contains('spcs'))) {
      return const [Icons.dns_outlined, Icons.dns, Icons.storage, Icons.developer_board, Icons.memory];
    }
    // ── SCADA / Supervisório / IHM (tela de supervisão) ────────────
    if (has(['scada', 'supervisório', 'supervisorio', 'ihm', 'interface homem'])) {
      return const [Icons.desktop_windows_outlined, Icons.monitor, Icons.desktop_windows, Icons.devices, Icons.important_devices];
    }
    // ── CLP / PLC / lógica ladder (chip / placa) ───────────────────
    if (has(['clp', ' plc', 'controlador lógico', 'controlador logico', 'ladder'])) {
      return const [Icons.developer_board, Icons.memory, Icons.code, Icons.terminal, Icons.integration_instructions];
    }
    // ── Automação (braço robótico) ─────────────────────────────────
    if (t.contains('automação') && !t.contains('spcs')) {
      return const [Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, Icons.factory, Icons.conveyor_belt, Icons.settings_suggest];
    }
    // ── Protocolos de comunicação específicos (ethernet industrial) ─
    if (has(['modbus', 'dnp3', 'iec 608', 'iec 61850', 'profibus', 'profinet', 'fieldbus', 'hart', 'can bus'])) {
      return const [Icons.settings_ethernet, Icons.settings_input_component, Icons.lan, Icons.usb, Icons.settings_input_hdmi];
    }
    // ── Protocolos / comunicação / rede (nós de rede) ──────────────
    if (has(['protocolos', 'protocolo', 'comunicação', 'comunicacao', 'rede '])) {
      return const [Icons.hub_outlined, Icons.hub, Icons.device_hub, Icons.schema, Icons.account_tree];
    }
    // ── Comissionamento / energização (checklist) ──────────────────
    if (has(['comissionamento', 'energização', 'energizacao', 'startup', 'start-up'])) {
      return const [Icons.fact_check_outlined, Icons.fact_check, Icons.checklist, Icons.rule, Icons.task_alt];
    }
    // ── Ensaios / testes / calibração (frasco de laboratório) ──────
    if (has(['ensaio', 'calibração', 'calibracao'])) {
      return const [Icons.science_outlined, Icons.science, Icons.biotech, Icons.scale, Icons.balance];
    }
    // ── Instalações elétricas industriais (raio sólido) ────────────
    if (has(['instalações elétricas', 'instalacoes eletricas', 'industrial'])) {
      return const [Icons.electric_bolt, Icons.bolt, Icons.offline_bolt, Icons.electrical_services, Icons.power];
    }
    // ── SPDA / descargas atmosféricas (guarda-chuva) ───────────────
    if (has(['spda', 'descargas atmosféricas', 'descargas atmosfericas', 'para-raio', 'para raio', 'pararraio'])) {
      return const [Icons.umbrella_outlined, Icons.umbrella, Icons.flash_on, Icons.bolt, Icons.offline_bolt];
    }
    // ── Aterramento / malha de terra (grade) ───────────────────────
    if (has(['aterramento', 'malha', 'equipotencial'])) {
      return const [Icons.grid_on_outlined, Icons.grid_on, Icons.grid_view, Icons.blur_on, Icons.scatter_plot];
    }
    // ── Qualidade da energia / harmônicos (medidor) ────────────────
    if (has(['qualidade da energia', 'qualidade', 'harmônic', 'harmonic', 'distorção', 'distorcao', 'flicker', 'afundamento'])) {
      return const [Icons.speed_outlined, Icons.speed, Icons.graphic_eq, Icons.equalizer, Icons.insights];
    }
    // ── Termografia / temperatura (termômetro) ─────────────────────
    if (has(['termografia', 'infravermelha', 'temperatura', 'térmic', 'termic'])) {
      return const [Icons.thermostat_outlined, Icons.thermostat, Icons.device_thermostat, Icons.heat_pump, Icons.whatshot];
    }
    // ── Estudos elétricos / curto-circuito / seletividade (régua) ──
    if (has(['estudos elétricos', 'estudos eletricos', 'estudo', 'curto-circuito', 'curto circuito', 'curto', 'fluxo de carga', 'fluxo de potência', 'fluxo de potencia', 'seletividade', 'coordenação', 'coordenacao'])) {
      return const [Icons.architecture, Icons.straighten, Icons.square_foot, Icons.functions, Icons.calculate];
    }
    // ── Proteção / relés / disjuntores (escudo) ────────────────────
    if (has(['proteção', 'protecao', 'relé', 'relay', 'relés', 'reles', 'sobrecorrente', 'diferencial', 'fusível', 'fusivel', 'disjuntor'])) {
      return const [Icons.shield_outlined, Icons.shield, Icons.security, Icons.gpp_good, Icons.verified_user];
    }
    // ── Transformadores / reatores (serviços elétricos) ────────────
    if (has(['transformador', 'trafo', 'reator'])) {
      return const [Icons.electrical_services_outlined, Icons.electrical_services, Icons.electric_meter, Icons.transform, Icons.power];
    }
    // ── Motores / acionamentos / inversores (engrenagem) ───────────
    if (has(['motor', 'acionamento', 'partida', 'soft starter', 'inversor', 'vfd'])) {
      return const [Icons.settings_outlined, Icons.settings, Icons.settings_applications, Icons.tune, Icons.toggle_on];
    }
    // ── Baterias / nobreak / retificador (bateria) ─────────────────
    if (has(['bateria', 'banco de baterias', 'nobreak', 'no-break', 'no break', 'retificador', 'ups '])) {
      return const [Icons.battery_charging_full_outlined, Icons.battery_charging_full, Icons.battery_full, Icons.ev_station, Icons.charging_station];
    }
    // ── Cabos / condutores / barramentos (cabo) ────────────────────
    if (has(['cabo', 'cabeamento', 'condutor', 'barramento'])) {
      return const [Icons.cable_outlined, Icons.cable, Icons.settings_input_component, Icons.power_input, Icons.usb];
    }
    // ── Subestações / linhas / transmissão (diagrama) ──────────────
    if (has(['subestação', 'subestacao', 'linha', 'transmissão', 'transmissao', 'distribuição', 'distribuicao', 'alimentador'])) {
      return const [Icons.account_tree_outlined, Icons.account_tree, Icons.device_hub, Icons.schema, Icons.polyline];
    }
    // ── Manutenção / preditiva / preventiva (engenharia) ───────────
    if (has(['manutenção', 'manutencao', 'preditiva', 'preventiva', 'gerador'])) {
      return const [Icons.engineering_outlined, Icons.engineering, Icons.handyman, Icons.build, Icons.home_repair_service];
    }
    // ── Medição / instrumentação / sensores (sensores) ─────────────
    if (has(['medição', 'medicao', 'medidor', 'instrumentação', 'instrumentacao', 'sensor', 'transdutor'])) {
      return const [Icons.sensors_outlined, Icons.sensors, Icons.radar, Icons.sensor_door, Icons.monitor_heart];
    }
    // ── Energias renováveis / solar / eólica (painel solar) ────────
    if (has(['renovável', 'renovavel', 'solar', 'fotovoltaic', 'eólica', 'eolica', 'geração', 'geracao'])) {
      return const [Icons.solar_power_outlined, Icons.solar_power, Icons.wind_power, Icons.energy_savings_leaf, Icons.eco];
    }
    // ── Normas / segurança / NRs (capacete de segurança) ───────────
    if (has(['norma', 'segurança', 'seguranca', 'nr-10', 'nr10', 'nr 10', 'nr-35', 'nr35', 'regulamentação', 'regulamentacao', 'nbr'])) {
      return const [Icons.health_and_safety_outlined, Icons.health_and_safety, Icons.verified, Icons.admin_panel_settings, Icons.fire_extinguisher];
    }
    // ── Telecom / fibra óptica (roteador) ──────────────────────────
    if (has(['telecom', 'fibra', 'óptica', 'optica'])) {
      return const [Icons.router_outlined, Icons.router, Icons.cell_tower, Icons.satellite_alt, Icons.podcasts];
    }
    // ── Fundamentos / introdução / conceitos (lâmpada) ─────────────
    if (has(['fundamento', 'básico', 'basico', 'introdução', 'introducao', 'conceito', 'princípio', 'principio'])) {
      return const [Icons.lightbulb_outline, Icons.lightbulb, Icons.tips_and_updates, Icons.emoji_objects, Icons.school];
    }
    // ── Elétrica genérica / energia / tensão (raio) ────────────────
    if (has(['elétrica', 'eletrica', 'energia', 'tensão', 'tensao', 'corrente', 'circuito'])) {
      return const [Icons.electric_bolt_outlined, Icons.electric_bolt, Icons.bolt, Icons.flash_on, Icons.offline_bolt, Icons.power];
    }

    return null;
  }

  /// Ícone semântico "canônico" para um conteúdo (o primeiro da família),
  /// ou `null` se nada casar. Usado pelas categorias.
  static IconData? iconForText(String text) => _iconFamily(text)?.first;

  /// Retorna apenas o ícone semântico para um conteúdo.
  ///
  /// Usado por módulos/trilhas: deriva um ícone do próprio título/subtítulo.
  /// Se nada casar, usa [fallback] (tipicamente o ícone da categoria) ou,
  /// na ausência dele, um ícone padrão.
  static IconData getIconForContent(String text, {IconData? fallback}) {
    return iconForText(text) ?? fallback ?? Icons.bolt;
  }

  /// Pool grande de ícones distintos (tema elétrica / engenharia / estudo)
  /// usado para garantir unicidade quando o ícone semântico colide ou falta.
  static const List<IconData> _uniqueIconPool = [
    // ── Energia / eletricidade ──────────────────────────────────────
    Icons.bolt, Icons.flash_on, Icons.flash_auto, Icons.offline_bolt,
    Icons.electric_bolt, Icons.power, Icons.power_settings_new,
    Icons.power_input, Icons.power_off, Icons.electrical_services,
    Icons.electric_meter, Icons.outlet, Icons.charging_station,
    Icons.ev_station, Icons.electric_car, Icons.electric_scooter,
    Icons.electric_moped, Icons.electric_bike,
    // ── Baterias / armazenamento de energia ─────────────────────────
    Icons.battery_charging_full, Icons.battery_full, Icons.battery_std,
    Icons.battery_alert, Icons.battery_saver, Icons.battery_5_bar,
    // ── Iluminação ──────────────────────────────────────────────────
    Icons.lightbulb, Icons.lightbulb_outline, Icons.tips_and_updates,
    Icons.emoji_objects, Icons.light_mode, Icons.wb_incandescent,
    Icons.light,
    // ── Cabos / conexões / entradas ─────────────────────────────────
    Icons.cable, Icons.settings_input_component,
    Icons.settings_input_hdmi, Icons.settings_input_svideo,
    Icons.settings_input_antenna, Icons.settings_input_composite,
    Icons.settings_ethernet, Icons.usb, Icons.nfc, Icons.bluetooth,
    Icons.cast, Icons.cast_connected,
    // ── Redes / comunicação ─────────────────────────────────────────
    Icons.lan, Icons.hub, Icons.router, Icons.wifi, Icons.wifi_tethering,
    Icons.cell_tower, Icons.satellite_alt, Icons.podcasts,
    Icons.network_check, Icons.signal_cellular_alt, Icons.settings_remote,
    Icons.device_hub, Icons.account_tree, Icons.schema, Icons.polyline,
    // ── Computação / eletrônica / dispositivos ──────────────────────
    Icons.memory, Icons.developer_board, Icons.dns, Icons.storage,
    Icons.computer, Icons.monitor, Icons.desktop_windows, Icons.laptop,
    Icons.laptop_chromebook, Icons.devices, Icons.devices_other,
    Icons.important_devices, Icons.terminal, Icons.code, Icons.data_object,
    Icons.data_array, Icons.integration_instructions, Icons.api,
    Icons.webhook,
    // ── Industrial / automação ──────────────────────────────────────
    Icons.precision_manufacturing, Icons.factory, Icons.conveyor_belt,
    Icons.settings, Icons.settings_applications, Icons.settings_suggest,
    Icons.tune, Icons.toggle_on,
    // ── Ferramentas / engenharia / construção ───────────────────────
    Icons.build, Icons.build_circle, Icons.handyman, Icons.construction,
    Icons.engineering, Icons.hardware, Icons.plumbing, Icons.carpenter,
    Icons.design_services, Icons.home_repair_service,
    Icons.miscellaneous_services, Icons.roofing, Icons.foundation,
    // ── Medição / sensores / climatização ───────────────────────────
    Icons.speed, Icons.thermostat, Icons.device_thermostat,
    Icons.ac_unit, Icons.heat_pump, Icons.whatshot, Icons.air,
    Icons.water_drop, Icons.gas_meter, Icons.sensors, Icons.radar,
    Icons.sensor_door, Icons.sensor_window, Icons.sensor_occupied,
    Icons.monitor_heart, Icons.scale, Icons.balance,
    // ── Energia renovável / sustentabilidade ────────────────────────
    Icons.solar_power, Icons.wind_power, Icons.energy_savings_leaf,
    Icons.eco, Icons.recycling,
    // ── Ciência / matemática / medidas ──────────────────────────────
    Icons.science, Icons.biotech, Icons.calculate, Icons.functions,
    Icons.architecture, Icons.straighten, Icons.square_foot,
    Icons.transform, Icons.draw, Icons.psychology,
    // ── Gráficos / dados / análise ──────────────────────────────────
    Icons.graphic_eq, Icons.equalizer, Icons.insights, Icons.analytics,
    Icons.query_stats, Icons.timeline, Icons.scatter_plot,
    Icons.bubble_chart, Icons.blur_on, Icons.grid_view, Icons.grid_on,
    Icons.layers, Icons.dashboard, Icons.view_in_ar,
    // ── Estudo / conteúdo ───────────────────────────────────────────
    Icons.school, Icons.menu_book, Icons.auto_stories, Icons.library_books,
    Icons.article, Icons.history_edu, Icons.local_library, Icons.book,
    Icons.import_contacts, Icons.chrome_reader_mode, Icons.quiz,
    Icons.edit_note, Icons.description, Icons.summarize, Icons.topic,
    // ── Verificação / segurança / normas ────────────────────────────
    Icons.assignment, Icons.fact_check, Icons.rule, Icons.checklist,
    Icons.task_alt, Icons.verified, Icons.verified_user, Icons.shield,
    Icons.security, Icons.gpp_good, Icons.health_and_safety,
    Icons.admin_panel_settings, Icons.vpn_key, Icons.gavel,
    Icons.umbrella, Icons.fire_extinguisher,
  ];

  /// Atribui um ícone **único** a cada item de [texts] (na ordem dada).
  ///
  /// Garante que não haja repetição na lista e que nenhum item use o
  /// [categoryIcon]. O [seed] (ex.: id/título da categoria) faz a escolha
  /// **variar entre categorias diferentes**, evitando que o mesmo conceito
  /// (ex.: "raio" de elétrica) apareça idêntico em categorias distintas.
  ///
  /// Estratégia:
  ///  1. Para cada texto, escolhe um membro da sua família semântica —
  ///     o membro é selecionado por hash(seed+texto), então o contexto é
  ///     mantido mas o ícone varia por categoria. Se o escolhido já estiver
  ///     em uso, tenta os outros membros da família.
  ///  2. Quem não casou em nenhuma família (ou cuja família esgotou) recebe
  ///     o próximo ícone livre do pool, começando num offset por categoria.
  ///
  /// Determinístico para a mesma lista + seed.
  static List<IconData> assignUniqueIcons(List<String> texts, {IconData? categoryIcon, String seed = ''}) {
    final used = <IconData>{};
    // O módulo nunca deve repetir o ícone da própria categoria.
    if (categoryIcon != null) used.add(categoryIcon);

    final result = List<IconData?>.filled(texts.length, null);

    // 1ª passada: membro da família semântica, variando por categoria.
    for (var i = 0; i < texts.length; i++) {
      final fam = _iconFamily(texts[i]);
      if (fam == null || fam.isEmpty) continue;
      final start = _hash('$seed|${texts[i]}') % fam.length;
      for (var k = 0; k < fam.length; k++) {
        final cand = fam[(start + k) % fam.length];
        if (!used.contains(cand)) {
          used.add(cand);
          result[i] = cand;
          break;
        }
      }
    }

    // 2ª passada: preenche os pendentes com ícones livres do pool,
    // começando num offset dependente da categoria.
    final n = _uniqueIconPool.length;
    final offset = _hash(seed) % n;
    var step = 0;
    for (var i = 0; i < texts.length; i++) {
      if (result[i] != null) continue;
      while (step < n) {
        final cand = _uniqueIconPool[(offset + step) % n];
        step++;
        if (!used.contains(cand)) {
          used.add(cand);
          result[i] = cand;
          break;
        }
      }
      // Pool esgotado (mais módulos que ícones distintos) — cenário muito
      // improvável. Cicla o pool de forma determinística por posição.
      result[i] ??= _uniqueIconPool[(offset + i) % n];
    }

    return result.cast<IconData>();
  }

  /// Analisa o texto (título/subtítulo) e retorna um ícone adequado
  /// de acordo com a semântica da palavra, aplicando as cores nativas do Spark.
  static Map<String, dynamic> getThemeForContent(String text, {int? fallbackIndex}) {
    final icon = iconForText(text);

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
