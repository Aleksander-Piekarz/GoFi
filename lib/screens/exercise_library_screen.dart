import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise.dart';
import '../services/api/providers.dart';
import '../utils/language_settings.dart';
import '../app/theme.dart';
import '../widgets/exercise_image.dart';
import 'exercise_detail_screen.dart';

/// Provider dla wyszukiwania i filtrowania ćwiczeń
final exerciseSearchProvider = StateProvider<String>((ref) => '');
final exerciseBodyPartFilterProvider = StateProvider<String?>((ref) => null);
final exerciseMuscleFilterProvider = StateProvider<String?>((ref) => null);
final exerciseEquipmentFilterProvider = StateProvider<String?>((ref) => null);
final exerciseDifficultyFilterProvider = StateProvider<String?>((ref) => null);

/// Mapowanie primary_muscle → body_part (dla custom exercises)
String _mapMuscleToBodyPart(String? muscle) {
  if (muscle == null) return 'FULL_BODY';
  switch (muscle.toLowerCase()) {
    case 'chest':
    case 'pectorals':
      return 'CHEST';
    case 'back':
    case 'lats':
    case 'traps':
    case 'upper back':
    case 'lower back':
    case 'erector spinae':
      return 'BACK';
    case 'shoulders':
    case 'deltoids':
    case 'delts':
      return 'SHOULDERS';
    case 'biceps':
    case 'triceps':
    case 'forearms':
    case 'brachialis':
      return 'ARMS';
    case 'quads':
    case 'quadriceps':
    case 'hamstrings':
    case 'glutes':
    case 'calves':
    case 'hip flexors':
    case 'adductors':
    case 'abductors':
      return 'LEGS';
    case 'abs':
    case 'core':
    case 'obliques':
    case 'abdominals':
      return 'CORE';
    default:
      return 'FULL_BODY';
  }
}

