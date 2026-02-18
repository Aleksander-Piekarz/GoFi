import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise.dart';
import '../services/api/providers.dart';
import '../utils/language_settings.dart';
import '../app/theme.dart';
import 'exercise_detail_screen.dart';

/// Provider dla wyszukiwania i filtrowania ćwiczeń
final exerciseSearchProvider = StateProvider<String>((ref) => '');
final exerciseMuscleFilterProvider = StateProvider<String?>((ref) => null);
final exerciseEquipmentFilterProvider = StateProvider<String?>((ref) => null);
final exerciseDifficultyFilterProvider = StateProvider<String?>((ref) => null);

/// Provider dla listy ćwiczeń z filtrami (w tym własne ćwiczenia)
final filteredExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final search = ref.watch(exerciseSearchProvider);
  final muscle = ref.watch(exerciseMuscleFilterProvider);
  final equipment = ref.watch(exerciseEquipmentFilterProvider);
  final difficulty = ref.watch(exerciseDifficultyFilterProvider);

  final exerciseService = ref.read(exerciseServiceProvider);
  
  // Pobierz standardowe ćwiczenia
  final standardExercises = await exerciseService.getAllExercises(
        search: search.isNotEmpty ? search : null,
        muscle: muscle,
        equipment: equipment,
        difficulty: difficulty,
        limit: 100,
      );
  
  // Pobierz własne ćwiczenia użytkownika
  final customExercisesRaw = await exerciseService.getCustomExercises();
  
  // Konwertuj własne ćwiczenia na model Exercise
  final customExercises = customExercisesRaw.map((raw) {
    final json = Map<String, dynamic>.from(raw);
    return Exercise.fromJson({
      'code': 'custom_${json['id']}',
      'name': {'en': json['name_en'] ?? '', 'pl': json['name_pl'] ?? ''},
      'pattern': json['pattern'] ?? 'accessory',
      'mechanics': 'compound',
      'difficulty': 'beginner',
      'equipment': json['equipment'] ?? 'body weight',
      'primary_muscle': json['primary_muscle'] ?? 'other',
      'secondary_muscles': json['secondary_muscles'] ?? [],
      'description': json['notes'] ?? '',
      'instructions': {'en': <String>[], 'pl': <String>[]},
      'images': <String>[],
      'common_mistakes': {'en': <String>[], 'pl': <String>[]},
      'safety': <String, dynamic>{},
      'is_custom': true,
    });
  }).toList();
  
  // Filtruj własne ćwiczenia według tych samych kryteriów
  final filteredCustom = customExercises.where((ex) {
    if (search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      final nameEn = ex.name['en']?.toLowerCase() ?? '';
      final namePl = ex.name['pl']?.toLowerCase() ?? '';
      if (!nameEn.contains(searchLower) && !namePl.contains(searchLower)) {
        return false;
      }
    }
    if (muscle != null && ex.primaryMuscle != muscle) return false;
    if (equipment != null && ex.equipment != equipment) return false;
    return true;
  }).toList();
  
  // Połącz własne ćwiczenia na początku listy
  return [...filteredCustom, ...standardExercises];
});

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  final bool selectionMode;
  
  const ExerciseLibraryScreen({super.key, this.selectionMode = false});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final asyncExercises = ref.watch(filteredExercisesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bg,
              AppColors.bg.withOpacity(0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            // Custom header zamiast AppBar
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    if (widget.selectionMode)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.bgAlt,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.accent, AppColors.accentSecondary],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.library_books_rounded, color: Colors.white, size: 24),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.selectionMode 
                                ? 'Wybierz ćwiczenie'
                                : AppTranslations.get('exercise_library', lang),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          if (!widget.selectionMode)
                            Text(
                              AppTranslations.get('browse_exercises', lang),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // Pasek wyszukiwania
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppTranslations.get('search_exercises', lang),
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(exerciseSearchProvider.notifier).state =
                                  '';
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            _showFilters
                                ? Icons.filter_list_off
                                : Icons.filter_list,
                            color:
                                _showFilters ? AppColors.accent : Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => _showFilters = !_showFilters),
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    ref.read(exerciseSearchProvider.notifier).state = value;
                  },
                ),
                ),

                // Filtry
                if (_showFilters) ...[
                  const SizedBox(height: 12),
                  _buildFilters(lang),
                ],
              ],
            ),
          ),

          // Lista ćwiczeń
          Expanded(
            child: asyncExercises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Błąd: $err', textAlign: TextAlign.center),
                  ],
                ),
              ),
              data: (exercises) {
                if (exercises.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            AppTranslations.get('no_exercises_found', lang),
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.bgAlt,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.lightbulb_outline, 
                                    color: AppColors.accent, size: 32),
                                const SizedBox(height: 12),
                                Text(
                                  lang == 'pl' 
                                      ? 'Nie znalazłeś tego czego szukasz?\nDodaj własne ćwiczenie!'
                                      : "Can't find what you're looking for?\nAdd your own exercise!",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: Text(lang == 'pl' ? 'Dodaj własne ćwiczenie' : 'Add custom exercise'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _showCreateCustomExerciseDialog(context, lang),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    return _buildExerciseCard(exercises[index], lang);
                  },
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildFilters(String lang) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterDropdown(
            label: AppTranslations.get('primary_muscle', lang),
            value: ref.watch(exerciseMuscleFilterProvider),
            items: [
              'abs',
              'biceps',
              'triceps',
              'chest',
              'back',
              'shoulders',
              'quads',
              'hamstrings',
              'glutes',
              'calves'
            ],
            onChanged: (value) =>
                ref.read(exerciseMuscleFilterProvider.notifier).state = value,
            lang: lang,
          ),
          const SizedBox(width: 8),
          _buildFilterDropdown(
            label: AppTranslations.get('equipment', lang),
            value: ref.watch(exerciseEquipmentFilterProvider),
            items: [
              'body weight',
              'barbell',
              'dumbbell',
              'cable',
              'machine',
              'kettlebell',
              'band'
            ],
            onChanged: (value) => ref
                .read(exerciseEquipmentFilterProvider.notifier)
                .state = value,
            lang: lang,
          ),
          const SizedBox(width: 8),
          _buildFilterDropdown(
            label: AppTranslations.get('difficulty', lang),
            value: ref.watch(exerciseDifficultyFilterProvider),
            items: ['beginner', 'intermediate', 'advanced'],
            onChanged: (value) => ref
                .read(exerciseDifficultyFilterProvider.notifier)
                .state = value,
            lang: lang,
          ),
          const SizedBox(width: 8),
          // Przycisk reset filtrów
          if (_hasActiveFilters())
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
              ),
              onPressed: _resetFilters,
            ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return ref.read(exerciseMuscleFilterProvider) != null ||
        ref.read(exerciseEquipmentFilterProvider) != null ||
        ref.read(exerciseDifficultyFilterProvider) != null;
  }

  void _resetFilters() {
    ref.read(exerciseMuscleFilterProvider.notifier).state = null;
    ref.read(exerciseEquipmentFilterProvider.notifier).state = null;
    ref.read(exerciseDifficultyFilterProvider.notifier).state = null;
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required String lang,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            value != null ? AppColors.accent.withOpacity(0.2) : AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null ? AppColors.accent : Colors.white10,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(label,
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          icon: Icon(
            Icons.arrow_drop_down,
            color: value != null ? AppColors.accent : Colors.grey,
          ),
          dropdownColor: AppColors.bgAlt,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(label, style: const TextStyle(color: Colors.grey)),
            ),
            ...items.map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    _translateFilterItem(item, lang),
                    style: const TextStyle(color: Colors.white),
                  ),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _translateFilterItem(String item, String lang) {
    // Użyj metod z modelu Exercise do tłumaczeń
    final dummyExercise = Exercise(
      code: '',
      name: {},
      pattern: '',
      mechanics: '',
      difficulty: item,
      equipment: item,
      primaryMuscle: item,
      secondaryMuscles: [],
      description: '',
      instructions: {},
      images: [],
      commonMistakes: {},
      safety: ExerciseSafety(requiresSpotter: false, excludedInjuries: []),
    );

    // Sprawdź czy to difficulty, equipment czy muscle
    if (['beginner', 'intermediate', 'advanced'].contains(item.toLowerCase())) {
      return dummyExercise.getDifficultyLabel(lang);
    } else if ([
      'body weight',
      'barbell',
      'dumbbell',
      'cable',
      'machine',
      'kettlebell',
      'band'
    ].contains(item.toLowerCase())) {
      return dummyExercise.getEquipmentLabel(lang);
    } else {
      return dummyExercise.getPrimaryMuscleLabel(lang);
    }
  }

  Widget _buildExerciseCard(Exercise exercise, String lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: () {
          if (widget.selectionMode) {
            // Zwróć wybrany exercise
            Navigator.pop(context, {
              'code': exercise.code,
              'name': exercise.getName(lang),
              'pattern': exercise.pattern,
              'primary_muscle': exercise.primaryMuscle,
            });
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseDetailScreen(
                  exerciseCode: exercise.code,
                  exerciseName: exercise.getName(lang),
                ),
              ),
            );
          }
        },
        child: Row(
          children: [
            // Miniaturka obrazu z gradientem
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent.withOpacity(0.3),
                    AppColors.accentSecondary.withOpacity(0.2),
                  ],
                ),
              ),
              child: exercise.mainImage.isNotEmpty
                  ? Image.asset(
                      exercise.mainImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Icon(Icons.fitness_center,
                            color: Colors.white38, size: 36),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.fitness_center,
                          color: Colors.white38, size: 36),
                    ),
            ),

            // Informacje
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.getName(lang),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMiniChip(
                          exercise.getPrimaryMuscleLabel(lang),
                          AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        _buildMiniChip(
                          exercise.getDifficultyLabel(lang),
                          _getDifficultyColor(exercise.difficulty),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.fitness_center, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          exercise.getEquipmentLabel(lang),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Strzałka
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.selectionMode ? Icons.add_rounded : Icons.chevron_right,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Dialog do tworzenia własnego ćwiczenia
  Future<void> _showCreateCustomExerciseDialog(BuildContext context, String lang) async {
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '10');
    final notesCtrl = TextEditingController();
    
    String selectedMuscle = 'chest';
    String selectedEquipment = 'body weight';
    String selectedPattern = 'accessory';
    
    final muscleGroups = [
      {'value': 'chest', 'label_pl': 'Klatka', 'label_en': 'Chest'},
      {'value': 'back', 'label_pl': 'Plecy', 'label_en': 'Back'},
      {'value': 'shoulders', 'label_pl': 'Barki', 'label_en': 'Shoulders'},
      {'value': 'biceps', 'label_pl': 'Biceps', 'label_en': 'Biceps'},
      {'value': 'triceps', 'label_pl': 'Triceps', 'label_en': 'Triceps'},
      {'value': 'quads', 'label_pl': 'Nogi - przód', 'label_en': 'Quads'},
      {'value': 'hamstrings', 'label_pl': 'Nogi - tył', 'label_en': 'Hamstrings'},
      {'value': 'glutes', 'label_pl': 'Pośladki', 'label_en': 'Glutes'},
      {'value': 'abs', 'label_pl': 'Brzuch', 'label_en': 'Abs'},
      {'value': 'calves', 'label_pl': 'Łydki', 'label_en': 'Calves'},
      {'value': 'forearms', 'label_pl': 'Przedramiona', 'label_en': 'Forearms'},
      {'value': 'other', 'label_pl': 'Inne', 'label_en': 'Other'},
    ];
    
    final equipmentTypes = [
      {'value': 'body weight', 'label_pl': 'Masa ciała', 'label_en': 'Body weight'},
      {'value': 'barbell', 'label_pl': 'Sztanga', 'label_en': 'Barbell'},
      {'value': 'dumbbell', 'label_pl': 'Hantle', 'label_en': 'Dumbbell'},
      {'value': 'cable', 'label_pl': 'Wyciąg', 'label_en': 'Cable'},
      {'value': 'machine', 'label_pl': 'Maszyna', 'label_en': 'Machine'},
      {'value': 'kettlebell', 'label_pl': 'Kettlebell', 'label_en': 'Kettlebell'},
      {'value': 'resistance band', 'label_pl': 'Guma', 'label_en': 'Resistance band'},
    ];
    
    final patternTypes = [
      {'value': 'compound', 'label_pl': 'Złożone', 'label_en': 'Compound'},
      {'value': 'accessory', 'label_pl': 'Izolowane', 'label_en': 'Accessory'},
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            lang == 'pl' ? 'Dodaj własne ćwiczenie' : 'Add custom exercise',
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nazwa ćwiczenia
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: lang == 'pl' ? 'Nazwa ćwiczenia *' : 'Exercise name *',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Partia mięśniowa
                Text(
                  lang == 'pl' ? 'Partia mięśniowa:' : 'Muscle group:',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedMuscle,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: muscleGroups.map((m) => DropdownMenuItem(
                    value: m['value'] as String,
                    child: Text(lang == 'pl' ? m['label_pl'] as String : m['label_en'] as String),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedMuscle = v ?? 'chest'),
                ),
                
                const SizedBox(height: 16),
                
                // Sprzęt
                Text(
                  lang == 'pl' ? 'Sprzęt:' : 'Equipment:',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedEquipment,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: equipmentTypes.map((e) => DropdownMenuItem(
                    value: e['value'] as String,
                    child: Text(lang == 'pl' ? e['label_pl'] as String : e['label_en'] as String),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedEquipment = v ?? 'body weight'),
                ),
                
                const SizedBox(height: 16),
                
                // Notatki
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: lang == 'pl' ? 'Notatki (opcjonalnie)' : 'Notes (optional)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                lang == 'pl' ? 'Anuluj' : 'Cancel',
                style: const TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: Text(lang == 'pl' ? 'Dodaj' : 'Add'),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'pl' ? 'Podaj nazwę ćwiczenia' : 'Enter exercise name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                try {
                  // Utwórz ćwiczenie przez API
                  await ref.read(exerciseServiceProvider).createCustomExercise(
                    nameEn: nameCtrl.text.trim(),
                    namePl: nameCtrl.text.trim(),
                    primaryMuscle: selectedMuscle,
                    equipment: selectedEquipment,
                    pattern: selectedPattern,
                    setsDefault: int.tryParse(setsCtrl.text) ?? 3,
                    repsDefault: int.tryParse(repsCtrl.text) ?? 10,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  
                  Navigator.of(ctx).pop();
                  
                  // Pokaż sukces i odśwież listę
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(lang == 'pl' ? 'Ćwiczenie dodane!' : 'Exercise added!'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Odśwież listę ćwiczeń
                    ref.invalidate(filteredExercisesProvider);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'pl' ? 'Błąd: $e' : 'Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
