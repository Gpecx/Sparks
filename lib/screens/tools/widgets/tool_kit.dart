import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

// Página padrão de uma ferramenta: fundo Spark + AppBar + lista centralizada.
class ToolPage extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ToolPage({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(title),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToolCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;

  const ToolCard({super.key, this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || subtitle != null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
          ],
          if (hasHeader) const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class ToolField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? semantic;
  final bool signed;

  const ToolField({
    super.key,
    required this.controller,
    required this.label,
    this.semantic,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semantic ?? label,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(
          decimal: true,
          signed: signed,
        ),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

// Duas (ou mais) ToolField lado a lado.
class ToolFieldRow extends StatelessWidget {
  final List<Widget> children;
  const ToolFieldRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(Expanded(child: children[i]));
      if (i != children.length - 1) spaced.add(const SizedBox(width: 10));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: spaced);
  }
}

class ToolButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const ToolButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.calculate_outlined),
        label: Text(label),
      ),
    );
  }
}

// Seletor segmentado horizontal (modos / abas).
class ToolSegmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const ToolSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: labels[i],
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: i == selected
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: i == selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ToolResult {
  final String label;
  final String value;

  const ToolResult(this.label, this.value);

  String get clip => '$label: $value';
}

class ToolResultsPanel extends StatelessWidget {
  final List<ToolResult> results;
  final String title;
  final String? warning;
  final String? note;

  const ToolResultsPanel({
    super.key,
    required this.results,
    this.title = 'Resultados',
    this.warning,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    if (warning != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                warning!,
                style: const TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: AppLocalizations.of(context)!.tlCopyAll,
                child: IconButton(
                  icon: const Icon(Icons.copy_all_outlined,
                      color: AppColors.primary, size: 20),
                  tooltip: 'Copiar tudo',
                  onPressed: () {
                    final text = results.map((r) => r.clip).join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    HapticFeedback.lightImpact();
                    SparkSnack.success(context, AppLocalizations.of(context)!.tlResultsCopied);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...results.map((r) => _row(context, r)),
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(
              note!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ToolResult r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        label: '${r.label}: ${r.value}',
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                r.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  r.value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Copiar ${r.label}',
              child: IconButton(
                icon: const Icon(Icons.copy_outlined,
                    color: AppColors.textMuted, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Copiar',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: r.clip));
                  HapticFeedback.selectionClick();
                  SparkSnack.success(context, '${r.label} copiado');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helpers de formatação numérica (vírgula como separador é tratado na entrada).
String fmtNumber(double v, {int decimals = 2}) {
  if (v.isNaN || v.isInfinite) return '—';
  if (v != 0 && (v.abs() >= 1e6 || v.abs() < 1e-3)) {
    return v.toStringAsExponential(3);
  }
  return v.toStringAsFixed(decimals);
}
