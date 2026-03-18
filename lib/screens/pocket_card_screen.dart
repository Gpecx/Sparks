import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

class PocketCardScreen extends StatefulWidget {
  const PocketCardScreen({super.key});

  @override
  State<PocketCardScreen> createState() => _PocketCardScreenState();
}

class _PocketCardScreenState extends State<PocketCardScreen> {
  // Variáveis para guardar a inclinação do cartão
  double _xRotation = 0.0;
  double _yRotation = 0.0;

  // Função que atualiza a rotação quando o dedo arrasta na tela
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // O delta é o quanto o dedo se moveu.
      // Multiplicamos por um valor pequeno (0.01) para a rotação não ficar maluca.
      _xRotation -= details.delta.dy * 0.01;
      _yRotation += details.delta.dx * 0.01;

      // Limitamos a inclinação máxima para o cartão não virar de cabeça para baixo
      _xRotation = _xRotation.clamp(-0.5, 0.5);
      _yRotation = _yRotation.clamp(-0.5, 0.5);
    });
  }

  // Função que faz o cartão voltar para o centro quando o usuário solta o dedo
  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _xRotation = 0.0;
      _yRotation = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent, // Transparente para ver o fundo
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'CREDENCIAL DIGITAL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
            centerTitle: true,
          ),
          // O GestureDetector é o nosso "espião" que detecta os toques
          body: GestureDetector(
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              color: Colors.transparent, // Necessário para capturar toques na tela toda
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              // AnimatedContainer faz o cartão voltar pro meio suavemente quando soltamos
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transformAlignment: Alignment.center,
                // AQUI É A MÁGICA DO 3D!
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Adiciona a perspectiva (profundidade)
                  ..rotateX(_xRotation)   // Inclina pra cima/baixo
                  ..rotateY(_yRotation),  // Inclina pros lados
                child: _buildCardUI(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Desenhando o visual do cartão
  Widget _buildCardUI() {
    return Container(
      width: 320,
      height: 500,
      decoration: BoxDecoration(
        // Fundo com degradê escuro
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2641), Color(0xFF061629)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.6),
          width: 2,
        ),
        // Brilho verde ao redor do cartão (Glow)
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Efeito de marca d'água (molécula gigante no fundo)
          Positioned(
            right: -50,
            bottom: -50,
            child: Opacity(
              opacity: 0.05,
              child: Icon(
                Icons.hub,
                size: 250,
                color: AppColors.primary,
              ),
            ),
          ),
          
          // Conteúdo do Cartão
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho do Cartão
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SPARK.ID',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    Icon(
                      Icons.verified_user,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Foto / Avatar
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                      color: AppColors.inputBackground,
                    ),
                    child: const Icon(Icons.person, size: 60, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Informações do Usuário
                const Center(
                  child: Text(
                    'ALEX RODRIGUEZ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'TÉCNICO LÍDER • LVL 12',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Selos / Normas Validadas
                const Text(
                  'CERTIFICAÇÕES ATIVAS',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildBadge('NR-10'),
                    const SizedBox(width: 8),
                    _buildBadge('NR-35'),
                    const SizedBox(width: 8),
                    _buildBadge('NFPA 70E'),
                  ],
                ),
                const Spacer(),
                
                // Código de barras / QR falso para dar um ar realista
                Center(
                  child: Container(
                    height: 40,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        30,
                        (index) => Container(
                          width: math.Random().nextDouble() * 4 + 1,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'VÁLIDO ATÉ: 12/2026',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mini Widget para os selos
  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}