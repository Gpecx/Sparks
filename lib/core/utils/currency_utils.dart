import 'package:flutter/widgets.dart';

/// Formata valores monetários conforme o idioma da interface.
///
/// Os preços-base do app estão em Reais (BRL). Em inglês, exibimos o
/// equivalente aproximado em dólares (USD) usando uma taxa fixa.
/// Ajuste [_brlPerUsd] se quiser outra taxa de conversão.
class CurrencyUtils {
  /// Quantos Reais equivalem a 1 dólar (aprox.).
  static const double _brlPerUsd = 5.0;

  static String format(BuildContext context, double brl, {int decimals = 2}) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (isEn) {
      final usd = brl / _brlPerUsd;
      return '\$${usd.toStringAsFixed(decimals)}';
    }
    return 'R\$ ${brl.toStringAsFixed(decimals)}';
  }
}
