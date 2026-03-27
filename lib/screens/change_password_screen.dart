import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  // Validação de força da senha
  bool get _hasMinLength => _newPassCtrl.text.length >= 8;
  bool get _hasUppercase => _newPassCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _newPassCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _newPassCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar => _newPassCtrl.text.contains(RegExp(r'[!@#\$%\^&\*\(\)_\+\-=\[\]\{\};:,\.<>\?]'));
  bool get _passwordsMatch =>
      _newPassCtrl.text.isNotEmpty &&
      _confirmPassCtrl.text.isNotEmpty &&
      _newPassCtrl.text == _confirmPassCtrl.text;

  int get _strengthScore {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasNumber) score++;
    if (_hasSpecialChar) score++;
    return score;
  }

  String get _strengthLabel {
    switch (_strengthScore) {
      case 0:
      case 1:
        return 'Muito fraca';
      case 2:
        return 'Fraca';
      case 3:
        return 'Razoável';
      case 4:
        return 'Forte';
      case 5:
        return 'Muito forte';
      default:
        return '';
    }
  }

  Color get _strengthColor {
    switch (_strengthScore) {
      case 0:
      case 1:
        return AppColors.error;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return AppColors.primaryLight;
      case 5:
        return const Color(0xFF00E676);
      default:
        return AppColors.textMuted;
    }
  }

  void _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_passwordsMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('As senhas não coincidem.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_strengthScore < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A senha precisa ser pelo menos razoável.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    // Simula chamada ao backend
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _saving = false);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.primaryLight, width: 1),
        ),
        icon: const Icon(Icons.check_circle, color: AppColors.primaryLight, size: 48),
        title: const Text(
          'Senha alterada!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Sua senha foi atualizada com sucesso. Use a nova senha no próximo login.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'CONTINUAR',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
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
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'ALTERAR SENHA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ícone de segurança
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.3),
                            AppColors.accent.withValues(alpha: 0.2),
                          ],
                        ),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 36),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Altere sua senha de acesso',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Aviso de segurança
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary.withValues(alpha: 0.7), size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Por segurança, informe sua senha atual antes de definir uma nova.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Campo: Senha Atual
                  _buildPasswordField(
                    label: 'Senha Atual',
                    controller: _currentPassCtrl,
                    showPassword: _showCurrent,
                    onToggle: () => setState(() => _showCurrent = !_showCurrent),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe sua senha atual';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo: Nova Senha
                  _buildPasswordField(
                    label: 'Nova Senha',
                    controller: _newPassCtrl,
                    showPassword: _showNew,
                    onToggle: () => setState(() => _showNew = !_showNew),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe a nova senha';
                      if (v.length < 8) return 'Mínimo de 8 caracteres';
                      return null;
                    },
                  ),

                  // Indicador de força da senha
                  if (_newPassCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildStrengthIndicator(),
                    const SizedBox(height: 10),
                    _buildRequirementsList(),
                  ],
                  const SizedBox(height: 20),

                  // Campo: Confirmar Nova Senha
                  _buildPasswordField(
                    label: 'Confirmar Nova Senha',
                    controller: _confirmPassCtrl,
                    showPassword: _showConfirm,
                    onToggle: () => setState(() => _showConfirm = !_showConfirm),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirme a nova senha';
                      if (v != _newPassCtrl.text) return 'As senhas não coincidem';
                      return null;
                    },
                  ),

                  // Feedback de confirmação
                  if (_confirmPassCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _passwordsMatch ? Icons.check_circle : Icons.cancel,
                          color: _passwordsMatch ? AppColors.primaryLight : AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _passwordsMatch ? 'As senhas coincidem' : 'As senhas não coincidem',
                          style: TextStyle(
                            color: _passwordsMatch ? AppColors.primaryLight : AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Botão Salvar
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'ALTERAR SENHA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool showPassword,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: !showPassword,
            onChanged: onChanged,
            validator: validator,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  showPassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onPressed: onToggle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _strengthScore / 5,
                  backgroundColor: AppColors.inputBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _strengthLabel,
              style: TextStyle(
                color: _strengthColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementsList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _requirementRow('Mínimo de 8 caracteres', _hasMinLength),
          _requirementRow('Letra maiúscula (A-Z)', _hasUppercase),
          _requirementRow('Letra minúscula (a-z)', _hasLowercase),
          _requirementRow('Número (0-9)', _hasNumber),
          _requirementRow('Caractere especial (!@#\$...)', _hasSpecialChar),
        ],
      ),
    );
  }

  Widget _requirementRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: met ? AppColors.primaryLight : AppColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: met ? Colors.white : AppColors.textMuted,
              fontSize: 12,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
