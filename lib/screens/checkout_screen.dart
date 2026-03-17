import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';

class CartItem {
  final String name;
  final String description;
  final double price;
  final IconData icon;
  const CartItem({required this.name, required this.description, required this.price, required this.icon});
}

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  const CheckoutScreen({super.key, required this.items});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  @override
  Widget build(BuildContext context) {
    final total = widget.items.fold<double>(0, (s, i) => s + i.price);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('CHECKOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5)),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.items.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle, border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3))),
                        child: const Icon(Icons.shopping_cart_outlined, color: AppColors.textMuted, size: 38),
                      ),
                      const SizedBox(height: 16),
                      const Text('Carrinho vazio', style: TextStyle(color: AppColors.textSecondary, fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Adicione itens na loja', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
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
                          color: AppColors.card, borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
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
                                ],
                              ),
                            ),
                            Text('R\$ ${item.price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => setState(() => widget.items.removeAt(index)),
                              child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
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
                  // Resumo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${widget.items.length} ${widget.items.length == 1 ? 'item' : 'itens'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      Row(children: [
                        const Text('TOTAL ', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Linha verde divisora EXS style
                  Container(height: 1, color: AppColors.primary.withValues(alpha: 0.2)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Compra realizada com sucesso! 🎉'), backgroundColor: AppColors.primary),
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('FINALIZAR COMPRA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2)),
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
    );
  }
}
