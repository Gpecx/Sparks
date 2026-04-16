import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

class TestHistoryScreen extends StatefulWidget {
  const TestHistoryScreen({super.key});

  @override
  State<TestHistoryScreen> createState() => _TestHistoryScreenState();
}

class _TestHistoryScreenState extends State<TestHistoryScreen> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            title: const Text('HISTÓRICO DE TESTES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5)),
          ),
          body: Column(
            children: [
              const SizedBox(height: 8),
              if (_uid != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(_uid).collection('quiz_history').snapshots(),
                  builder: (context, snapshot) {
                    int total = 0;
                    double media = 0.0;
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      total = snapshot.data!.docs.length;
                      double s = 0.0;
                      for (var doc in snapshot.data!.docs) {
                        s += (doc.data() as Map<String, dynamic>)['score'] as double? ?? 0.0;
                      }
                      media = (s / total) * 100;
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _summaryChip('$total', 'Testes', Icons.quiz_outlined),
                          const SizedBox(width: 10),
                          _summaryChip('${media.toStringAsFixed(0)}%', 'Média', Icons.gps_fixed),
                          const SizedBox(width: 10),
                          _summaryChip('-', 'Normas', Icons.menu_book_outlined),
                        ],
                      ),
                    );
                  }
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar testes...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4))),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _uid == null 
                  ? const Center(child: Text("Faça login para ver seu histórico.", style: TextStyle(color: Colors.white)))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(_uid).collection('quiz_history').orderBy('timestamp', descending: true).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("Nenhum histórico encontrado.", style: TextStyle(color: AppColors.textMuted)));
                        }
                        
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (ctx, i) {
                            final data = snapshot.data!.docs[i].data() as Map<String, dynamic>;
                            final score = data['score'] as double? ?? 0.0;
                            final moduleId = data['moduleId'] as String? ?? 'Desconhecido';
                            final ts = data['timestamp'] as Timestamp?;
                            final dateStr = ts != null ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : 'Data Desconhecida';
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _histCard('Módulo: $moduleId', dateStr, score, Icons.text_snippet_outlined, score >= 0.7),
                            );
                          },
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

  Widget _summaryChip(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 15),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w800)),
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _histCard(String title, String date, double score, IconData icon, bool passed) {
    final pct = (score * 100).toInt();
    final color = passed ? AppColors.primary : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 2),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$pct%', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(passed ? 'APROVADO' : 'REVISAR', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}