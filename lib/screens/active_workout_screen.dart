import 'dart:async'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';
import '../utils/converters.dart';
import '../utils/language_settings.dart';
import '../models/exercise.dart';
import 'exercise_detail_screen.dart';




class SetLog {
  final int setNumber;
  final String suggestedReps;
  final TextEditingController weightController = TextEditingController();
  
  
  int reps; 
  bool isCompleted = false;

  SetLog({required this.setNumber, required this.suggestedReps})
      
      : reps = int.tryParse(suggestedReps.split('-').first) ?? 8;

  
  void dispose() {
    weightController.dispose();
    
  }

  
  Map<String, dynamic> toMap() => {
    'reps': reps.toString(), 
    'weight': weightController.text.isEmpty ? '0' : weightController.text,
  };
}

class ExerciseLog {
  final String code;
  final String name;
  final List<SetLog> sets;
  Exercise? exerciseData; // Pełne dane ćwiczenia z API

  ExerciseLog({required this.code, required this.name, required this.sets, this.exerciseData});

  void dispose() {
    for (var set in sets) {
      set.dispose();
    }
  }
  
  Map<String, dynamic> toMap() => {
    'code': code,
    'sets': sets.where((s) => s.isCompleted).map((s) => s.toMap()).toList(),
  };

  /// Ścieżka do obrazu GIF ćwiczenia
  String get imagePath => exerciseData?.mainImage ?? 'assets/images/exercises/${code}.gif';
}



