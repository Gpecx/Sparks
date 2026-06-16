import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spark_app/core/utils/i18n_utils.dart';

class LanguageNotifier extends Notifier<Locale> {
  static const _kLanguageKey = 'spark_language_code';

  @override
  Locale build() {
    I18nUtils.currentLang = 'pt';
    _loadLanguage();
    return const Locale('pt'); // Fallback padrão
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString(_kLanguageKey);
    if (langCode != null) {
      I18nUtils.currentLang = langCode; // mantém o read-path do conteúdo em sincronia
      state = Locale(langCode);
    }
  }

  Future<void> setLanguage(Locale locale) async {
    I18nUtils.currentLang = locale.languageCode; // read-path do conteúdo segue o idioma
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageKey, locale.languageCode);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
            .collection('users')
            .doc(user.uid)
            .update({'preferredLanguage': locale.languageCode});
      }
    } catch (_) {
      // Ignora erro se o usuário não tiver doc ainda
    }
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, Locale>(() {
  return LanguageNotifier();
});
