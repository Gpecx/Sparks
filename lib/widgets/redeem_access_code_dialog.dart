import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/services/access_code_service.dart';
import 'package:spark_app/l10n/app_localizations.dart';

/// Popup que pede a chave de acesso (código de cortesia) ao usuário e a resgata
/// via [AccessCodeService]. Pensado para ser exibido logo após um cadastro novo
/// (ex.: primeiro login com Google, onde não há campo de chave no fluxo).
///
/// O usuário pode pular ("Agora não"). Retorna `true` se uma chave foi resgatada
/// com sucesso, `false` caso o usuário pule ou feche o diálogo.
Future<bool> showRedeemAccessCodeDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _RedeemAccessCodeDialog(),
  );
  return result ?? false;
}

class _RedeemAccessCodeDialog extends StatefulWidget {
  const _RedeemAccessCodeDialog();

  @override
  State<_RedeemAccessCodeDialog> createState() =>
      _RedeemAccessCodeDialogState();
}

class _RedeemAccessCodeDialogState extends State<_RedeemAccessCodeDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = l10n.enterCode);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final until = await AccessCodeService.instance.redeem(code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      final d =
          '${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')}/${until.year}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text(l10n.accessGrantedUntil(d)),
        ),
      );
    } on AccessCodeException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = l10n.redeemError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Row(
        children: [
          const Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.redeemPromptTitle,
                style: const TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.redeemPromptDesc,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            enabled: !_loading,
            onSubmitted: (_) => _loading ? null : _redeem(),
            style: const TextStyle(
                color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'PROF-XXXX-XXXX',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              errorText: _error,
              enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.textMuted)),
              focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.redeemSkip,
              style: const TextStyle(color: AppColors.textMuted)),
        ),
        FilledButton(
          onPressed: _loading ? null : _redeem,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l10n.settingsRedeem),
        ),
      ],
    );
  }
}