class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  final Map workout;
  final String unitSystem;
  const ActiveWorkoutScreen({super.key, required this.workout, required this.unitSystem});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  List<ExerciseLog>? _exerciseLogs;
  late String _planName;
  late UnitConverter _converter;
  bool _isSaving = false;
  int? _expandedExerciseIndex; // Indeks rozwiniętego ćwiczenia

  
  static const int _defaultRestTime = 90; 
  Timer? _timer;
  int _remainingSeconds = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _converter = UnitConverter(unitSystem: widget.unitSystem); 
    _planName = (widget.workout['day'] ?? widget.workout['block'] ?? 'Trening').toString();
    
    
    
    _loadInitialData();
  }
  

  Future<void> _loadInitialData() async {
    final exercises = (widget.workout['exercises'] as List?) ?? [];
    if (exercises.isEmpty) {
      setState(() => _exerciseLogs = []);
      return;
    }

    
    final exerciseCodes = exercises
        .map((ex) => (ex as Map)['code']?.toString())
        .where((code) => code != null)
        .cast<String>()
        .toList();

    
    final Map<String, dynamic> latestLogs = 
        await ref.read(latestLogsProvider(exerciseCodes).future);

    
    final newLogs = exercises.map((exMap) {
      final exercise = exMap as Map;
      final String code = exercise['code']?.toString() ?? 'UNKNOWN';
      final String name = exercise['name']?.toString() ?? 'Nieznane ćwiczenie';
      final int setCount = exercise['sets'] as int? ?? 3;
      final String suggestedReps = exercise['reps']?.toString() ?? '8';

      
      final Map<String, dynamic>? lastLog = latestLogs[code] as Map<String, dynamic>?;

      
      String initialWeight = '';
      String initialReps = suggestedReps.split('-').first;

      if (lastLog != null) {
        
        final double? weightKg = double.tryParse(lastLog['weight']?.toString() ?? '');
        if (weightKg != null) {
          initialWeight = _converter.displayWeight(weightKg).toString();
        }
        initialReps = lastLog['reps']?.toString() ?? initialReps;
      } else {
        
        final double? weightKg = double.tryParse(exercise['weight']?.toString() ?? '');
        if (weightKg != null) {
          initialWeight = _converter.displayWeight(weightKg).toString();
        }
      }

      return ExerciseLog(
        code: code,
        name: name,
        sets: List.generate(
          setCount,
          (index) {
            final setLog = SetLog(
              setNumber: index + 1,
              suggestedReps: suggestedReps,
            );
            
            setLog.weightController.text = initialWeight;
            setLog.reps = int.tryParse(initialReps) ?? 8;
            return setLog;
          },
        ),
      );
    }).toList();

    // Załaduj pełne dane ćwiczeń z API
    _loadExerciseDetails(newLogs);

    
    if (mounted) {
      setState(() {
        _exerciseLogs = newLogs;
      });
    }
  }

  /// Ładuje pełne dane ćwiczeń (obrazy, instrukcje) z API
  Future<void> _loadExerciseDetails(List<ExerciseLog> logs) async {
    final exerciseService = ref.read(exerciseServiceProvider);
    
    for (final log in logs) {
      try {
        final exercise = await exerciseService.getExerciseByCode(log.code);
        if (exercise != null && mounted) {
          setState(() {
            log.exerciseData = exercise;
          });
        }
      } catch (e) {
        print('Błąd ładowania danych ćwiczenia ${log.code}: $e');
      }
    }
  }

  @override
  void dispose() {
    if (_exerciseLogs != null) {
      for (var ex in _exerciseLogs!) { 
        ex.dispose();
      }
    }
    
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  
  void _startTimer() {
    _timer?.cancel(); 
    setState(() {
      _remainingSeconds = _defaultRestTime;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        
        _timer?.cancel();
        _playTimerSound();
      }
    });
  }

  
  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 0;
    });
  }

  
  Future<void> _playTimerSound() async {
    try {
      
      await _audioPlayer.play(AssetSource('sounds/timer_done.mp3'));
    } catch (e) {
      print('Błąd odtwarzania dźwięku: $e');
    }
  }


  Future<void> _finishWorkout() async {
    setState(() => _isSaving = true);

    final workoutData = {
      'planName': _planName,
      'exercises': _exerciseLogs!
          .map((ex) {
            
            final List<Map<String, dynamic>> completedSets = [];
            for (final set in ex.sets) {
              if (set.isCompleted) {
                final displayWeight = double.tryParse(set.weightController.text) ?? 0.0;
                final kgToSave = _converter.saveWeight(displayWeight);
                completedSets.add({
                  'reps': set.reps.toString(),
                  'weight': kgToSave.toString(),
                });
              }
            }
            return {
              'code': ex.code,
              'sets': completedSets,
            };
          })
          .where((exMap) => (exMap['sets'] as List).isNotEmpty)
          .toList(),
    };
    try {
      await ref.read(logServiceProvider).saveWorkout(workoutData);
      if (!mounted) return;
      ref.invalidate(workoutLogsProvider);
      ref.invalidate(latestLogsProvider);
      Navigator.of(context).pop();
      final lang = ref.read(languageProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.get('good_job', lang)),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Błąd zapisu treningu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

 @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_planName),
        actions: [
          
          if (_exerciseLogs != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton(
                onPressed: _isSaving ? null : _finishWorkout,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(AppTranslations.get('finish_workout', lang)),
              ),
            )
        ],
      ),
      
      body: Column(
        children: [
          Expanded(
            child: _exerciseLogs == null
                ? const Center(child: CircularProgressIndicator()) 
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _exerciseLogs!.length,
                    itemBuilder: (context, index) {
                      final exercise = _exerciseLogs![index];
                      return _buildExerciseCard(exercise, index, lang);
                    },
                  ),
          ),
          if (_remainingSeconds > 0)
            _buildTimerWidget()
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseLog exercise, int index, String lang) {
    final unitLabel = _converter.unitLabel;
    final isExpanded = _expandedExerciseIndex == index;
    final exerciseData = exercise.exerciseData;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nagłówek z obrazem i nazwą
          InkWell(
            onTap: () {
              setState(() {
                _expandedExerciseIndex = isExpanded ? null : index;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Miniaturka GIF
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.black26,
                      child: Image.asset(
                        exercise.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.fitness_center, color: Colors.white38),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Nazwa i info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exerciseData?.getName(lang) ?? exercise.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (exerciseData != null)
                          Row(
                            children: [
                              _buildMiniTag(
                                exerciseData.getPrimaryMuscleLabel(lang),
                                Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              _buildMiniTag(
                                exerciseData.getEquipmentLabel(lang),
                                Colors.blue,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  
                  // Przycisk szczegółów
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(
                            exerciseCode: exercise.code,
                            exerciseName: exerciseData?.getName(lang) ?? exercise.name,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Ikona rozwinięcia
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Rozwinięta sekcja z instrukcjami
          if (isExpanded && exerciseData != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Większy obrazek GIF
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.black,
                      child: Image.asset(
                        exercise.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.fitness_center, color: Colors.white24, size: 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Krótkie instrukcje (pierwsze 3 kroki)
                  Text(
                    AppTranslations.get('instructions', lang),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...exerciseData.getInstructions(lang).take(3).map((instruction) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.grey)),
                        Expanded(
                          child: Text(
                            instruction,
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
          
          const Divider(height: 1),
          
          // Serie
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Nagłówek tabeli
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(AppTranslations.get('serie', lang))),
                      Expanded(flex: 3, child: Text('${AppTranslations.get('weight', lang)} ($unitLabel)')),
                      Expanded(flex: 4, child: Center(child: Text(AppTranslations.get('reps', lang)))),
                      const Expanded(flex: 2, child: Center(child: Text('✓'))),
                    ],
                  ),
                ),
                ...exercise.sets.map((set) => _buildSetRow(set)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
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

  Widget _buildSetRow(SetLog set) {
    final theme = Theme.of(context);
    final bool isCompleted = set.isCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                '${set.setNumber}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isCompleted ? Colors.grey : theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
          
          
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextField(
                controller: set.weightController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0',
                  enabled: !isCompleted,
                  border: const UnderlineInputBorder(),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ),

          
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: isCompleted ? null : () {
                      setState(() {
                        if (set.reps > 0) set.reps--;
                      });
                    },
                  ),
                ),
                Container(
                  width: 30, 
                  alignment: Alignment.center,
                  child: Text(
                    '${set.reps}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: isCompleted ? null : () {
                      setState(() {
                        set.reps++;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          
          Expanded(
            flex: 2,
            child: Center(
              child: IconButton(
                icon: Icon(
                  isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                  color: isCompleted ? Colors.green : Colors.grey,
                  size: 28,
                ),
                onPressed: () {
                  setState(() {
                    set.isCompleted = !set.isCompleted;
                  });
                  if (set.isCompleted) {
                    _startTimer();
                  } else {
                    _stopTimer();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildTimerWidget() {
    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);
    final minutes = (_remainingSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SafeArea(
        top: false, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Text(
                  '$minutes:$seconds',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
            TextButton(
              onPressed: _stopTimer,
              child: Text(AppTranslations.get('skip', lang)),
            )
          ],
        ),
      ),
    );
  }
}