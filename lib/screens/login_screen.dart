import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/animated_spark_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

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
        title: const Text(
          'Entrar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const AnimatedSparkLogo(),
            const SizedBox(height: 24),
            // Linha verde EXS
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Bem-vindo de volta', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Faça login no SPARK para continuar', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
            const SizedBox(height: 36),
            _fieldLabel('Endereço de E-mail'),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Digite seu e-mail',
                prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 20),
            _fieldLabel('Senha'),
            const SizedBox(height: 8),
            TextField(
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Digite sua senha',
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                child: const Text('Esqueceu a senha?', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
                child: const Text('ENTRAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 20),
            // Linha divisória com texto
            Row(children: [
              Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.4))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
              ),
              Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.4))),
            ]),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Não tem uma conta? ', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('Cadastre-se', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)),
  );
}
