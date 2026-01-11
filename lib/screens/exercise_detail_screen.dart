import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise.dart';
import '../services/api/providers.dart';
import '../utils/language_settings.dart';
import '../app/theme.dart';

/// Ekran szczegółów ćwiczenia z pełnymi danymi
class ExerciseDetailScreen extends ConsumerStatefulWidget {
  final String exerciseCode;
  final String? exerciseName;

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseCode,
    this.exerciseName,
  });

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Exercise? _exercise;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExercise();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExercise() async {
    try {
      final exercise = await ref
          .read(exerciseServiceProvider)
          .getExerciseByCode(widget.exerciseCode);
      if (mounted) {
        setState(() {
          _exercise = exercise;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.exerciseName ?? 'Ładowanie...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _exercise == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.exerciseName ?? 'Błąd')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error ?? 'Nie znaleziono ćwiczenia'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Wróć'),
              ),
            ],
          ),
        ),
      );
    }

    final exercise = _exercise!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Appbar z obrazem
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.bgAlt,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Obraz GIF ćwiczenia
                  if (exercise.mainImage.isNotEmpty)
                    Image.asset(
                      exercise.mainImage,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.bgAlt,
                        child: const Center(
                          child: Icon(Icons.fitness_center,
                              size: 80, color: Colors.white24),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.bgAlt,
                      child: const Center(
                        child: Icon(Icons.fitness_center,
                            size: 80, color: Colors.white24),
                      ),
                    ),
                  // Gradient na dole
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.bg.withOpacity(0.8),
                            AppColors.bg,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nagłówek z nazwą i tagami
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nazwa ćwiczenia
                  Text(
                    exercise.getName(lang),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tagi informacyjne
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        icon: Icons.fitness_center,
                        label: exercise.getPrimaryMuscleLabel(lang),
                        color: AppColors.accent,
                      ),
                      _buildInfoChip(
                        icon: Icons.build,
                        label: exercise.getEquipmentLabel(lang),
                        color: Colors.blue,
                      ),
                      _buildInfoChip(
                        icon: Icons.speed,
                        label: exercise.getDifficultyLabel(lang),
                        color: _getDifficultyColor(exercise.difficulty),
                      ),
                      if (exercise.safety.requiresSpotter)
                        _buildInfoChip(
                          icon: Icons.people,
                          label: AppTranslations.get('spotter_required', lang),
                          color: Colors.orange,
                        ),
                    ],
                  ),

                  // Pomocnicze partie mięśniowe
                  if (exercise.secondaryMuscles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      AppTranslations.get('secondary_muscles', lang),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: exercise.secondaryMuscles
                          .map((m) => Chip(
                                label: Text(m,
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.white10,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // TabBar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: AppTranslations.get('instructions', lang)),
                  Tab(text: AppTranslations.get('common_mistakes', lang)),
                  Tab(text: AppTranslations.get('safety_tips', lang)),
                ],
              ),
            ),
          ),

          // Zawartość tabów
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInstructionsTab(exercise, lang),
                _buildMistakesTab(exercise, lang),
                _buildSafetyTab(exercise, lang),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  Widget _buildInstructionsTab(Exercise exercise, String lang) {
    final instructions = exercise.getInstructions(lang);

    if (instructions.isEmpty) {
      return const Center(
        child: Text(
          'Brak instrukcji',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: instructions.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  instructions[index],
                  style: const TextStyle(
                    height: 1.5,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMistakesTab(Exercise exercise, String lang) {
    final mistakes = exercise.getCommonMistakes(lang);

    if (mistakes.isEmpty) {
      return const Center(
        child: Text(
          'Brak informacji o błędach',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: mistakes.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mistakes[index],
                  style: const TextStyle(
                    height: 1.4,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSafetyTab(Exercise exercise, String lang) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Czy wymaga asekuracji
        if (exercise.safety.requiresSpotter)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppTranslations.get('spotter_required', lang),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Kontuzje do unikania
        if (exercise.safety.excludedInjuries.isNotEmpty) ...[
          Text(
            AppTranslations.get('avoid_if_injury', lang),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...exercise.safety.excludedInjuries.map((injury) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.do_not_disturb,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      injury,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )),
        ],

        if (!exercise.safety.requiresSpotter &&
            exercise.safety.excludedInjuries.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 12),
                Text(
                  lang == 'pl'
                      ? 'To ćwiczenie jest bezpieczne dla większości osób'
                      : 'This exercise is safe for most people',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.bg,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}
