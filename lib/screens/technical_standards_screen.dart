import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';

class TechnicalStandardsScreen extends StatefulWidget {
  const TechnicalStandardsScreen({super.key});
  @override
  State<TechnicalStandardsScreen> createState() => _TechnicalStandardsScreenState();
}

class _TechnicalStandardsScreenState extends State<TechnicalStandardsScreen> {
  String _selectedFilter = 'Todos';
  String _searchQuery = '';
  final List<String> _filters = ['Todos', 'NRs', 'TCs', 'TPs'];

  final List<Map<String, dynamic>> _allStandards = [
    {'code': 'NR-10', 'type': 'NR', 'description': 'Segurança em Instalações e Serviços em Eletricidade', 'progress': 1.0, 'status': 'COMPLETO', 'statusColor': AppColors.primary, 'icon': Icons.electrical_services},
    {'code': 'NR-12', 'type': 'NR', 'description': 'Segurança no Trabalho em Máquinas e Equipamentos', 'progress': 0.3, 'status': 'EM ANDAMENTO', 'statusColor': AppColors.blue, 'icon': Icons.precision_manufacturing},
    {'code': 'NR-18', 'type': 'NR', 'description': 'Segurança e Saúde no Trabalho na Construção', 'progress': 0.0, 'status': 'BLOQUEADO', 'statusColor': AppColors.textMuted, 'icon': Icons.construction},
    {'code': 'NR-23', 'type': 'NR', 'description': 'Proteção Contra Incêndios', 'progress': 0.0, 'status': 'BLOQUEADO', 'statusColor': AppColors.textMuted, 'icon': Icons.local_fire_department},
    {'code': 'NR-33', 'type': 'NR', 'description': 'Segurança e Saúde nos Trabalhos em Espaço Confinado', 'progress': 0.0, 'status': 'BLOQUEADO', 'statusColor': AppColors.textMuted, 'icon': Icons.warning_amber},
    {'code': 'NR-35', 'type': 'NR', 'description': 'Trabalho em Altura', 'progress': 0.65, 'status': 'EM ANDAMENTO', 'statusColor': AppColors.blue, 'icon': Icons.height},
    {'code': 'TC-05', 'type': 'TC', 'description': 'Trabalho em Altura e Prevenção de Quedas', 'progress': 0.45, 'status': 'EM REVISÃO', 'statusColor': AppColors.warning, 'icon': Icons.swap_vert},
    {'code': 'TC-08', 'type': 'TC', 'description': 'Controle de Qualidade em Soldagem', 'progress': 0.0, 'status': 'BLOQUEADO', 'statusColor': AppColors.textMuted, 'icon': Icons.build},
    {'code': 'TP-12', 'type': 'TP', 'description': 'Operação de Máquinas Pesadas', 'progress': 0.78, 'status': 'EM ANDAMENTO', 'statusColor': AppColors.blue, 'icon': Icons.groups},
    {'code': 'TP-15', 'type': 'TP', 'description': 'Procedimentos de Emergência Industrial', 'progress': 0.2, 'status': 'EM ANDAMENTO', 'statusColor': AppColors.blue, 'icon': Icons.emergency},
  ];

  List<Map<String, dynamic>> get _filtered {
    return _allStandards.where((s) {
      if (_selectedFilter != 'Todos') {
        final t = _selectedFilter.replaceAll('s', '');
        if (s['type'] != t) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!(s['code'] as String).toLowerCase().contains(q) &&
            !(s['description'] as String).toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('NORMAS TÉCNICAS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar normas...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                filled: true, fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4))),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filtros estilo tags EXS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _filters.map((f) {
                final sel = f == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: sel ? AppColors.primary : AppColors.cardBorder.withValues(alpha: 0.5)),
                      ),
                      child: Text(f, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.search_off, color: AppColors.textMuted, size: 48),
                  const SizedBox(height: 12),
                  Text('Nenhuma norma encontrada', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15)),
                ]),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _card(ctx, items[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> s) {
    final Color color = s['statusColor'] as Color;
    final double progress = s['progress'] as double;
    final bool locked = s['status'] == 'BLOQUEADO';
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/standard-detail'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(s['icon'] as IconData, color: locked ? AppColors.textMuted : color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['code'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(s['description'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
                  child: Text(s['status'] as String, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ],
            ),
            if (!locked) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Text('Progresso', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const Spacer(),
                Text('${(progress * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.inputBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
