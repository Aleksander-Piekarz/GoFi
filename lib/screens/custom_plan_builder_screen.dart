import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../services/api/providers.dart';
import '../models/exercise.dart';
import 'home_screen.dart';

/// Pomocnicza funkcja do wyciągnięcia nazwy ćwiczenia (obsługuje różne formaty)
String getExerciseName(dynamic exercise, [String lang = 'pl']) {
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

class CustomPlanBuilderScreen extends ConsumerStatefulWidget {
  const CustomPlanBuilderScreen({super.key});

  @override
  ConsumerState<CustomPlanBuilderScreen> createState() => _CustomPlanBuilderScreenState();
}

class _CustomPlanBuilderScreenState extends ConsumerState<CustomPlanBuilderScreen> {
  int _currentStep = 0;
  bool _saving = false;
  
  // Konfiguracja planu
  String _splitType = 'fbw';
  int _daysPerWeek = 3;
  List<WorkoutDay> _workoutDays = [];
  int _selectedDayIndex = 0;
  
  static const _splitOptions = [
    {'value': 'fbw', 'label': 'Full Body', 'desc': 'Całe ciało każdego dnia'},
    {'value': 'upper_lower', 'label': 'Upper/Lower', 'desc': 'Góra i dół ciała naprzemiennie'},
    {'value': 'ppl', 'label': 'Push/Pull/Legs', 'desc': 'Pchnięcia, przyciągania, nogi'},
    {'value': 'custom', 'label': 'Własny podział', 'desc': 'Stwórz własny układ'},
  ];

  static const _dayNames = ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'];

  @override
  void initState() {
    super.initState();
    _rebuildDays();
  }

  void _rebuildDays() {
    final newDays = <WorkoutDay>[];
    for (int i = 0; i < _daysPerWeek; i++) {
      final existingExercises = (i < _workoutDays.length) 
          ? _workoutDays[i].exercises 
          : <Map<String, dynamic>>[];
      
      newDays.add(WorkoutDay(
        name: _dayNames[i],
        focus: _getFocusForDay(i),
        exercises: existingExercises,
      ));
    }
    _workoutDays = newDays;
    if (_selectedDayIndex >= _workoutDays.length) {
      _selectedDayIndex = _workoutDays.isNotEmpty ? _workoutDays.length - 1 : 0;
    }
  }

  String _getFocusForDay(int index) {
    switch (_splitType) {
      case 'fbw':
        return 'Full Body';
      case 'upper_lower':
        return index.isEven ? 'Góra ciała' : 'Dół ciała';
      case 'ppl':
        return ['Push', 'Pull', 'Legs'][index % 3];
      default:
        return 'Trening ${index + 1}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Kreator planu'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(child: _buildCurrentStep()),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDone ? Colors.green : (isActive ? AppColors.accent : Colors.white12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text('${index + 1}', style: TextStyle(
                            color: isActive ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                          )),
                  ),
                ),
                if (index < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isDone ? Colors.green : Colors.white12,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Split();
      case 1:
        return _buildStep2Days();
      case 2:
        return _buildStep3Exercises();
      default:
        return const SizedBox();
    }
  }

  // === KROK 1: Wybór typu podziału ===
  Widget _buildStep1Split() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Wybierz typ podziału',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Określ jak chcesz rozłożyć treningi w tygodniu',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        const SizedBox(height: 24),
        ..._splitOptions.map((opt) {
          final isSelected = _splitType == opt['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: isSelected ? AppColors.accent.withOpacity(0.2) : AppColors.bgAlt,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  _splitType = opt['value'] as String;
                  _rebuildDays();
                }),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt['label'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              opt['desc'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? Colors.white60 : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppColors.accent),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // === KROK 2: Konfiguracja dni ===
  Widget _buildStep2Days() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Ile dni w tygodniu?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 24),
        
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgAlt,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDayAdjustButton(Icons.remove, () {
                if (_daysPerWeek > 2) {
                  setState(() {
                    _daysPerWeek--;
                    _rebuildDays();
                  });
                }
              }, _daysPerWeek > 2),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '$_daysPerWeek',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
              
              _buildDayAdjustButton(Icons.add, () {
                if (_daysPerWeek < 7) {
                  setState(() {
                    _daysPerWeek++;
                    _rebuildDays();
                  });
                }
              }, _daysPerWeek < 7),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        const Text(
          'Twój tydzień',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        
        ...List.generate(_workoutDays.length, (i) {
          final day = _workoutDays[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(day.focus, style: const TextStyle(fontSize: 13, color: Colors.white54)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white38, size: 20),
                  onPressed: () => _editDayFocus(i),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDayAdjustButton(IconData icon, VoidCallback onTap, bool enabled) {
    return Material(
      color: enabled ? AppColors.accent : Colors.white10,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: enabled ? Colors.white : Colors.white30),
        ),
      ),
    );
  }

  void _editDayFocus(int index) {
    final controller = TextEditingController(text: _workoutDays[index].focus);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgAlt,
        title: Text('Edytuj ${_workoutDays[index].name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Fokus dnia'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _workoutDays[index].focus = controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  // === KROK 3: Dodawanie ćwiczeń ===
  Widget _buildStep3Exercises() {
    if (_workoutDays.isEmpty) {
      return const Center(child: Text('Brak dni treningowych', style: TextStyle(color: Colors.white54)));
    }
    
    final currentDay = _workoutDays[_selectedDayIndex];
    
    return Column(
      children: [
        // Selector dni
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _workoutDays.length,
            itemBuilder: (ctx, i) {
              final day = _workoutDays[i];
              final isSelected = i == _selectedDayIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${day.name.substring(0, 3)} (${day.exercises.length})'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedDayIndex = i),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.bgAlt,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tytuł dnia
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentDay.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(currentDay.focus, style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _addExercise(_selectedDayIndex),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Dodaj'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lista ćwiczeń
        Expanded(
          child: currentDay.exercises.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center, size: 64, color: Colors.white.withOpacity(0.15)),
                      const SizedBox(height: 16),
                      const Text('Brak ćwiczeń', style: TextStyle(color: Colors.white38)),
                      const SizedBox(height: 8),
                      const Text('Kliknij "Dodaj" aby wybrać ćwiczenia', style: TextStyle(color: Colors.white24, fontSize: 13)),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: currentDay.exercises.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = currentDay.exercises.removeAt(oldIndex);
                      currentDay.exercises.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (ctx, i) => _buildExerciseCard(
                    key: ValueKey('${currentDay.name}_$i'),
                    exercise: currentDay.exercises[i],
                    index: i,
                    onDelete: () => setState(() => currentDay.exercises.removeAt(i)),
                    onEdit: () => _editExercise(_selectedDayIndex, i),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard({
    required Key key,
    required Map<String, dynamic> exercise,
    required int index,
    required VoidCallback onDelete,
    required VoidCallback onEdit,
  }) {
    final name = getExerciseName(exercise);
    
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: Colors.white24, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '${exercise['sets'] ?? 3} serii × ${exercise['reps'] ?? '8-12'} powt.',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20, color: Colors.white38),
            onPressed: onEdit,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.redAccent),
            onPressed: onDelete,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Future<void> _addExercise(int dayIndex) async {
    // Pokaż loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    List<Exercise> exercises = [];
    try {
      exercises = await ref.read(exerciseServiceProvider).getAllExercises(limit: 200)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // zamknij loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania ćwiczeń: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    if (!mounted) return;
    Navigator.pop(context); // zamknij loading
    
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak ćwiczeń w bazie'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    final selected = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _ExercisePickerSheet(
          exercises: exercises,
          scrollController: scrollController,
        ),
      ),
    );
    
    if (selected != null && mounted) {
      setState(() {
        _workoutDays[dayIndex].exercises.add({
          'code': selected.code,
          'name': selected.getName('pl'),
          'name_en': selected.getName('en'),
          'name_pl': selected.getName('pl'),
          'pattern': selected.pattern,
          'primary_muscle': selected.primaryMuscle,
          'sets': 3,
          'reps': '8-12',
        });
      });
    }
  }

  void _editExercise(int dayIndex, int exerciseIndex) {
    final exercise = _workoutDays[dayIndex].exercises[exerciseIndex];
    final setsCtrl = TextEditingController(text: (exercise['sets'] ?? 3).toString());
    final repsCtrl = TextEditingController(text: (exercise['reps'] ?? '8-12').toString());
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgAlt,
        title: Text(getExerciseName(exercise)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: setsCtrl,
              decoration: const InputDecoration(labelText: 'Serie'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: repsCtrl,
              decoration: const InputDecoration(labelText: 'Powtórzenia'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _workoutDays[dayIndex].exercises[exerciseIndex]['sets'] = int.tryParse(setsCtrl.text) ?? 3;
                _workoutDays[dayIndex].exercises[exerciseIndex]['reps'] = repsCtrl.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  // === NAWIGACJA ===
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Wstecz'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _saving ? null : _handleNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_currentStep < 2 ? 'Dalej' : 'Zapisz plan', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _savePlan();
    }
  }

  Future<void> _savePlan() async {
    final hasExercises = _workoutDays.any((d) => d.exercises.isNotEmpty);
    if (!hasExercises) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dodaj przynajmniej jedno ćwiczenie'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    
    setState(() => _saving = true);
    
    try {
      final plan = {
        'split': _getSplitName(),
        'custom': true,
        'week': _workoutDays.map((day) => {
          'day': day.name,
          'block': day.focus,
          'exercises': day.exercises,
        }).toList(),
        'progression': [
          {'week': 1, 'note': 'Tydzień 1: Adaptacja - zostaw 2-3 powtórzenia w zapasie.'},
          {'week': 2, 'note': 'Tydzień 2: Zwiększ ciężar o 2.5% w głównych ćwiczeniach.'},
          {'week': 3, 'note': 'Tydzień 3: Zwiększ intensywność (RIR 1).'},
          {'week': 4, 'note': 'Tydzień 4: Deload - 50% objętości.'},
        ],
      };
      
      await ref.read(questionnaireServiceProvider).saveCustomPlan(plan);
      ref.invalidate(planProvider);
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _getSplitName() {
    switch (_splitType) {
      case 'fbw': return 'Full Body ($_daysPerWeek dni)';
      case 'upper_lower': return 'Upper/Lower ($_daysPerWeek dni)';
      case 'ppl': return 'Push/Pull/Legs ($_daysPerWeek dni)';
      default: return 'Własny plan ($_daysPerWeek dni)';
    }
  }
}

// === MODEL ===
class WorkoutDay {
  String name;
  String focus;
  List<Map<String, dynamic>> exercises;
  
  WorkoutDay({required this.name, required this.focus, List<Map<String, dynamic>>? exercises})
      : exercises = exercises ?? [];
}

// === WIDGET DO WYBORU ĆWICZENIA ===
class _ExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final ScrollController scrollController;
  
  const _ExercisePickerSheet({required this.exercises, required this.scrollController});
  
  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _search = '';
  
  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises.where((ex) {
      if (_search.isEmpty) return true;
      final name = ex.getName('pl').toLowerCase();
      final code = ex.code.toLowerCase();
      return name.contains(_search.toLowerCase()) || code.contains(_search.toLowerCase());
    }).toList();
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Szukaj ćwiczenia...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.bgAlt,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final ex = filtered[i];
              return ListTile(
                title: Text(ex.getName('pl'), style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${ex.primaryMuscle} • ${ex.pattern}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                onTap: () => Navigator.pop(context, ex),
              );
            },
          ),
        ),
      ],
    );
  }
}
