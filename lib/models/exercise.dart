/// Model ćwiczenia z pełnymi danymi z exercises_final.json
class Exercise {
  final String code;
  final Map<String, String> name; // {'en': '...', 'pl': '...'}
  final String pattern;
  final String mechanics;
  final String difficulty;
  final String equipment;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final String description;
  final Map<String, List<String>> instructions; // {'en': [...], 'pl': [...]}
  final List<String> images;
  final Map<String, List<String>> commonMistakes; // {'en': [...], 'pl': [...]}
  final ExerciseSafety safety;

  Exercise({
    required this.code,
    required this.name,
    required this.pattern,
    required this.mechanics,
    required this.difficulty,
    required this.equipment,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.description,
    required this.instructions,
    required this.images,
    required this.commonMistakes,
    required this.safety,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      code: json['code'] ?? '',
      name: _parseLocalizedString(json['name']),
      pattern: json['pattern'] ?? '',
      mechanics: json['mechanics'] ?? '',
      difficulty: json['difficulty'] ?? 'beginner',
      equipment: json['equipment'] ?? 'body weight',
      primaryMuscle: json['primary_muscle'] ?? '',
      secondaryMuscles: List<String>.from(json['secondary_muscles'] ?? []),
      description: json['description'] ?? '',
      instructions: _parseLocalizedStringList(json['instructions']),
      images: List<String>.from(json['images'] ?? []),
      commonMistakes: _parseLocalizedStringList(json['common_mistakes']),
      safety: ExerciseSafety.fromJson(json['safety'] ?? {}),
    );
  }

  static Map<String, String> _parseLocalizedString(dynamic value) {
    if (value is Map) {
      return {
        'en': value['en']?.toString() ?? '',
        'pl': value['pl']?.toString() ?? '',
      };
    }
    final str = value?.toString() ?? '';
    return {'en': str, 'pl': str};
  }

  static Map<String, List<String>> _parseLocalizedStringList(dynamic value) {
    if (value is Map) {
      return {
        'en': List<String>.from(value['en'] ?? []),
        'pl': List<String>.from(value['pl'] ?? []),
      };
    }
    return {'en': [], 'pl': []};
  }

  /// Zwraca nazwę w danym języku
  String getName(String lang) => name[lang] ?? name['en'] ?? code;

  /// Zwraca instrukcje w danym języku
  List<String> getInstructions(String lang) =>
      instructions[lang] ?? instructions['en'] ?? [];

  /// Zwraca częste błędy w danym języku
  List<String> getCommonMistakes(String lang) =>
      commonMistakes[lang] ?? commonMistakes['en'] ?? [];

  /// Zwraca ścieżkę do głównego obrazu GIF
  String get mainImage => images.isNotEmpty
      ? images.first
          .replaceFirst('assets/exercises/', 'assets/images/exercises/')
      : '';

