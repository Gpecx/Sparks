import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/animated_spark_logo.dart';
import 'package:spark_app/services/auth_service.dart';
import 'package:spark_app/services/device_service.dart';
import 'package:spark_app/widgets/email_verification_dialog.dart';
import 'package:spark_app/widgets/google_auth_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.prefillEmail, this.prefillPassword});

  final String? prefillEmail;
  final String? prefillPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null) {
      _emailController.text = widget.prefillEmail!;
    }
    if (widget.prefillPassword != null) {
      _passwordController.text = widget.prefillPassword!;
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.signInWithEmail(email, password);
      final user = credential.user;
      if (!mounted || user == null) return;

      // ── Verificação de dispositivo ──────────────────────────────
      final deviceService = DeviceService();
      final deviceId = await deviceService.getDeviceId();
      final isTrusted = await _authService.checkDeviceVerification(user.uid, deviceId);

      if (!mounted) return;

      if (!isTrusted) {
        // Mantém o usuário LOGADO para que as Cloud Functions tenham o uid.
        // Envia o código OTP para o e-mail do usuário
        try {
          final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
          await fn.httpsCallable('sendEmailVerificationCode').call({'email': email});
        } catch (e) {
          // Falhou ao enviar — desloga e mostra erro
          await _authService.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao enviar código: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        if (!mounted) return;

        // Exibe o popup de verificação (usuário ainda logado)
        final verified = await showEmailVerificationDialog(
          context,
          email: email,
          uid: user.uid,
        );

        if (!mounted) return;
        if (!verified) {
          // Usuário cancelou a verificação — desloga por segurança
          await _authService.signOut();
          return;
        }
        // Código OTP confirmado, dispositivo registrado como confiável.
        // O usuário já está logado — segue direto para /home.
      }

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _authService.signInWithGoogle();
      final user = credential.user;
      if (!mounted || user == null) return;

      // O Google já verifica a identidade do usuário, então pulamos a
      // verificação de dispositivo por OTP e vamos direto para a home.
      if (mounted) context.go('/home');
    } on GoogleSignInCancelled {
      // Usuário fechou o popup — não é erro, ignora silenciosamente.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
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
              controller: _passwordController,
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
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Esqueceu a senha?', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('ENTRAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
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
            GoogleAuthButton(
              label: 'Entrar com Google',
              isLoading: _isGoogleLoading,
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Não tem uma conta? ', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                GestureDetector(
                  onTap: () => context.push('/register'),
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
