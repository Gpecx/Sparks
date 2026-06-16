class I18nUtils {
  /// Retorna o campo traduzido baseado no idioma atual.
  /// Se o idioma for 'pt' ou não houver tradução, retorna o campo original (fallback).
  static String localized(Map<String, dynamic>? json, String field, String lang) {
    if (json == null) return '';
    
    final fallbackValue = json[field]?.toString() ?? '';
    if (lang == 'pt') return fallbackValue;

    final translations = json['translations'] as Map<String, dynamic>?;
    if (translations != null) {
      final langMap = translations[lang] as Map<String, dynamic>?;
      if (langMap != null && langMap[field] != null) {
        return langMap[field].toString();
      }
    }
    
    return fallbackValue;
  }
}
