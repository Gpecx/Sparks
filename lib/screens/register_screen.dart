import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/screens/animated_spark_logo.dart';
import 'package:spark_app/screens/welcome_screen.dart';
import 'package:spark_app/services/auth_service.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/services/access_code_service.dart';
import 'package:spark_app/widgets/email_verification_dialog.dart';
import 'package:spark_app/widgets/google_auth_button.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/widgets/responsive_form_container.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _voucherController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      SparkSnack.info(context, AppLocalizations.of(context)!.fillAllFields);
      return;
    }

    try {
      setState(() => _isLoading = true);

      WelcomeScreen.skipAutoLogin = true;
      UserService().stopListening(); // Cancela listeners ativos

      // 1. Cria a conta no Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );

      final user = credential.user;
      if (user == null) throw Exception(AppLocalizations.of(context)!.registerUnknownError);

      // 2. Atualiza o nome do usuário com try/catch e timeout
      try {
        await user.updateDisplayName(name).timeout(const Duration(seconds: 1));
        await user.reload().timeout(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('Aviso: updateDisplayName demorou ou falhou: $e');
      }

      // 3. Cria o documento no Firestore com Timeout e Try/Catch isolado
      // Se houver instabilidade ou timeout no Firestore, não travamos o usuário.
      // A conta Auth já existe e o AuthService a curará no próximo login.
      try {
        await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('users').doc(user.uid).set({
          'uid': user.uid,
          'displayName': name,
          'email': email,
          'photoUrl': null,
          'role': 'técnico',
          'xp': 0,
          'level': 1,
          'tensionLevel': 'BT',
          'currentStreak': 0,
          'longestStreak': 0,
          'activeDays': 0,
          'studiedToday': false,
          'lastStudyDate': null,
          'weeklyXp': 0,
          'monthlyXp': 0,
          'unlockedBadgeIds': [],
          'clanId': null,
          'clanName': null,
          'totalLessonsCompleted': 0,
          'totalCorrectAnswers': 0,
          'totalAnswers': 0,
          'eloRating': 1200,
          'wins': 0,
          'losses': 0,
          'totalDuels': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 3));
      } catch (firestoreError) {
        debugPrint('Firestore Timeout/Error ignorado no cadastro: $firestoreError');
      }

      // 3b. Código de cortesia (opcional): resgata agora, com o usuário ainda
      // autenticado, liberando o acesso total antes mesmo de ir para o login.
      final voucher = _voucherController.text.trim().toUpperCase();
      DateTime? voucherUntil;
      String? voucherError;
      if (voucher.isNotEmpty) {
        try {
          voucherUntil = await AccessCodeService.instance.redeem(voucher);
        } on AccessCodeException catch (e) {
          voucherError = e.message;
        } catch (_) {
          voucherError = AppLocalizations.of(context)!.voucherActivateLater;
        }
      }

      if (!mounted) return;

      // Feedback do voucher antes de seguir para a verificação de e-mail.
      if (voucherUntil != null) {
        final d =
            '${voucherUntil.day.toString().padLeft(2, '0')}/${voucherUntil.month.toString().padLeft(2, '0')}/${voucherUntil.year}';
        await _showInfoDialog(
          AppLocalizations.of(context)!.fullAccessGranted,
          AppLocalizations.of(context)!.fullAccessUntilMessage(d),
        );
      } else if (voucherError != null) {
        await _showInfoDialog(
          AppLocalizations.of(context)!.codeNotApplied,
          AppLocalizations.of(context)!.codeNotAppliedMessage(voucherError),
        );
      }

      if (!mounted) return;

      // 4. Envia código OTP (primeiro cadastro sempre verifica)
      try {
        final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
        await fn.httpsCallable('sendEmailVerificationCode').call({'email': email});
      } catch (e) {
        debugPrint('Aviso: falha ao enviar OTP pós-cadastro: $e');
        // Não bloqueia o fluxo — o usuário poderá reenviar no popup
      }

      if (!mounted) return;

      // 5. Exibe popup OTP — usuário deve verificar antes de ir para o login
      final verified = await showEmailVerificationDialog(
        context,
        email: email,
        uid: user.uid,
      );

      if (!mounted) return;

      // Após verificação (ou se fechou), navega para login com prefill
      final router = GoRouter.of(context);
      final registeredEmail = email;
      final registeredPassword = password;
      WelcomeScreen.skipAutoLogin = false;
      await FirebaseAuth.instance.signOut();
      UserService().stopListening();

      if (verified) {
        router.go('/login', extra: {
          'email': registeredEmail,
          'password': registeredPassword,
        });
      } else {
        // Cancelou verificação — vai para login sem prefill
        router.go('/login');
      }

    } catch (e) {
      WelcomeScreen.skipAutoLogin = false;
      if (!mounted) return;
      SparkSnack.error(context, AppLocalizations.of(context)!.genericErrorPrefix(e.toString().replaceAll('Exception: ', '')));
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

      // O Google já verifica a identidade do usuário, então vamos direto
      // para a home (sem o fluxo de OTP do cadastro por e-mail/senha).
      if (mounted) context.go('/home');
    } on GoogleSignInCancelled {
      // Usuário fechou o popup — não é erro, ignora silenciosamente.
    } catch (e) {
      if (!mounted) return;
      SparkSnack.error(context, e);
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
        title: Text(l10n.createAccountTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ResponsiveFormContainer(
          child: Column(
          children: [
            const SizedBox(height: 16),
            const AnimatedSparkLogo(),
            const SizedBox(height: 24),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(l10n.createYourAccount, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(l10n.registerSubtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),
            _fieldLabel(l10n.fullNameLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 50,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: l10n.fullNameHint, prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMuted), counterText: ''),
            ),
            const SizedBox(height: 20),
            _fieldLabel(l10n.emailAddressLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              maxLength: 100,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: l10n.emailHint, prefixIcon: const Icon(Icons.mail_outline, color: AppColors.textMuted), counterText: ''),
            ),
            const SizedBox(height: 20),
            _fieldLabel(l10n.passwordLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              maxLength: 128,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.createPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                counterText: '',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _fieldLabel(l10n.courtesyCodeOptional),
            const SizedBox(height: 8),
            TextField(
              controller: _voucherController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 20,
              style: const TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'PROF-XXXX-XXXX',
                prefixIcon: Icon(Icons.card_giftcard_outlined, color: AppColors.textMuted),
                counterText: '',
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.courtesyCodeHelp,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12, height: 1.4),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isLoading || _isGoogleLoading) ? null : _handleRegister,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(l10n.registerButton, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
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
              label: l10n.signUpWithGoogle,
              isLoading: _isGoogleLoading,
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.alreadyHaveAccount, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                GestureDetector(
                  onTap: () => context.push('/login'),
                  child: Text(l10n.loginTitle, style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _showInfoDialog(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)),
  );
}
