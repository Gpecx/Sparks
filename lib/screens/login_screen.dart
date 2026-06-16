import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/animated_spark_logo.dart';
import 'package:spark_app/services/auth_service.dart';
import 'package:spark_app/services/device_service.dart';
import 'package:spark_app/widgets/email_verification_dialog.dart';
import 'package:spark_app/widgets/google_auth_button.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/l10n/app_localizations.dart';

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
  bool _rememberDevice = false;

  static const _devEmail = String.fromEnvironment('SPARK_DEV_EMAIL');
  static const _devPassword = String.fromEnvironment('SPARK_DEV_PASSWORD');
  static const _devAutoLogin = bool.fromEnvironment('SPARK_DEV_AUTOLOGIN', defaultValue: false);

  @override
  void initState() {
    super.initState();

    // Prefill explícito (ex: vindo do cadastro) tem prioridade.
    if (widget.prefillEmail != null) {
      _emailController.text = widget.prefillEmail!;
    }
    if (widget.prefillPassword != null) {
      _passwordController.text = widget.prefillPassword!;
    }

    // Autofill de dev: só em debug, e só se o campo ainda estiver vazio.
    if (kDebugMode && _devEmail.isNotEmpty && _devPassword.isNotEmpty) {
      if (_emailController.text.isEmpty) _emailController.text = _devEmail;
      if (_passwordController.text.isEmpty) _passwordController.text = _devPassword;
      if (_devAutoLogin) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleLogin());
      }
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      SparkSnack.info(context, AppLocalizations.of(context)!.fillAllFields);
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
          SparkSnack.error(context, AppLocalizations.of(context)!.errorSendingCode(e.toString().replaceAll('Exception: ', '')));
          return;
        }

        if (!mounted) return;

        // Exibe o popup de verificação (usuário ainda logado)
        final verified = await showEmailVerificationDialog(
          context,
          email: email,
          uid: user.uid,
          rememberDevice: _rememberDevice,
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
      if (mounted) SparkSnack.error(context, e);
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
      if (mounted) SparkSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.loginTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1),
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
            Text(l10n.loginWelcomeBack, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(l10n.loginSubtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 36),
            _fieldLabel(l10n.emailAddressLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.emailHint,
                prefixIcon: const Icon(Icons.mail_outline, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 20),
            _fieldLabel(l10n.passwordLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.passwordHint,
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Checkbox "Lembrar este dispositivo"
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberDevice,
                    onChanged: (v) => setState(() => _rememberDevice = v ?? false),
                    activeColor: AppColors.primary,
                    checkColor: Colors.black,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() => _rememberDevice = !_rememberDevice),
                  child: Text(
                    l10n.rememberDevice30Days,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: Text(l10n.forgotPassword, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
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
                    : Text(l10n.loginButton, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 20),
            // Linha divisória com texto
            Row(children: [
              Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.4))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l10n.orDivider, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
              Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.4))),
            ]),
            const SizedBox(height: 20),
            GoogleAuthButton(
              label: l10n.signInWithGoogle,
              isLoading: _isGoogleLoading,
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.noAccountQuestion, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                GestureDetector(
                  onTap: () => context.push('/register'),
                  child: Text(l10n.signUpLink, style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
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
