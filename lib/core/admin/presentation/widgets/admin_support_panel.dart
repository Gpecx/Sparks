import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/app_theme.dart';

class AdminSupportPanel extends StatefulWidget {
  const AdminSupportPanel({super.key});

  @override
  State<AdminSupportPanel> createState() => _AdminSupportPanelState();
}

class _AdminSupportPanelState extends State<AdminSupportPanel> {
  String _selectedCategory = 'Todas';
  
  final List<String> _categories = [
    'Todas',
    'Dúvida geral',
    'Problema técnico',
    'Sugestão de melhoria',
    'Erro em conteúdo',
    'Problema com conta',
    'Outro',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caixa de Entrada de Suporte',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Visualize e gerencie os tickets de suporte criados pelos usuários.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        
        // Filtro de Categorias
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = category);
                    }
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              
              final docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma mensagem encontrada.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  return _buildTicketCard(data, docId);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Query _buildQuery() {
    Query query = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    ).collection('support_tickets').orderBy('createdAt', descending: true);
    
    if (_selectedCategory != 'Todas') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    
    return query;
  }

  Widget _buildTicketCard(Map<String, dynamic> data, String docId) {
    final subject = data['subject'] ?? 'Sem assunto';
    final message = data['message'] ?? 'Sem mensagem';
    final email = data['email'] ?? 'E-mail não informado';
    final name = data['displayName'] ?? 'Usuário anônimo';
    final category = data['category'] ?? 'Desconhecido';
    final status = data['status'] ?? 'open';
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
    
    String dateStr = 'Data desconhecida';
    if (createdAt != null) {
      dateStr = DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate());
    }

    Color statusColor = status == 'open' ? AppColors.orange : AppColors.greenBright;
    String statusText = status == 'open' ? 'Aberto' : 'Resolvido';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      email,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 16),
              if (status == 'open')
                ElevatedButton(
                  onPressed: () => _markAsResolved(docId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenBright,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Resolver', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markAsResolved(String docId) async {
    try {
      await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      ).collection('support_tickets').doc(docId).update({
        'status': 'resolved',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
