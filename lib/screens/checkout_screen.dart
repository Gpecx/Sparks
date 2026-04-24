import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

class CartItem {
  final String name;
  final String description;
  final double price;
  final IconData icon;
  /// Spark Points concedidos ao comprar este item (0 = nenhum)
  final int sparkPointsGranted;
  const CartItem({
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
    this.sparkPointsGranted = 0,
  });
}

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  const CheckoutScreen({super.key, required this.items});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;

  double get _total => widget.items.fold<double>(0, (s, i) => s + i.price);
  int get _totalPoints => widget.items.fold<int>(0, (s, i) => s + i.sparkPointsGranted);

  Future<void> _finalizePurchase() async {
    setState(() => _isProcessing = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Usuário não autenticado');

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1) Registrar transação na coleção 'transactions'
      final txRef = db.collection('transactions').doc();
      batch.set(txRef, {
        'uid': uid,
        'items': widget.items
            .map((i) => {
                  'name': i.name,
                  'description': i.description,
                  'price': i.price,
                  'sparkPointsGranted': i.sparkPointsGranted,
                })
            .toList(),
        'totalPrice': _total,
        'totalPoints': _totalPoints,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2) Incrementar Spark Points no documento do usuário
      if (_totalPoints > 0) {
        final userRef = db.collection('users').doc(uid);
        batch.update(userRef, {
          'sparkPoints': FieldValue.increment(_totalPoints),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_totalPoints > 0
              ? 'Compra realizada! $_totalPoints Pontos Spark adicionados à sua conta 🎉'
              : 'Compra realizada com sucesso! 🎉'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar compra: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
            ),
            title: const Text(
              'CHECKOUT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: widget.items.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.shopping_cart_outlined, color: AppColors.primary.withValues(alpha: 0.2), size: 100),
                          const SizedBox(height: 16),
                          const Text('Seu carrinho está vazio', style: TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(
                            'Explore a loja e equipe-se\npara os próximos desafios!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.storefront, size: 18, color: AppColors.primary),
                            label: const Text('VOLTAR À LOJA', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 1)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.15), elevation: 0),
                          ),
                        ]),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: widget.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(item.icon, color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                      Text(item.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                      if (item.sparkPointsGranted > 0)
                                        Row(children: [
                                          const Icon(Icons.bolt, color: AppColors.primary, size: 12),
                                          Text(
                                            ' +${item.sparkPointsGranted} pts',
                                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ]),
                                    ],
                                  ),
                                ),
                                Text(
                                  'R\$ ${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (widget.items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border(top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.items.length} ${widget.items.length == 1 ? 'item' : 'itens'}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                          Row(children: [
                            const Text('TOTAL ', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            Text('R\$ ${_total.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800)),
                          ]),
                        ],
                      ),
                      if (_totalPoints > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(Icons.bolt, color: AppColors.gold, size: 14),
                              Text(
                                ' +$_totalPoints Pontos Spark no total',
                                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),
                      Container(height: 1, color: AppColors.primary.withValues(alpha: 0.2)),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _finalizePurchase,
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Text(
                                  'FINALIZAR COMPRA',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 12),
                          const SizedBox(width: 4),
                          Text('Pagamento seguro', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}