import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider dla wybranego języka aplikacji
final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<String> {
  static const _storageKey = 'app_language';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  LanguageNotifier() : super('pl') {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final lang = await _storage.read(key: _storageKey);
      if (lang != null && (lang == 'pl' || lang == 'en')) {
        state = lang;
      }
    } catch (e) {
      print('Błąd ładowania języka: $e');
    }
  }

  Future<void> setLanguage(String lang) async {
    if (lang != 'pl' && lang != 'en') return;
    state = lang;
    try {
      await _storage.write(key: _storageKey, value: lang);
    } catch (e) {
      print('Błąd zapisywania języka: $e');
    }
  }

  void toggleLanguage() {
    setLanguage(state == 'pl' ? 'en' : 'pl');
  }
}

/// Tłumaczenia interfejsu użytkownika
class AppTranslations {
  static const Map<String, Map<String, String>> _translations = {
    // Ogólne
    'home': {'pl': 'Strona główna', 'en': 'Home'},
    'profile': {'pl': 'Profil', 'en': 'Profile'},
    'settings': {'pl': 'Ustawienia', 'en': 'Settings'},
    'save': {'pl': 'Zapisz', 'en': 'Save'},
    'cancel': {'pl': 'Anuluj', 'en': 'Cancel'},
    'close': {'pl': 'Zamknij', 'en': 'Close'},
    'delete': {'pl': 'Usuń', 'en': 'Delete'},
    'edit': {'pl': 'Edytuj', 'en': 'Edit'},
    'search': {'pl': 'Szukaj', 'en': 'Search'},
    'loading': {'pl': 'Ładowanie...', 'en': 'Loading...'},
    'error': {'pl': 'Błąd', 'en': 'Error'},
    'success': {'pl': 'Sukces', 'en': 'Success'},

    // Nawigacja
    'statistics': {'pl': 'Statystyki', 'en': 'Statistics'},
    'plan': {'pl': 'Plan', 'en': 'Plan'},
    'library': {'pl': 'Biblioteka', 'en': 'Library'},

    // Trening
    'workout': {'pl': 'Trening', 'en': 'Workout'},
    'exercise': {'pl': 'Ćwiczenie', 'en': 'Exercise'},
    'exercises': {'pl': 'Ćwiczenia', 'en': 'Exercises'},
    'sets': {'pl': 'Serie', 'en': 'Sets'},
    'reps': {'pl': 'Powtórzenia', 'en': 'Reps'},
    'weight': {'pl': 'Waga', 'en': 'Weight'},
    'rest': {'pl': 'Odpoczynek', 'en': 'Rest'},
    'start_workout': {'pl': 'Rozpocznij trening', 'en': 'Start Workout'},
    'finish_workout': {'pl': 'Zakończ', 'en': 'Finish'},
    'todays_workout': {'pl': 'Dzisiejszy trening', 'en': "Today's Workout"},
    'rest_day': {'pl': 'Dzień wolny', 'en': 'Rest Day'},
    'rest_message': {
      'pl': 'Odpocznij i zregeneruj siły!',
      'en': 'Rest and recover!'
    },
    'good_job': {
      'pl': 'Dobra robota! Trening zapisany.',
      'en': 'Great job! Workout saved.'
    },
    'serie': {'pl': 'Seria', 'en': 'Set'},

    // Szczegóły ćwiczenia
    'instructions': {'pl': 'Instrukcje', 'en': 'Instructions'},
    'common_mistakes': {'pl': 'Częste błędy', 'en': 'Common Mistakes'},
    'safety_tips': {'pl': 'Bezpieczeństwo', 'en': 'Safety Tips'},
    'spotter_required': {'pl': 'Wymaga asekuracji', 'en': 'Spotter Required'},
    'avoid_if_injury': {
      'pl': 'Unikaj przy kontuzjach:',
      'en': 'Avoid if you have:'
    },
    'primary_muscle': {'pl': 'Główna partia', 'en': 'Primary Muscle'},
    'secondary_muscles': {'pl': 'Pomocnicze partie', 'en': 'Secondary Muscles'},
    'equipment': {'pl': 'Sprzęt', 'en': 'Equipment'},
    'difficulty': {'pl': 'Poziom', 'en': 'Level'},
    'pattern': {'pl': 'Wzorzec ruchu', 'en': 'Movement Pattern'},

    // Biblioteka
    'exercise_library': {'pl': 'Biblioteka ćwiczeń', 'en': 'Exercise Library'},
    'all_muscles': {'pl': 'Wszystkie partie', 'en': 'All Muscles'},
    'all_equipment': {'pl': 'Cały sprzęt', 'en': 'All Equipment'},
    'all_levels': {'pl': 'Wszystkie poziomy', 'en': 'All Levels'},
    'filter': {'pl': 'Filtruj', 'en': 'Filter'},
    'no_exercises_found': {
      'pl': 'Nie znaleziono ćwiczeń',
      'en': 'No exercises found'
    },
    'search_exercises': {
      'pl': 'Szukaj ćwiczeń...',
      'en': 'Search exercises...'
    },

    // Profil/Ustawienia
    'language': {'pl': 'Język', 'en': 'Language'},
    'polish': {'pl': 'Polski', 'en': 'Polish'},
    'english': {'pl': 'Angielski', 'en': 'English'},
    'unit_system': {'pl': 'System jednostek', 'en': 'Unit System'},
    'metric': {'pl': 'Metryczny (kg)', 'en': 'Metric (kg)'},
    'imperial': {'pl': 'Imperialny (lbs)', 'en': 'Imperial (lbs)'},
    'daily_steps': {'pl': 'Dzienny cel kroków', 'en': 'Daily Steps Goal'},
    'logout': {'pl': 'Wyloguj', 'en': 'Logout'},

    // Home
    'welcome_back': {'pl': 'Witaj z powrotem!', 'en': 'Welcome back!'},
    'ready_to_train': {'pl': 'Gotowy na trening?', 'en': 'Ready to train?'},
    'your_activity': {'pl': 'Twoja aktywność', 'en': 'Your Activity'},
    'steps': {'pl': 'Kroki', 'en': 'Steps'},
    'log_weight': {'pl': 'Zapisz wagę', 'en': 'Log Weight'},
    'your_weight': {'pl': 'Twoja waga', 'en': 'Your Weight'},

    // Plan
    'your_plan': {'pl': 'Twój Plan', 'en': 'Your Plan'},
    'weekly_schedule': {
      'pl': 'Twój harmonogram tygodniowy',
      'en': 'Your weekly schedule'
    },
    'recovery': {'pl': 'Regeneracja', 'en': 'Recovery'},
    'edit_hint': {
      'pl': 'Dotknij ołówka, aby zmienić parametry lub ćwiczenie.',
      'en': 'Tap pencil to change parameters or exercise.'
    },

    // Timer
    'skip': {'pl': 'Pomiń', 'en': 'Skip'},

    // Kwestionariusz
    'questionnaire': {'pl': 'Kwestionariusz', 'en': 'Questionnaire'},
    'fill_questionnaire': {
      'pl': 'Wypełnij kwestionariusz',
      'en': 'Fill questionnaire'
    },
    'no_plan_yet': {
      'pl': 'Nie masz jeszcze planu. Wypełnij kwestionariusz.',
      'en': "You don't have a plan yet. Fill the questionnaire."
    },
    'welcome': {'pl': 'Witaj w GoFi!', 'en': 'Welcome to GoFi!'},
  };

