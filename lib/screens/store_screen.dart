import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/checkout_screen.dart';
import 'package:spark_app/screens/main_shell_screen.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void add(CartItem item) {
    state = [...state, item];
  }

  void clear() {
    state = [];
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

class SparkPackage {
  final int points;
  final double price;
  final String? badge;
  const SparkPackage({required this.points, required this.price, this.badge});
}

const List<SparkPackage> sparkPackages = [
  SparkPackage(points: 100, price: 4.99),
  SparkPackage(points: 300, price: 12.99, badge: 'Popular'),
  SparkPackage(points: 500, price: 19.99),
  SparkPackage(points: 1000, price: 34.99, badge: 'Melhor Valor'),
  SparkPackage(points: 2500, price: 79.99),
];

const int promoPoints = 500;
const double promoOriginalPrice = 19.99;
const double promoDiscountPrice = 9.99;

class SubscriptionPlan {
  final String name;
  final double monthlyPrice;
  final int bonusPoints;
  final String period;
  final String? badge;
  const SubscriptionPlan({required this.name, required this.monthlyPrice, required this.bonusPoints, required this.period, this.badge});
}

const List<SubscriptionPlan> subscriptionPlans = [
  SubscriptionPlan(name: 'Mensal', monthlyPrice: 29.90, bonusPoints: 200, period: '/mês'),
  SubscriptionPlan(name: 'Trimestral', monthlyPrice: 24.90, bonusPoints: 350, period: '/mês', badge: 'Economize 17%'),
  SubscriptionPlan(name: 'Semestral', monthlyPrice: 19.90, bonusPoints: 500, period: '/mês', badge: 'Mais Popular'),
  SubscriptionPlan(name: 'Anual', monthlyPrice: 14.90, bonusPoints: 800, period: '/mês', badge: 'Melhor Oferta'),
];

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  void _addToCart(BuildContext context, WidgetRef ref, CartItem item) {
    ref.read(cartProvider.notifier).add(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} adicionado!'), backgroundColor: AppColors.primary, duration: const Duration(seconds: 1)),
    );
  }

  void _openCheckout(BuildContext context, WidgetRef ref, List<CartItem> cart) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(items: List.from(cart)))).then((_) {
      ref.read(cartProvider.notifier).clear();
    });
  }

  // === BOTÃO VOLTAR INTELIGENTE ===
  Widget _buildSmartBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          final shell = context.findAncestorStateOfType<MainShellScreenState>();
          shell?.switchTab(0);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent, 
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 20, 0),
                  child: Row(
                    children: [
                      _buildSmartBackButton(context), 
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LOJA SPARK', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
                            SizedBox(height: 2),
                            Text('Potencialize seu aprendizado', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      // Carrinho
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                        onTap: cart.isEmpty ? null : () => _openCheckout(context, ref, cart),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cart.isNotEmpty ? AppColors.primary.withValues(alpha: 0.5) : AppColors.cardBorder.withValues(alpha: 0.4)),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.shopping_cart_outlined, color: cart.isNotEmpty ? AppColors.primary : AppColors.textMuted, size: 22),
                              if (cart.isNotEmpty)
                                Positioned(
                                  top: -6, right: -6,
                                  child: Container(
                                    width: 17, height: 17,
                                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                    child: Center(child: Text('${cart.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Promo card
                        _promoCard(context, ref),
                        const SizedBox(height: 28),
                        _sectionTitle('PACOTES DE PONTOS', Icons.bolt),
                        const SizedBox(height: 12),
                        ...sparkPackages.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _packageCard(context, ref, p))),
                        const SizedBox(height: 16),
                        _sectionTitle('PLANOS DE ASSINATURA', Icons.card_membership_outlined),
                        const SizedBox(height: 4),
                        Text('Ganhe pontos bônus todo mês automaticamente!', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                        const SizedBox(height: 12),
                        ...subscriptionPlans.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _planCard(context, ref, p))),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Text(t, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _promoCard(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: [Color(0xFF0D3B1A), Color(0xFF061629)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                child: const Text('OFERTA DO DIA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const Spacer(),
              const Icon(Icons.timer_outlined, color: AppColors.primary, size: 16),
              const SizedBox(width: 4),
              Text('Expira em breve', style: TextStyle(color: AppColors.primary.withValues(alpha: 0.7), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('⚡ Oferta Relâmpago do Dia!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Economize 50% neste pacote exclusivo', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              const Text('500 Pontos Spark', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('R\$ ${promoOriginalPrice.toStringAsFixed(2)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13, decoration: TextDecoration.lineThrough, decorationColor: Colors.white38)),
              const SizedBox(width: 8),
              Text('R\$ ${promoDiscountPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 46,
            child: ElevatedButton(
              onPressed: () => _addToCart(context, ref, CartItem(name: '500 Pontos Spark (Promo)', description: 'Oferta Relâmpago', price: promoDiscountPrice, icon: Icons.bolt)),
              child: const Text('APROVEITAR AGORA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _packageCard(BuildContext context, WidgetRef ref, SparkPackage pkg) {
    final hasBadge = pkg.badge != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: () => _addToCart(context, ref, CartItem(name: '${pkg.points} Pontos Spark', description: 'Pacote avulso', price: pkg.price, icon: Icons.bolt)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasBadge ? AppColors.primary.withValues(alpha: 0.4) : AppColors.cardBorder.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.bolt, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('${pkg.points} pts', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    if (hasBadge) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                        child: Text(pkg.badge!, style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ],
                  ]),
                  Text('R\$ ${(pkg.price / pkg.points * 100).toStringAsFixed(1)} por 100 pts', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('R\$ ${pkg.price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
                const Icon(Icons.add_shopping_cart, color: AppColors.textMuted, size: 16),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _planCard(BuildContext context, WidgetRef ref, SubscriptionPlan plan) {
    final isBest = plan.badge == 'Melhor Oferta';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: () => _addToCart(context, ref, CartItem(name: 'Plano ${plan.name}', description: '+${plan.bonusPoints} pts bônus/mês', price: plan.monthlyPrice, icon: isBest ? Icons.workspace_premium : Icons.card_membership)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isBest ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isBest ? AppColors.primary.withValues(alpha: 0.5) : AppColors.cardBorder.withValues(alpha: 0.3), width: isBest ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: isBest ? 0.18 : 0.10), borderRadius: BorderRadius.circular(10)),
              child: Icon(isBest ? Icons.workspace_premium : Icons.card_membership_outlined, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(plan.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    if (plan.badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                        child: Text(plan.badge!, style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ],
                  ]),
                  Row(children: [
                    const Icon(Icons.bolt, color: AppColors.primary, size: 13),
                    const SizedBox(width: 3),
                    Text('+${plan.bonusPoints} pts/mês', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('R\$ ${plan.monthlyPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w800)),
                Text(plan.period, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}