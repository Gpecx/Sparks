class I18nUtils {
  /// Idioma atual do app ('pt' | 'en' | 'es'). Atualizado pelo LanguageNotifier.
  /// Os models de conteúdo usam isto para localizar no parse do Firestore sem
  /// precisar passar o idioma por toda a árvore de chamadas. O conteúdo é relido
  /// ao reabrir as telas, então a troca de idioma se reflete na próxima leitura.
  static String currentLang = 'pt';

  /// Mapa de traduções de um doc para um idioma (ex.: translations['en']),
  /// já tratando o caso 'pt' (sem tradução) e ausência de dados.
  static Map<String, dynamic>? _langMap(Map<String, dynamic>? json, String lang) {
    if (json == null || lang == 'pt') return null;
    final translations = json['translations'];
    if (translations is Map) {
      final m = translations[lang];
      if (m is Map) return Map<String, dynamic>.from(m);
    }
    return null;
  }

  /// Campo string traduzido, com fallback para o valor original (PT).
  static String localized(Map<String, dynamic>? json, String field, String lang) {
    if (json == null) return '';
    final fallback = json[field]?.toString() ?? '';
    final m = _langMap(json, lang);
    final v = m?[field];
    return v != null ? v.toString() : fallback;
  }

  /// Campo string traduzido que retorna null se a origem for null.
  static String? localizedNullable(Map<String, dynamic>? json, String field, String lang) {
    if (json == null || json[field] == null) return null;
    final fallback = json[field].toString();
    final m = _langMap(json, lang);
    final v = m?[field];
    return v != null ? v.toString() : fallback;
  }

  /// Lista de strings traduzida (ex.: options[] das questões), com fallback PT.
  /// Só usa a tradução se tiver o MESMO tamanho da original (segurança).
  static List<String> localizedList(Map<String, dynamic>? json, String field, String lang) {
    final original = (json?[field] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final m = _langMap(json, lang);
    final translated = m?[field];
    if (translated is List && translated.length == original.length) {
      return translated.map((e) => e.toString()).toList();
    }
    return original;
  }

  /// Valor traduzido cru (dynamic) para estruturas aninhadas — ex.: sections de
  /// um capítulo de ebook, ou blanks de uma questão. Faz fallback para o PT.
  static dynamic localizedRaw(Map<String, dynamic>? json, String field, String lang) {
    if (json == null) return null;
    final m = _langMap(json, lang);
    final v = m?[field];
    return v ?? json[field];
  }
}
