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

/// Provider dla listy ćwiczeń z filtrami
final filteredExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final search = ref.watch(exerciseSearchProvider);
  final muscle = ref.watch(exerciseMuscleFilterProvider);
  final equipment = ref.watch(exerciseEquipmentFilterProvider);
  final difficulty = ref.watch(exerciseDifficultyFilterProvider);

  return ref.read(exerciseServiceProvider).getAllExercises(
        search: search.isNotEmpty ? search : null,
        muscle: muscle,
        equipment: equipment,
        difficulty: difficulty,
        limit: 100,
      );
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.selectionMode 
              ? 'Wybierz ćwiczenie'
              : AppTranslations.get('exercise_library', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: widget.selectionMode 
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (!widget.selectionMode) ...[
            const LanguageSwitch(showLabel: false),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: Column(
        children: [
          // Pasek wyszukiwania
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
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
                    fillColor: AppColors.bgAlt,
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
                        ),
                      ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.bgAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
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
            // Miniaturka obrazu
            Container(
              width: 100,
              height: 100,
              color: Colors.black26,
              child: exercise.mainImage.isNotEmpty
                  ? Image.asset(
                      exercise.mainImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Icon(Icons.fitness_center,
                            color: Colors.white24, size: 32),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.fitness_center,
                          color: Colors.white24, size: 32),
                    ),
            ),

            // Informacje
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.build, size: 12, color: Colors.grey[500]),
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
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey),
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
}
