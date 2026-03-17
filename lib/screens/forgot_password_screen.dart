import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/animated_spark_logo.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Recuperar Senha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const AnimatedSparkLogo(),
            const SizedBox(height: 32),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Recuperar Acesso', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'Insira seu e-mail para receber as instruções de redefinição',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 36),
            // Info box EXS style
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Um link de redefinição será enviado para o seu e-mail cadastrado.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Endereço de E-mail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 8),
            const TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Digite seu e-mail', prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted)),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Instruções enviadas para seu e-mail!'), backgroundColor: AppColors.primary),
                  );
                },
                child: const Text('ENVIAR INSTRUÇÕES', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('← Voltar para o Login', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
