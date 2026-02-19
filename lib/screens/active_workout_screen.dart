import 'dart:async'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';
import '../services/api/workout_session_service.dart';
import '../utils/converters.dart';
import '../utils/language_settings.dart';
import '../models/exercise.dart';
import '../widgets/exercise_image.dart';
import 'exercise_detail_screen.dart';




class SetLog {
  final int setNumber;
  final String suggestedReps;
  final TextEditingController weightController = TextEditingController();
  
  
  int reps; 
  bool isCompleted = false;
  bool isInProgress = false; // Czy seria jest w trakcie (timer leci)
  DateTime? startTime; // Czas rozpoczęcia serii
  int durationSeconds = 0; // Czas trwania serii

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

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> with WidgetsBindingObserver {
  List<ExerciseLog>? _exerciseLogs;
  late String _planName;
  late UnitConverter _converter;
  bool _isSaving = false;
  int? _expandedExerciseIndex; // Indeks rozwiniętego ćwiczenia

  // Rest timer
  static const int _defaultRestTime = 90; 
  Timer? _restTimer;
  int _remainingSeconds = 0;
  int _totalRestForCurrentBreak = 0; // Całkowity czas przerwy (do progress bar)
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Workout timing
  Timer? _workoutTimer;
  int _totalWorkoutSeconds = 0;
  int _totalRestSeconds = 0;
  DateTime? _workoutStartTime;
  bool _isPaused = false; // Czy trening jest wstrzymany
  int _pausedAtSeconds = 0; // Czas kiedy wstrzymano
  
  // Session tracking
  int? _sessionId;
  SetLog? _currentActiveSet;
  ExerciseLog? _currentActiveExercise;
  Timer? _setTimer;
  
  // UI preferences
  bool _showSetDuration = true; // Czy pokazywać czas trwania serii

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _converter = UnitConverter(unitSystem: widget.unitSystem); 
    _planName = (widget.workout['day'] ?? widget.workout['block'] ?? 'Trening').toString();
    
    // Start workout timer
    _workoutStartTime = DateTime.now();
    _startWorkoutTimer();
    
    // Start session tracking
    _initSession();
    
    _loadInitialData();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App idzie w tło - zapisz aktualny czas
      _pausedAtSeconds = _totalWorkoutSeconds;
      _workoutTimer?.cancel();
      _isPaused = true;
    } else if (state == AppLifecycleState.resumed && _isPaused) {
      // App wraca - oblicz ile czasu minęło
      if (_workoutStartTime != null) {
        _totalWorkoutSeconds = DateTime.now().difference(_workoutStartTime!).inSeconds;
      }
      _isPaused = false;
      _startWorkoutTimer();
    }
  }
  
  Future<void> _initSession() async {
    try {
      final sessionService = ref.read(workoutSessionServiceProvider);
      final session = await sessionService.startSession(planName: _planName);
      if (session != null && mounted) {
        setState(() {
          _sessionId = session.id;
        });
      }
    } catch (e) {
      print('Error starting session: $e');
    }
  }
  
  void _startWorkoutTimer() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _totalWorkoutSeconds++;
        });
      }
    });
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
      final int setCount = int.tryParse(exercise['sets']?.toString() ?? '') ?? 3;
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
    WidgetsBinding.instance.removeObserver(this);
    if (_exerciseLogs != null) {
      for (var ex in _exerciseLogs!) { 
        ex.dispose();
      }
    }
    
    _restTimer?.cancel();
    _workoutTimer?.cancel();
    _setTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  /// Rozpocznij serię ćwiczenia (startuje timer)
  Future<void> _startSet(ExerciseLog exercise, SetLog set) async {
    // WAŻNE: Zatrzymaj timer przerwy jeśli działa
    _stopRestTimer();
    
    // Kończymy poprzednią aktywną serię jeśli jest
    if (_currentActiveSet != null && _currentActiveExercise != null) {
      await _endCurrentSet(startRest: false);
    }
    
    set.startTime = DateTime.now();
    set.isInProgress = true;
    _currentActiveSet = set;
    _currentActiveExercise = exercise;
    
    // Lokalny timer do śledzenia czasu serii
    _setTimer?.cancel();
    _setTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (set.isInProgress && mounted) {
        setState(() {
          set.durationSeconds = DateTime.now().difference(set.startTime!).inSeconds;
        });
      }
    });
    
    // Wyślij do API
    if (_sessionId != null) {
      try {
        final sessionService = ref.read(workoutSessionServiceProvider);
        await sessionService.startSet(
          sessionId: _sessionId!,
          exerciseCode: exercise.code,
          exerciseName: exercise.name,
          setNumber: set.setNumber,
        );
      } catch (e) {
        print('Error starting set: $e');
      }
    }
    
    setState(() {});
  }
  
  /// Zakończ aktualną serię
  Future<void> _endCurrentSet({bool startRest = true}) async {
    if (_currentActiveSet == null || _currentActiveExercise == null) return;
    
    final set = _currentActiveSet!;
    set.isInProgress = false;
    if (set.startTime != null) {
      set.durationSeconds = DateTime.now().difference(set.startTime!).inSeconds;
    }
    _setTimer?.cancel();
    
    // Wyślij do API
    if (_sessionId != null) {
      try {
        final weight = double.tryParse(set.weightController.text);
        final sessionService = ref.read(workoutSessionServiceProvider);
        await sessionService.endSet(
          sessionId: _sessionId!,
          reps: set.reps,
          weight: weight != null ? _converter.saveWeight(weight) : null,
          startRest: startRest,
        );
      } catch (e) {
        print('Error ending set: $e');
      }
    }
    
    _currentActiveSet = null;
    _currentActiveExercise = null;
  } 

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  void _startRestTimer() {
    _restTimer?.cancel(); 
    setState(() {
      _remainingSeconds = _defaultRestTime;
      _totalRestForCurrentBreak = _defaultRestTime;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _totalRestSeconds++; // Track total rest time
        });
      } else {
        _restTimer?.cancel();
        _playTimerSound();
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _remainingSeconds = 0;
    });
  }

  /// Dodaje nową serię do ćwiczenia
  void _addSet(ExerciseLog exercise, int exerciseIndex) {
    setState(() {
      // Skopiuj parametry z ostatniej serii
      final lastSet = exercise.sets.isNotEmpty ? exercise.sets.last : null;
      final newSetNumber = exercise.sets.length + 1;
      
      final newSet = SetLog(
        setNumber: newSetNumber,
        suggestedReps: lastSet?.suggestedReps ?? '8',
      );
      
      // Skopiuj wagę i powtórzenia z poprzedniej serii
      if (lastSet != null) {
        newSet.weightController.text = lastSet.weightController.text;
        newSet.reps = lastSet.reps;
      }
      
      exercise.sets.add(newSet);
    });
  }

  /// Usuwa ostatnią nieukończoną serię z ćwiczenia
  void _removeSet(ExerciseLog exercise, int exerciseIndex) {
    if (exercise.sets.length <= 1) return;
    
    setState(() {
      // Znajdź ostatnią nieukończoną serię i ją usuń
      final lastIncompleteIndex = exercise.sets.lastIndexWhere((s) => !s.isCompleted);
      
      if (lastIncompleteIndex >= 0) {
        // Zatrzymaj timer jeśli ta seria jest w trakcie
        final setToRemove = exercise.sets[lastIncompleteIndex];
        if (setToRemove.isInProgress) {
          _setTimer?.cancel();
          if (_currentActiveSet == setToRemove) {
            _currentActiveSet = null;
            _currentActiveExercise = null;
          }
        }
        
        setToRemove.dispose();
        exercise.sets.removeAt(lastIncompleteIndex);
        
        // Przenumeruj serie
        for (int i = 0; i < exercise.sets.length; i++) {
          // SetLog nie ma settera na setNumber, więc zostawiamy oryginalne numery
          // ale wyświetlamy i+1 wizualnie
        }
      } else {
        // Wszystkie serie ukończone - usuń ostatnią
        final removed = exercise.sets.removeLast();
        removed.dispose();
      }
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
    // Stop workout timer
    _workoutTimer?.cancel();
    _setTimer?.cancel();
    
    // Kończymy aktywną serię jeśli jest
    if (_currentActiveSet != null) {
      await _endCurrentSet(startRest: false);
    }
    
    setState(() => _isSaving = true);

    final workoutData = {
      'planName': _planName,
      'duration_seconds': _totalWorkoutSeconds,
      'rest_time_seconds': _totalRestSeconds,
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
                  'duration_seconds': set.durationSeconds,
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
    
    // Zakończ sesję na serwerze
    if (_sessionId != null) {
      try {
        final sessionService = ref.read(workoutSessionServiceProvider);
        await sessionService.endSession(
          sessionId: _sessionId!,
          exercises: workoutData['exercises'] as List<Map<String, dynamic>>,
        );
      } catch (e) {
        print('Error ending session: $e');
      }
    }
    
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

  /// Dialog wyjścia z treningu
  Future<void> _showExitDialog() async {
    final lang = ref.read(languageProvider);
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang == 'pl' ? 'Wyjść z treningu?' : 'Exit workout?',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          lang == 'pl' 
              ? 'Trening jest w trakcie. Co chcesz zrobić?'
              : 'Workout is in progress. What do you want to do?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(lang == 'pl' ? 'Kontynuuj trening' : 'Continue workout'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'pause'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
            child: Text(lang == 'pl' ? 'Dokończ później' : 'Continue later'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'exit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: Text(lang == 'pl' ? 'Wyjdź bez zapisu' : 'Exit without saving'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text(lang == 'pl' ? 'Zapisz i wyjdź' : 'Save and exit'),
          ),
        ],
      ),
    );
    
    if (result == 'exit') {
      // Zakończ sesję bez zapisu
      if (_sessionId != null) {
        try {
          final sessionService = ref.read(workoutSessionServiceProvider);
          await sessionService.abandonSession(_sessionId!);
        } catch (e) {
          print('Error ending session: $e');
        }
      }
      if (mounted) Navigator.of(context).pop();
    } else if (result == 'pause') {
      // Wyjdź bez kończenia sesji - sesja zostaje aktywna do wznowienia
      _workoutTimer?.cancel();
      _restTimer?.cancel();
      _setTimer?.cancel();
      if (mounted) {
        final lang = ref.read(languageProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang == 'pl'
                ? 'Trening wstrzymany — wznów z ekranu głównego'
                : 'Workout paused — resume from home screen'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop('paused');
      }
    } else if (result == 'save') {
      await _finishWorkout();
    }
  }

 @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final theme = Theme.of(context);
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _showExitDialog();
      },
      child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 26),
          onPressed: _showExitDialog,
          tooltip: lang == 'pl' ? 'Wyjdź' : 'Exit',
        ),
        title: Text(_planName, style: const TextStyle(fontSize: 16)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'toggle_set_duration') {
                setState(() {
                  _showSetDuration = !_showSetDuration;
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_set_duration',
                child: Row(
                  children: [
                    Icon(
                      _showSetDuration ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _showSetDuration 
                          ? (lang == 'pl' ? 'Ukryj czas serii' : 'Hide set duration')
                          : (lang == 'pl' ? 'Pokaż czas serii' : 'Show set duration'),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      
      body: Stack(
        children: [
          Column(
            children: [
              // Workout stats bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.fitness_center,
                      _exerciseLogs?.length.toString() ?? '0',
                      lang == 'pl' ? 'Ćwiczeń' : 'Exercises',
                    ),
                    Container(width: 1, height: 30, color: Colors.white12),
                    _buildStatItem(
                      Icons.timer,
                      _formatTime(_totalWorkoutSeconds),
                      lang == 'pl' ? 'Czas' : 'Time',
                    ),
                    Container(width: 1, height: 30, color: Colors.white12),
                    _buildStatItem(
                      Icons.pause_circle_outline,
                      _formatTime(_totalRestSeconds),
                      lang == 'pl' ? 'Przerwy' : 'Rest',
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: _exerciseLogs == null
                    ? const Center(child: CircularProgressIndicator()) 
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: 16, 
                          right: 16, 
                          top: 16, 
                          bottom: _remainingSeconds > 0 || _currentActiveSet != null ? 120 : 16,
                        ),
                        itemCount: _exerciseLogs!.length,
                        itemBuilder: (context, index) {
                          final exercise = _exerciseLogs![index];
                          return _buildExerciseCard(exercise, index, lang);
                        },
                      ),
              ),
            ],
          ),
          
          // Floating set timer (gdy seria jest aktywna)
          if (_currentActiveSet != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildActiveSetTimer(lang),
            )
          // Rest timer (gdy przerwa)
          else if (_remainingSeconds > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildTimerWidget(),
            ),
        ],
      ),
    ),
    );
  }
  
  Widget _buildActiveSetTimer(String lang) {
    final theme = Theme.of(context);
    final set = _currentActiveSet;
    final exercise = _currentActiveExercise;
    
    if (set == null || exercise == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.9),
            theme.colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false, 
        child: Row(
          children: [
            // Animated timer circle
            if (_showSetDuration)
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(set.durationSeconds),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      lang == 'pl' ? 'seria' : 'set',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showSetDuration)
            const SizedBox(width: 20),
            
            // Exercise info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    exercise.exerciseData?.getName(lang) ?? exercise.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang == 'pl' 
                        ? 'Seria ${set.setNumber} w trakcie...' 
                        : 'Set ${set.setNumber} in progress...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Complete button
            FilledButton(
              onPressed: () async {
                await _endCurrentSet();
                setState(() {
                  set.isCompleted = true;
                });
                _startRestTimer();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 18),
                  const SizedBox(width: 6),
                  Text(lang == 'pl' ? 'Gotowe' : 'Done'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
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
                      child: ExerciseImage(
                        exerciseCode: exercise.code,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
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
                      child: ExerciseImage(
                        exerciseCode: exercise.code,
                        height: 180,
                        fit: BoxFit.contain,
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
                ...exercise.sets.asMap().entries.map((entry) => _buildSetRow(exercise, entry.value, entry.key + 1)),
                
                // Przyciski dodawania/usuwania serii
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Usuń serię
                    OutlinedButton.icon(
                      onPressed: exercise.sets.length > 1 
                          ? () => _removeSet(exercise, index)
                          : null,
                      icon: const Icon(Icons.remove, size: 16),
                      label: Text(lang == 'pl' ? 'Usuń serię' : 'Remove set'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                          color: exercise.sets.length > 1 ? Colors.redAccent.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Dodaj serię
                    OutlinedButton.icon(
                      onPressed: () => _addSet(exercise, index),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(lang == 'pl' ? 'Dodaj serię' : 'Add set'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildSetRow(ExerciseLog exercise, SetLog set, int displayNumber) {
    final theme = Theme.of(context);
    final bool isCompleted = set.isCompleted;
    final bool isInProgress = set.isInProgress;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$displayNumber',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isCompleted ? Colors.grey : (isInProgress ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color),
                    ),
                  ),
                  if (_showSetDuration && (set.durationSeconds > 0 || isInProgress))
                    Text(
                      _formatTime(set.durationSeconds),
                      style: TextStyle(
                        fontSize: 10,
                        color: isInProgress ? theme.colorScheme.primary : Colors.grey,
                        fontWeight: isInProgress ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                ],
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
              child: isInProgress
                ? // Gdy seria jest w trakcie - pokaż przycisk zakończ
                  IconButton(
                    icon: Icon(
                      Icons.stop_circle,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    onPressed: () async {
                      await _endCurrentSet();
                      setState(() {
                        set.isCompleted = true;
                      });
                      _startRestTimer();
                    },
                  )
                : isCompleted
                  ? // Seria ukończona
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() {
                          set.isCompleted = false;
                          set.durationSeconds = 0;
                        });
                        _stopRestTimer();
                      },
                    )
                  : // Seria nierozpoczęta - pokaż przycisk start
                    IconButton(
                      icon: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.grey,
                        size: 28,
                      ),
                      onPressed: () {
                        _startSet(exercise, set);
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false, 
        child: Row(
          children: [
            // Circular progress timer
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: _totalRestForCurrentBreak > 0 
                        ? _remainingSeconds / _totalRestForCurrentBreak 
                        : 0,
                    strokeWidth: 5,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _remainingSeconds > 10 ? theme.colorScheme.primary : Colors.orange,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      lang == 'pl' ? 'przerwa' : 'rest',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 20),
            
            // Info text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang == 'pl' ? 'Czas na odpoczynek' : 'Rest time',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang == 'pl' 
                        ? 'Przygotuj się do następnej serii' 
                        : 'Get ready for the next set',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            
            // Skip button
            FilledButton.tonal(
              onPressed: _stopRestTimer,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Text(AppTranslations.get('skip', lang)),
            ),
          ],
        ),
      ),
    );
  }
}