  /// Zwraca kolor trudności
  String get difficultyColor {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 'green';
      case 'intermediate':
        return 'orange';
      case 'advanced':
        return 'red';
      default:
        return 'grey';
    }
  }

  /// Tłumaczenie poziomu trudności
  String getDifficultyLabel(String lang) {
    final labels = {
      'beginner': {'en': 'Beginner', 'pl': 'Początkujący'},
      'intermediate': {'en': 'Intermediate', 'pl': 'Średniozaawansowany'},
      'advanced': {'en': 'Advanced', 'pl': 'Zaawansowany'},
    };
    return labels[difficulty.toLowerCase()]?[lang] ?? difficulty;
  }

  /// Tłumaczenie sprzętu
  String getEquipmentLabel(String lang) {
    final labels = {
      'body weight': {'en': 'Bodyweight', 'pl': 'Ciężar ciała'},
      'barbell': {'en': 'Barbell', 'pl': 'Sztanga'},
      'dumbbell': {'en': 'Dumbbell', 'pl': 'Hantle'},
      'cable': {'en': 'Cable', 'pl': 'Wyciąg'},
      'machine': {'en': 'Machine', 'pl': 'Maszyna'},
      'kettlebell': {'en': 'Kettlebell', 'pl': 'Kettlebell'},
      'band': {'en': 'Resistance Band', 'pl': 'Gumy oporowe'},
      'medicine ball': {'en': 'Medicine Ball', 'pl': 'Piłka lekarska'},
      'stability ball': {'en': 'Stability Ball', 'pl': 'Piłka gimnastyczna'},
      'ez barbell': {'en': 'EZ Bar', 'pl': 'Sztanga łamana'},
      'lever': {'en': 'Lever Machine', 'pl': 'Maszyna dźwigniowa'},
      'smith machine': {'en': 'Smith Machine', 'pl': 'Suwnicy Smitha'},
      'sled': {'en': 'Sled', 'pl': 'Sanie'},
      'roller': {'en': 'Roller', 'pl': 'Roller'},
      'suspension': {'en': 'Suspension', 'pl': 'Taśmy TRX'},
      'weighted': {'en': 'Weighted', 'pl': 'Z obciążeniem'},
    };
    return labels[equipment.toLowerCase()]?[lang] ?? equipment;
  }

  /// Tłumaczenie głównej partii mięśniowej
  String getPrimaryMuscleLabel(String lang) {
    final labels = {
      'abs': {'en': 'Abs', 'pl': 'Brzuch'},
      'biceps': {'en': 'Biceps', 'pl': 'Biceps'},
      'triceps': {'en': 'Triceps', 'pl': 'Triceps'},
      'chest': {'en': 'Chest', 'pl': 'Klatka piersiowa'},
      'back': {'en': 'Back', 'pl': 'Plecy'},
      'shoulders': {'en': 'Shoulders', 'pl': 'Barki'},
      'quads': {'en': 'Quadriceps', 'pl': 'Czworogłowe'},
      'hamstrings': {'en': 'Hamstrings', 'pl': 'Dwugłowe'},
      'glutes': {'en': 'Glutes', 'pl': 'Pośladki'},
      'calves': {'en': 'Calves', 'pl': 'Łydki'},
      'forearms': {'en': 'Forearms', 'pl': 'Przedramiona'},
      'traps': {'en': 'Traps', 'pl': 'Kapturowe'},
      'lats': {'en': 'Lats', 'pl': 'Najszersze'},
      'obliques': {'en': 'Obliques', 'pl': 'Skośne brzucha'},
      'hip flexors': {'en': 'Hip Flexors', 'pl': 'Zginacze bioder'},
      'adductors': {'en': 'Adductors', 'pl': 'Przywodziciele'},
      'abductors': {'en': 'Abductors', 'pl': 'Odwodziciele'},
      'erector spinae': {'en': 'Erector Spinae', 'pl': 'Prostowniki grzbietu'},
      'lower back': {'en': 'Lower Back', 'pl': 'Dolna część pleców'},
    };
    return labels[primaryMuscle.toLowerCase()]?[lang] ?? primaryMuscle;
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'pattern': pattern,
        'mechanics': mechanics,
        'difficulty': difficulty,
        'equipment': equipment,
        'primary_muscle': primaryMuscle,
        'secondary_muscles': secondaryMuscles,
        'description': description,
        'instructions': instructions,
        'images': images,
        'common_mistakes': commonMistakes,
        'safety': safety.toJson(),
      };
}

class ExerciseSafety {
  final bool requiresSpotter;
  final List<String> excludedInjuries;

  ExerciseSafety({
    required this.requiresSpotter,
    required this.excludedInjuries,
  });

  factory ExerciseSafety.fromJson(Map<String, dynamic> json) {
    return ExerciseSafety(
      requiresSpotter: json['requires_spotter'] ?? false,
      excludedInjuries: List<String>.from(json['excluded_injuries'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'requires_spotter': requiresSpotter,
        'excluded_injuries': excludedInjuries,
      };
}
