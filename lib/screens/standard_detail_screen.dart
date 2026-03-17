import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';

class StandardDetailScreen extends StatelessWidget {
  const StandardDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.card, borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.play_arrow, color: AppColors.primary, size: 14),
                        SizedBox(width: 4),
                        Text('POWERPLAY', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Hero icon EXS
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.card,
                        border: Border.all(color: AppColors.primary, width: 2.5),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 6),
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 60, spreadRadius: 20),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow, color: AppColors.primary, size: 46),
                    ),
                    const SizedBox(height: 24),
                    // Linha decorativa
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    const Text(
                      'POWERPLAY',
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 3),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'O Netflix da Engenharia Elétrica',
                      style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Acesse centenas de aulas, estudos de caso e conteúdos exclusivos sobre normas técnicas e engenharia — tudo num só lugar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Features chips
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _featureChip(Icons.videocam_outlined, 'Vídeo Aulas'),
                          const SizedBox(width: 10),
                          _featureChip(Icons.cases_outlined, 'Casos Reais'),
                          const SizedBox(width: 10),
                          _featureChip(Icons.offline_bolt_outlined, 'Offline'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Hot Now section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                            child: const Text('EM ALTA', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                          const SizedBox(width: 10),
                          const Text('Recomendados para você', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 195,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _videoCard('NR-10: Painéis Elétricos Industriais Avançados', '12:45', true),
                          const SizedBox(width: 12),
                          _videoCard('Estudo de Caso: Inspeção em Alta Tensão', '8:30', false),
                          const SizedBox(width: 12),
                          _videoCard('NR-35: Equipamentos de Proteção Individual', '15:20', false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // CTA Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {},
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('ACESSAR POWERPLAY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2)),
                              SizedBox(width: 10),
                              Icon(Icons.open_in_new, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Talvez mais tarde', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _videoCard(String title, String duration, bool isNew) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Stack(
            children: [
              Container(
                height: 130, width: 240,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                  gradient: LinearGradient(
                    colors: [AppColors.greenDark.withValues(alpha: 0.6), AppColors.background],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.15), border: Border.all(color: AppColors.primary, width: 2)),
                    child: const Icon(Icons.play_arrow, color: AppColors.primary, size: 26),
                  ),
                ),
              ),
              if (isNew)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(5)),
                    child: const Text('NOVO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ),
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: Text(duration, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
