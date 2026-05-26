import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';
import 'package:spark_app/services/standards_service.dart';
import 'package:spark_app/models/standard_metadata.dart';

class TechnicalStandardsScreen extends ConsumerStatefulWidget {
  const TechnicalStandardsScreen({super.key});
  @override
  ConsumerState<TechnicalStandardsScreen> createState() => _TechnicalStandardsScreenState();
}

class _TechnicalStandardsScreenState extends ConsumerState<TechnicalStandardsScreen> {
  String _selectedFilter = 'Todos';
  String _searchQuery = '';
  final List<String> _filters = ['Todos', 'NRs', 'TCs', 'TPs'];

  @override
  void initState() {
    super.initState();
    StandardsService().initializeStandards();
  }

  @override
  Widget build(BuildContext context) {
    final isTestMode = kDebugMode && ref.watch(devModeProvider);
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            title: const Text('MÓDULOS EM DESTAQUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5)),
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
              Expanded(
                child: StreamBuilder<List<StandardMetadata>>(
                  stream: StandardsService().getTopStandards(limit: 50),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Erro ao carregar destaques', style: TextStyle(color: AppColors.error)));
                    }
                    final data = snapshot.data ?? [];
                    final filtered = data.where((s) {
                      if (_selectedFilter != 'Todos') {
                        final t = _selectedFilter.replaceAll('s', ''); // NR, TC, TP
                        if (!s.code.startsWith(t)) return false;
                      }
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        if (!s.code.toLowerCase().contains(q) &&
                            !s.description.toLowerCase().contains(q)) {
                          return false;
                        }
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.search_off, color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text('Nenhum módulo encontrado', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15)),
                        ]),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _cardFromMetadata(ctx, filtered[i], isTestMode),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardFromMetadata(BuildContext context, StandardMetadata s, bool isTestMode) {
    // Para simplificar, assumimos progresso 0 se não estiver carregado o progresso do usuário aqui,
    // já que o foco é listar destaques. Poderia ser integrado com userProgressProvider se desejado.
    final hexString = s.colorHex.replaceAll('#', '');
    final colorInt = int.parse(hexString.length == 6 ? 'FF$hexString' : hexString, radix: 16);
    final Color color = Color(colorInt);
    final bool locked = !isTestMode; // Podemos deixar destrancado apenas para teste ou baseado no user
    return GestureDetector(
      onTap: () {
        StandardsService().incrementClick(s.id);
        context.push('/standard-detail', extra: {'standardId': s.id});
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.menu_book, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.code, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(s.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 2),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
              child: Text(locked ? 'BLOQUEADO' : 'ACESSAR', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}