  static String get(String key, String lang) {
    return _translations[key]?[lang] ?? _translations[key]?['en'] ?? key;
  }
}

/// Widget przełącznika języka
class LanguageSwitch extends ConsumerWidget {
  final bool showLabel;

  const LanguageSwitch({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => ref.read(languageProvider.notifier).toggleLanguage(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFlag(lang),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                lang.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.swap_horiz,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlag(String lang) {
    return Container(
      width: 24,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: lang == 'pl'
          ? Column(
              children: [
                Expanded(child: Container(color: Colors.white)),
                Expanded(child: Container(color: Colors.red)),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(width: 8, color: const Color(0xFF012169)),
                      Expanded(
                          child: Container(color: const Color(0xFFC8102E))),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(width: 8, color: const Color(0xFF012169)),
                      Expanded(child: Container(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Widget selektora języka (rozwijana lista)
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(Icons.language, color: theme.colorScheme.primary),
      title: Text(AppTranslations.get('language', lang)),
      subtitle: Text(lang == 'pl' ? 'Polski' : 'English'),
      trailing: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'pl', label: Text('PL')),
          ButtonSegment(value: 'en', label: Text('EN')),
        ],
        selected: {lang},
        onSelectionChanged: (selection) {
          ref.read(languageProvider.notifier).setLanguage(selection.first);
        },
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
