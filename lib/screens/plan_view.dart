import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';
import '../utils/language_settings.dart';
import 'exercise_detail_screen.dart';

/// Helper do wyciągnięcia nazwy ćwiczenia (obsługuje różne formaty)
String _getExerciseName(dynamic exercise, [String lang = 'pl']) {
  if (exercise == null) return 'Nieznane';
  if (exercise is String) return exercise;
  if (exercise is Map) {
    final name = exercise['name'];
    if (name is String) return name;
    if (name is Map) {
      return name[lang]?.toString() ?? name['en']?.toString() ?? name['pl']?.toString() ?? 'Nieznane';
    }
    return exercise['name_$lang']?.toString() ?? 
           exercise['name_en']?.toString() ?? 
           exercise['name_pl']?.toString() ?? 
           exercise['code']?.toString() ?? 
           'Nieznane';
  }
  return exercise.toString();
}

typedef OnExerciseChanged = void Function(
  int dayIndex,
  int exerciseIndex,
  Map<String, dynamic> newValues,
);

class PlanView extends ConsumerWidget {
  final Map<String, dynamic> plan;
  final OnExerciseChanged? onExerciseChanged;
  final String unitSystem;

  const PlanView({
    super.key,
    required this.plan,
    this.onExerciseChanged,
    this.unitSystem = 'metric',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split = plan['split']?.toString() ?? 'Twój Plan';
    final week = (plan['week'] as List?) ?? const [];
    final isEditable = onExerciseChanged != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        // --- NAGŁÓWEK PLANU ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                split.toUpperCase(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Twój harmonogram tygodniowy',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              if (isEditable)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        'Dotknij ołówka, aby zmienić parametry lub ćwiczenie.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // --- LISTA DNI ---
        ...week.asMap().entries.map((dayEntry) {
          final int dayIndex = dayEntry.key;
          final Map d = dayEntry.value as Map;
          final exercises = (d['exercises'] as List?) ?? const [];
          
          if (exercises.isEmpty) {
            return _buildRestDayCard(context, d);
          }

          return _buildWorkoutDayCard(
            context,
            ref,
            d,
            exercises,
            dayIndex,
            isEditable,
          );
        }),
      ],
    );
  }

  Widget _buildRestDayCard(BuildContext context, Map dayData) {
    final dayName = (dayData['day'] ?? dayData['block'] ?? 'Dzień').toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.self_improvement, color: Colors.greenAccent),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Regeneracja',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutDayCard(
    BuildContext context,
    WidgetRef ref,
    Map dayData,
    List exercises,
    int dayIndex,
    bool isEditable,
  ) {
    final dayName = (dayData['day'] ?? dayData['block'] ?? 'Dzień').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nagłówek dnia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '${exercises.length} ćwiczeń',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          
          // Lista ćwiczeń
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            itemCount: exercises.length,
            separatorBuilder: (ctx, i) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
            itemBuilder: (ctx, i) {
              return _buildExerciseRow(
                context,
                ref,
                exercises[i] as Map,
                dayIndex,
                i,
                isEditable,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(
    BuildContext context,
    WidgetRef ref,
    Map exercise,
    int dayIndex,
    int exerciseIndex,
    bool isEditable,
  ) {
    final lang = ref.watch(languageProvider);
    final name = _getExerciseName(exercise, lang);
    final sets = exercise['sets']?.toString() ?? '0';
    final reps = exercise['reps']?.toString() ?? '0';
    final exerciseCode = exercise['code']?.toString() ?? '';
    
    // Check if exercise has code to show details
    final bool hasCode = exerciseCode.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ikonka / Numer
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${exerciseIndex + 1}',
              style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          
          // Treść
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatBadge(context, sets, 'SERII'),
                    const SizedBox(width: 8),
                    _buildStatBadge(context, reps, 'POWT'),
                  ],
                )
              ],
            ),
          ),

          // Akcje (Info / Edit)
          Column(
            children: [
              if (hasCode)
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  color: Colors.white38,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: () => _navigateToExerciseDetails(context, exerciseCode, name),
                ),
              if (isEditable)
                IconButton(
                  icon: Icon(Icons.edit, size: 20, color: Theme.of(context).colorScheme.primary),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: () => _showEditDialog(context, ref, exercise, dayIndex, exerciseIndex),
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label.toLowerCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // --- DIALOGI I LOGIKA EDYCJI ---

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Map currentExercise,
    int dayIndex,
    int exerciseIndex,
  ) {
    final setsCtrl = TextEditingController(text: currentExercise['sets']?.toString() ?? '');
    final repsCtrl = TextEditingController(text: currentExercise['reps']?.toString() ?? '');
    final lang = ref.read(languageProvider);
    
    // Zmienne stanu dialogu
    List<Map<String, dynamic>> alternatives = [];
    bool isLoadingAlts = true;
    bool requestSent = false;
    Map<String, dynamic>? selectedAlternative; // Jeśli null, używamy currentExercise

    // Helper to safely get equipment string
    String _getEquipmentString(dynamic equipment) {
      if (equipment == null) return '-';
      if (equipment is String) return equipment;
      if (equipment is List) {
        return equipment.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).join(', ');
      }
      return '-';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Pierwsze uruchomienie wewnątrz dialogu - pobranie danych
            if (isLoadingAlts && !requestSent) {
              requestSent = true;
              ref.read(exerciseServiceProvider).getAlternatives(currentExercise['code']?.toString() ?? '')
                .then((alts) {
                  if (context.mounted) {
                    setDialogState(() {
                      alternatives = alts;
                      isLoadingAlts = false;
                    });
                  }
                }).catchError((e) {
                  if (context.mounted) {
                    setDialogState(() {
                      alternatives = [];
                      isLoadingAlts = false;
                    });
                  }
                });
            }

            final activeExercise = selectedAlternative ?? currentExercise;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                lang == 'pl' ? 'Edytuj ćwiczenie' : 'Edit exercise',
                style: const TextStyle(fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- ZMIANA PARAMETRÓW ---
                      Text(
                        lang == 'pl' ? 'Parametry treningowe:' : 'Training parameters:',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: setsCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: lang == 'pl' ? 'Serie' : 'Sets',
                                filled: true,
                                fillColor: Colors.black12,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: repsCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: lang == 'pl' ? 'Powtórzenia' : 'Reps',
                                filled: true,
                                fillColor: Colors.black12,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: TextInputType.text,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),

                      // --- WYBÓR ĆWICZENIA ---
                      Text(
                        lang == 'pl' ? 'Wymień ćwiczenie na inne:' : 'Swap exercise for another:',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      
                      // Obecnie wybrane
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _getExerciseName(activeExercise, lang),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Lista alternatyw
                      if (isLoadingAlts)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ))
                      else if (alternatives.isEmpty)
                        Text(
                          lang == 'pl' 
                            ? 'Brak dostępnych alternatyw dla tego ćwiczenia.'
                            : 'No alternatives available for this exercise.',
                          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        )
                      else
                        ...alternatives.map((alt) {
                          // Nie pokazujemy na liście tego, co jest aktualnie wybrane
                          final altCode = alt['code']?.toString();
                          final activeCode = activeExercise['code']?.toString();
                          if (altCode != null && altCode == activeCode) return const SizedBox.shrink();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.swap_horiz, color: Colors.grey),
                            title: Text(
                              _getExerciseName(alt, lang),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            subtitle: Text(
                              '${lang == 'pl' ? 'Sprzęt' : 'Equipment'}: ${_getEquipmentString(alt['equipment'])}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            onTap: () {
                              setDialogState(() {
                                selectedAlternative = Map<String, dynamic>.from(alt);
                              });
                            },
                          );
                        }),
                        
                        // Opcja powrotu do oryginału
                        if (selectedAlternative != null && selectedAlternative!['code']?.toString() != currentExercise['code']?.toString())
                           ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.undo, color: Colors.orangeAccent),
                            title: Text(
                              '${lang == 'pl' ? 'Przywróć' : 'Restore'}: ${_getExerciseName(currentExercise, lang)}',
                              style: const TextStyle(color: Colors.orangeAccent),
                            ),
                            onTap: () {
                              setDialogState(() {
                                selectedAlternative = null; // Reset do oryginału
                              });
                            },
                          ),
                    ],
                  ),
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
                  child: Text(lang == 'pl' ? 'Zapisz zmiany' : 'Save changes'),
                  onPressed: () {
                    final baseExercise = selectedAlternative ?? currentExercise;
                    
                    final newExerciseData = <String, dynamic>{};
                    baseExercise.forEach((key, value) {
                      newExerciseData[key.toString()] = value;
                    });
                    newExerciseData['sets'] = setsCtrl.text;
                    newExerciseData['reps'] = repsCtrl.text;

                    onExerciseChanged?.call(
                      dayIndex,
                      exerciseIndex,
                      newExerciseData,
                    );
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToExerciseDetails(BuildContext context, String exerciseCode, String exerciseName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exerciseCode: exerciseCode,
          exerciseName: exerciseName,
        ),
      ),
    );
  }
}