/// Provider dla listy ćwiczeń z filtrami (w tym własne ćwiczenia)
final filteredExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final search = ref.watch(exerciseSearchProvider);
  final bodyPart = ref.watch(exerciseBodyPartFilterProvider);
  final muscle = ref.watch(exerciseMuscleFilterProvider);
  final equipment = ref.watch(exerciseEquipmentFilterProvider);
  final difficulty = ref.watch(exerciseDifficultyFilterProvider);

  final exerciseService = ref.read(exerciseServiceProvider);
  
  // Pobierz standardowe ćwiczenia
  final standardExercises = await exerciseService.getAllExercises(
        search: search.isNotEmpty ? search : null,
        bodyPart: bodyPart,
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
      'difficulty': json['difficulty'] ?? 'beginner',
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
    if (bodyPart != null) {
      final exBodyPart = _mapMuscleToBodyPart(ex.primaryMuscle);
      if (exBodyPart != bodyPart.toUpperCase()) return false;
    }
    if (muscle != null && ex.primaryMuscle != muscle) return false;
    if (equipment != null && ex.equipment != equipment) return false;
    if (difficulty != null && ex.difficulty != difficulty) return false;
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCustomExerciseDialog(context, lang),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(lang == 'pl' ? 'Własne' : 'Custom'),
      ),
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
          // Filtr części ciała (główny, używa body_part z JSON)
          _buildFilterDropdown(
            label: lang == 'pl' ? 'Część ciała' : 'Body part',
            value: ref.watch(exerciseBodyPartFilterProvider),
            items: [
              'CHEST',
              'BACK',
              'SHOULDERS',
              'ARMS',
              'LEGS',
              'CORE',
              'CARDIO',
              'FULL_BODY',
            ],
            displayLabels: {
              'CHEST': lang == 'pl' ? 'Klatka' : 'Chest',
              'BACK': lang == 'pl' ? 'Plecy' : 'Back',
              'SHOULDERS': lang == 'pl' ? 'Barki' : 'Shoulders',
              'ARMS': lang == 'pl' ? 'Ramiona' : 'Arms',
              'LEGS': lang == 'pl' ? 'Nogi' : 'Legs',
              'CORE': lang == 'pl' ? 'Brzuch/Core' : 'Core',
              'CARDIO': lang == 'pl' ? 'Cardio' : 'Cardio',
              'FULL_BODY': lang == 'pl' ? 'Całe ciało' : 'Full body',
            },
            onChanged: (value) {
              ref.read(exerciseBodyPartFilterProvider.notifier).state = value;
              // Reset muscle filter when body part is changed
              ref.read(exerciseMuscleFilterProvider.notifier).state = null;
            },
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
              'band',
              'ez barbell',
              'smith machine',
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
    return ref.read(exerciseBodyPartFilterProvider) != null ||
        ref.read(exerciseMuscleFilterProvider) != null ||
        ref.read(exerciseEquipmentFilterProvider) != null ||
        ref.read(exerciseDifficultyFilterProvider) != null;
  }

  void _resetFilters() {
    ref.read(exerciseBodyPartFilterProvider.notifier).state = null;
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
    Map<String, String>? displayLabels,
  }) {
    String getDisplayText(String item) {
      if (displayLabels != null && displayLabels.containsKey(item)) {
        return displayLabels[item]!;
      }
      return _translateFilterItem(item, lang);
    }

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
                    getDisplayText(item),
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
    // Direct translation map for equipment/difficulty items
    final labels = <String, Map<String, String>>{
      'body weight': {'en': 'Bodyweight', 'pl': 'Ciężar ciała'},
      'barbell': {'en': 'Barbell', 'pl': 'Sztanga'},
      'dumbbell': {'en': 'Dumbbell', 'pl': 'Hantle'},
      'cable': {'en': 'Cable', 'pl': 'Wyciąg'},
      'machine': {'en': 'Machine', 'pl': 'Maszyna'},
      'kettlebell': {'en': 'Kettlebell', 'pl': 'Kettlebell'},
      'band': {'en': 'Resistance Band', 'pl': 'Gumy oporowe'},
      'ez barbell': {'en': 'EZ Bar', 'pl': 'Sztanga łamana'},
      'smith machine': {'en': 'Smith Machine', 'pl': 'Suwnicy Smitha'},
      'beginner': {'en': 'Beginner', 'pl': 'Początkujący'},
      'intermediate': {'en': 'Intermediate', 'pl': 'Średniozaawansowany'},
      'advanced': {'en': 'Advanced', 'pl': 'Zaawansowany'},
    };
    return labels[item.toLowerCase()]?[lang] ?? item;
  }

  Widget _buildExerciseCard(Exercise exercise, String lang) {
    final isCustom = exercise.code.startsWith('custom_');
    
    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCustom ? AppColors.accent.withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
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
            Navigator.pop(context, {
              'code': exercise.code,
              'name': exercise.getName(lang),
              'pattern': exercise.pattern,
              'primary_muscle': exercise.primaryMuscle,
            });
          } else if (!isCustom) {
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
        onLongPress: isCustom ? () => _showCustomExerciseOptions(exercise, lang) : null,
        child: Row(
          children: [
            // Miniaturka obrazu / ikona
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isCustom
                      ? [AppColors.accent.withOpacity(0.4), AppColors.accentSecondary.withOpacity(0.3)]
                      : [AppColors.accent.withOpacity(0.3), AppColors.accentSecondary.withOpacity(0.2)],
                ),
              ),
              child: isCustom
                  ? const Center(child: Icon(Icons.person, color: Colors.white54, size: 40))
                  : ExerciseImage(
                      exerciseCode: exercise.code,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
            ),

            // Informacje
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.getName(lang),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCustom)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lang == 'pl' ? 'WŁASNE' : 'CUSTOM',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                      ],
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

            // Strzałka / opcje
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
    
    // Swipe to delete for custom exercises
    if (isCustom) {
      return Dismissible(
        key: Key(exercise.code),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete, color: Colors.white, size: 28),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(
                lang == 'pl' ? 'Usuń ćwiczenie' : 'Delete exercise',
                style: const TextStyle(color: Colors.white),
              ),
              content: Text(
                lang == 'pl' 
                    ? 'Czy na pewno chcesz usunąć "${exercise.getName(lang)}"?'
                    : 'Are you sure you want to delete "${exercise.getName(lang)}"?',
                style: const TextStyle(color: Colors.grey),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(lang == 'pl' ? 'Anuluj' : 'Cancel',
                      style: const TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Usuń', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ) ?? false;
        },
        onDismissed: (_) => _deleteCustomExercise(exercise, lang),
        child: card,
      );
    }
    
    return card;
  }
  
  void _showCustomExerciseOptions(Exercise exercise, String lang) {
    final id = int.tryParse(exercise.code.replaceFirst('custom_', ''));
    if (id == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              exercise.getName(lang),
              style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: Text(
                lang == 'pl' ? 'Edytuj ćwiczenie' : 'Edit exercise',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showEditCustomExerciseDialog(exercise, id, lang);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                lang == 'pl' ? 'Usuń ćwiczenie' : 'Delete exercise',
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteCustomExercise(exercise, lang);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  Future<void> _deleteCustomExercise(Exercise exercise, String lang) async {
    final id = int.tryParse(exercise.code.replaceFirst('custom_', ''));
    if (id == null) return;
    
    try {
      await ref.read(exerciseServiceProvider).deleteCustomExercise(id);
      ref.invalidate(filteredExercisesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang == 'pl' ? 'Ćwiczenie usunięte' : 'Exercise deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang == 'pl' ? 'Błąd usuwania: $e' : 'Delete error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _showEditCustomExerciseDialog(Exercise exercise, int id, String lang) async {
    final nameEnCtrl = TextEditingController(text: exercise.name['en'] ?? '');
    final namePlCtrl = TextEditingController(text: exercise.name['pl'] ?? '');
    final notesCtrl = TextEditingController(text: exercise.description);
    
    String selectedMuscle = exercise.primaryMuscle.isNotEmpty ? exercise.primaryMuscle : 'chest';
    String selectedEquipment = exercise.equipment.isNotEmpty ? exercise.equipment : 'body weight';
    String selectedDifficulty = exercise.difficulty.isNotEmpty ? exercise.difficulty : 'beginner';
    
    final muscleGroups = _getMuscleGroupOptions();
    final equipmentTypes = _getEquipmentOptions();
    final difficultyLevels = _getDifficultyOptions();
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            lang == 'pl' ? 'Edytuj ćwiczenie' : 'Edit exercise',
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogTextField(nameEnCtrl, lang == 'pl' ? 'Nazwa (EN)' : 'Name (EN)'),
                const SizedBox(height: 12),
                _buildDialogTextField(namePlCtrl, lang == 'pl' ? 'Nazwa (PL)' : 'Name (PL)'),
                const SizedBox(height: 16),
                _buildDialogDropdown(
                  label: lang == 'pl' ? 'Partia mięśniowa:' : 'Muscle group:',
                  value: selectedMuscle,
                  items: muscleGroups,
                  onChanged: (v) => setDialogState(() => selectedMuscle = v ?? 'chest'),
                  lang: lang,
                ),
                const SizedBox(height: 16),
                _buildDialogDropdown(
                  label: lang == 'pl' ? 'Sprzęt:' : 'Equipment:',
                  value: selectedEquipment,
                  items: equipmentTypes,
                  onChanged: (v) => setDialogState(() => selectedEquipment = v ?? 'body weight'),
                  lang: lang,
                ),
                const SizedBox(height: 16),
                _buildDialogDropdown(
                  label: lang == 'pl' ? 'Trudność:' : 'Difficulty:',
                  value: selectedDifficulty,
                  items: difficultyLevels,
                  onChanged: (v) => setDialogState(() => selectedDifficulty = v ?? 'beginner'),
                  lang: lang,
                ),
                const SizedBox(height: 16),
                _buildDialogTextField(notesCtrl, lang == 'pl' ? 'Notatki' : 'Notes', maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(lang == 'pl' ? 'Anuluj' : 'Cancel', style: const TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: Text(lang == 'pl' ? 'Zapisz' : 'Save'),
              onPressed: () async {
                if (nameEnCtrl.text.trim().isEmpty && namePlCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'pl' ? 'Podaj nazwę ćwiczenia' : 'Enter exercise name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                try {
                  await ref.read(exerciseServiceProvider).updateCustomExercise(id, {
                    'name_en': nameEnCtrl.text.trim().isNotEmpty ? nameEnCtrl.text.trim() : null,
                    'name_pl': namePlCtrl.text.trim().isNotEmpty ? namePlCtrl.text.trim() : null,
                    'primary_muscle': selectedMuscle,
                    'equipment': selectedEquipment,
                    'difficulty': selectedDifficulty,
                    'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  });
                  Navigator.of(ctx).pop();
                  ref.invalidate(filteredExercisesProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(lang == 'pl' ? 'Ćwiczenie zaktualizowane!' : 'Exercise updated!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
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
    final nameEnCtrl = TextEditingController();
    final namePlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    
    String selectedMuscle = 'chest';
    String selectedEquipment = 'body weight';
    String selectedDifficulty = 'beginner';
    
    final muscleGroups = _getMuscleGroupOptions();
    final equipmentTypes = _getEquipmentOptions();
    final difficultyLevels = _getDifficultyOptions();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.add_circle, color: AppColors.accent, size: 24),
              const SizedBox(width: 10),
              Text(
                lang == 'pl' ? 'Dodaj własne ćwiczenie' : 'Add custom exercise',
                style: const TextStyle(fontSize: 17, color: Colors.white),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogTextField(
                  nameEnCtrl, 
                  lang == 'pl' ? 'Nazwa (EN) *' : 'Name (EN) *',
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  namePlCtrl, 
                  lang == 'pl' ? 'Nazwa (PL)' : 'Name (PL)',
                ),
                const SizedBox(height: 16),
                _buildDialogDropdown(
                  label: lang == 'pl' ? 'Partia mięśniowa:' : 'Muscle group:',
                  value: selectedMuscle,
                  items: muscleGroups,
                  onChanged: (v) => setDialogState(() => selectedMuscle = v ?? 'chest'),
                  lang: lang,
                ),
                const SizedBox(height: 16),
                _buildDialogDropdown(
                  label: lang == 'pl' ? 'Sprzęt:' : 'Equipment:',
                  value: selectedEquipment,
                  items: equipmentTypes,
                  onChanged: (v) => setDialogState(() => selectedEquipment = v ?? 'body weight'),
                  lang: lang,
                ),
                const SizedBox(height: 16),
                _buildDialogDropdown(
                  label: lang == 'pl' ? 'Trudność:' : 'Difficulty:',
                  value: selectedDifficulty,
                  items: difficultyLevels,
                  onChanged: (v) => setDialogState(() => selectedDifficulty = v ?? 'beginner'),
                  lang: lang,
                ),
                const SizedBox(height: 16),
                _buildDialogTextField(
                  notesCtrl, 
                  lang == 'pl' ? 'Notatki (opcjonalnie)' : 'Notes (optional)', 
                  maxLines: 2,
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
                if (nameEnCtrl.text.trim().isEmpty && namePlCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'pl' ? 'Podaj nazwę ćwiczenia' : 'Enter exercise name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                try {
                  final nameEn = nameEnCtrl.text.trim().isNotEmpty 
                      ? nameEnCtrl.text.trim() 
                      : namePlCtrl.text.trim();
                  final namePl = namePlCtrl.text.trim().isNotEmpty 
                      ? namePlCtrl.text.trim() 
                      : nameEnCtrl.text.trim();
                  
                  await ref.read(exerciseServiceProvider).createCustomExercise(
                    nameEn: nameEn,
                    namePl: namePl,
                    primaryMuscle: selectedMuscle,
                    equipment: selectedEquipment,
                    pattern: 'accessory',
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  
                  Navigator.of(ctx).pop();
                  
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

  // =====================================================
  // Shared dialog helpers
  // =====================================================

  List<Map<String, String>> _getMuscleGroupOptions() => [
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
    {'value': 'lats', 'label_pl': 'Najszersze', 'label_en': 'Lats'},
    {'value': 'traps', 'label_pl': 'Kapturowe', 'label_en': 'Traps'},
    {'value': 'other', 'label_pl': 'Inne', 'label_en': 'Other'},
  ];

  List<Map<String, String>> _getEquipmentOptions() => [
    {'value': 'body weight', 'label_pl': 'Ciężar ciała', 'label_en': 'Body weight'},
    {'value': 'barbell', 'label_pl': 'Sztanga', 'label_en': 'Barbell'},
    {'value': 'dumbbell', 'label_pl': 'Hantle', 'label_en': 'Dumbbell'},
    {'value': 'cable', 'label_pl': 'Wyciąg', 'label_en': 'Cable'},
    {'value': 'machine', 'label_pl': 'Maszyna', 'label_en': 'Machine'},
    {'value': 'kettlebell', 'label_pl': 'Kettlebell', 'label_en': 'Kettlebell'},
    {'value': 'resistance band', 'label_pl': 'Guma oporowa', 'label_en': 'Resistance band'},
    {'value': 'ez barbell', 'label_pl': 'Sztanga łamana', 'label_en': 'EZ Bar'},
    {'value': 'smith machine', 'label_pl': 'Suwnicy Smitha', 'label_en': 'Smith Machine'},
  ];

  List<Map<String, String>> _getDifficultyOptions() => [
    {'value': 'beginner', 'label_pl': 'Początkujący', 'label_en': 'Beginner'},
    {'value': 'intermediate', 'label_pl': 'Średniozaawansowany', 'label_en': 'Intermediate'},
    {'value': 'advanced', 'label_pl': 'Zaawansowany', 'label_en': 'Advanced'},
  ];

  Widget _buildDialogTextField(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required void Function(String?) onChanged,
    required String lang,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: items.any((i) => i['value'] == value) ? value : items.first['value'],
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: items.map((m) => DropdownMenuItem(
            value: m['value'],
            child: Text(lang == 'pl' ? m['label_pl']! : m['label_en']!),
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
