import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/idmt_curves.dart';

// Abre o seletor de curva IDMT (agrupado por família) e retorna a curva escolhida.
Future<IdmtCurve?> showIdmtCurvePicker(
  BuildContext context, {
  String? selectedId,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<IdmtCurve>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _IdmtCurvePicker(selectedId: selectedId),
  );
}

class _IdmtCurvePicker extends StatelessWidget {
  final String? selectedId;

  const _IdmtCurvePicker({this.selectedId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                AppLocalizations.of(context)!.toolsSelectCurve,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final family in idmtFamilies) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Text(
                        family.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    for (final c
                        in idmtCurves.where((e) => e.family == family))
                      _curveTile(context, c),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _curveTile(BuildContext context, IdmtCurve c) {
    final selected = c.id == selectedId;
    return Semantics(
      button: true,
      selected: selected,
      label: c.name,
      child: InkWell(
        onTap: () => Navigator.pop(context, c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    color: AppColors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
