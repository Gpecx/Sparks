import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/animated_spark_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
        title: const Text('Criar Conta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const AnimatedSparkLogo(),
            const SizedBox(height: 24),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Crie sua conta', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Cadastre-se no SPARK para começar', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
            const SizedBox(height: 32),
            _fieldLabel('Nome Completo'),
            const SizedBox(height: 8),
            const TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Digite seu nome completo', prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted)),
            ),
            const SizedBox(height: 20),
            _fieldLabel('Endereço de E-mail'),
            const SizedBox(height: 8),
            const TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Digite seu e-mail', prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted)),
            ),
            const SizedBox(height: 20),
            _fieldLabel('Senha'),
            const SizedBox(height: 8),
            TextField(
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Crie uma senha',
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Checkbox termos
            Row(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Concordo com os ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      children: const [
                        TextSpan(text: 'Termos de Uso', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                        TextSpan(text: ' e '),
                        TextSpan(text: 'Política de Privacidade', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
                child: const Text('CADASTRAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Já possui uma conta? ', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Entrar', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
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
