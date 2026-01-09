import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';
import '../utils/converters.dart';
import '../app/theme.dart';

// ===== TIMELINE EVENT MODELS =====

enum WorkoutEventType {
  startWorkout,
  startExercise,
  completeSet,
  startRest,
  endRest,
  skipRest,
  finishWorkout,
}

class WorkoutEvent {
  final DateTime timestamp;
  final WorkoutEventType type;
  final Map<String, dynamic>? data;

  WorkoutEvent({
    required this.timestamp,
    required this.type,
    this.data,
  });

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    if (data != null) 'data': data,
  };
}

// ===== SET & EXERCISE LOG MODELS =====

class SetLog {
  final int setNumber;
  final String suggestedReps;
  final TextEditingController weightController = TextEditingController();
  int reps;
  bool isCompleted = false;
  DateTime? completedAt;

  SetLog({required this.setNumber, required this.suggestedReps})
      : reps = int.tryParse(suggestedReps.split('-').first) ?? 8;

  void dispose() {
    weightController.dispose();
  }

  Map<String, dynamic> toMap() => {
    'reps': reps.toString(),
    'weight': weightController.text.isEmpty ? '0' : weightController.text,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };
}

class ExerciseLog {
  final String code;
  final String name;
  final String? type;
  final String? equipment;
  final List<SetLog> sets;
  DateTime? startedAt;

  ExerciseLog({
    required this.code,
    required this.name,
    this.type,
    this.equipment,
    required this.sets,
  });

  void dispose() {
    for (var set in sets) {
      set.dispose();
    }
  }

  int get completedSetsCount => sets.where((s) => s.isCompleted).length;
  bool get isCompleted => sets.every((s) => s.isCompleted);

  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    if (type != null) 'type': type,
    if (equipment != null) 'equipment': equipment,
    'sets': sets.where((s) => s.isCompleted).map((s) => s.toMap()).toList(),
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
  };
}



// ===== MAIN SCREEN =====

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  final Map workout;
  final String unitSystem;
  const ActiveWorkoutScreen({super.key, required this.workout, required this.unitSystem});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  // State
  List<ExerciseLog>? _exerciseLogs;
  late String _planName;
  late UnitConverter _converter;
  bool _isSaving = false;
  
  // Workflow state
  bool _workoutStarted = false;
  int _currentExerciseIndex = 0;
  DateTime? _workoutStartTime;
  Duration _totalDuration = Duration.zero;
  
  // Timeline events
  final List<WorkoutEvent> _timeline = [];

  // Timer
  static const int _defaultRestTime = 90;
  Timer? _restTimer;
  Timer? _workoutTimer;
  int _remainingRestSeconds = 0;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Page controller
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _converter = UnitConverter(unitSystem: widget.unitSystem);
    _planName = (widget.workout['day'] ?? widget.workout['block'] ?? 'Trening').toString();
    _pageController = PageController();
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
      final String? type = exercise['pattern']?.toString();
      final String? equipment = exercise['equipment']?.toString();

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
        type: type,
        equipment: equipment,
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

    if (mounted) {
      setState(() {
        _exerciseLogs = newLogs;
      });
    }
  }

  @override
  void dispose() {
    if (_exerciseLogs != null) {
      for (var ex in _exerciseLogs!) {
        ex.dispose();
      }
    }
    _restTimer?.cancel();
    _workoutTimer?.cancel();
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ===== TIMELINE METHODS =====

  void _addEvent(WorkoutEventType type, {Map<String, dynamic>? data}) {
    _timeline.add(WorkoutEvent(
      timestamp: DateTime.now(),
      type: type,
      data: data,
    ));
  }

  // ===== WORKOUT FLOW =====

  void _startWorkout() {
    setState(() {
      _workoutStarted = true;
      _workoutStartTime = DateTime.now();
      _currentExerciseIndex = 0;
    });
    
    _addEvent(WorkoutEventType.startWorkout);
    _startWorkoutTimer();
    
    if (_exerciseLogs != null && _exerciseLogs!.isNotEmpty) {
      _exerciseLogs![0].startedAt = DateTime.now();
      _addEvent(WorkoutEventType.startExercise, data: {
        'exerciseCode': _exerciseLogs![0].code,
        'exerciseName': _exerciseLogs![0].name,
      });
    }
  }

  void _startWorkoutTimer() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_workoutStartTime != null) {
        setState(() {
          _totalDuration = DateTime.now().difference(_workoutStartTime!);
        });
      }
    });
  }

  void _completeSet(SetLog set, ExerciseLog exercise) {
    final now = DateTime.now();
    setState(() {
      set.isCompleted = true;
      set.completedAt = now;
    });

    final displayWeight = double.tryParse(set.weightController.text) ?? 0.0;
    final weightKg = _converter.saveWeight(displayWeight);

    _addEvent(WorkoutEventType.completeSet, data: {
      'exerciseCode': exercise.code,
      'setNumber': set.setNumber,
      'weight': weightKg,
      'reps': set.reps,
    });

    _startRestTimer();
  }

  void _undoSet(SetLog set) {
    setState(() {
      set.isCompleted = false;
      set.completedAt = null;
    });
    _stopRestTimer();
  }

  void _goToNextExercise() {
    if (_exerciseLogs == null) return;
    
    if (_currentExerciseIndex < _exerciseLogs!.length - 1) {
      setState(() {
        _currentExerciseIndex++;
      });
      
      _exerciseLogs![_currentExerciseIndex].startedAt = DateTime.now();
      _addEvent(WorkoutEventType.startExercise, data: {
        'exerciseCode': _exerciseLogs![_currentExerciseIndex].code,
        'exerciseName': _exerciseLogs![_currentExerciseIndex].name,
      });
      
      _pageController.animateToPage(
        _currentExerciseIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousExercise() {
    if (_currentExerciseIndex > 0) {
      setState(() {
        _currentExerciseIndex--;
      });
      _pageController.animateToPage(
        _currentExerciseIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ===== REST TIMER =====

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _remainingRestSeconds = _defaultRestTime;
    });

    _addEvent(WorkoutEventType.startRest);

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingRestSeconds > 0) {
        setState(() {
          _remainingRestSeconds--;
        });
      } else {
        _restTimer?.cancel();
        _addEvent(WorkoutEventType.endRest);
        _playTimerSound();
      }
    });
  }

  void _stopRestTimer() {
    if (_remainingRestSeconds > 0) {
      _addEvent(WorkoutEventType.skipRest);
    }
    _restTimer?.cancel();
    setState(() {
      _remainingRestSeconds = 0;
    });
  }

  Future<void> _playTimerSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/timer_done.mp3'));
    } catch (e) {
      print('Błąd odtwarzania dźwięku: $e');
    }
  }

  // ===== FINISH WORKOUT =====

  Future<void> _finishWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zakończ trening?'),
        content: Text(
          'Czas treningu: ${_formatDuration(_totalDuration)}\n'
          'Wykonane serie: ${_getTotalCompletedSets()}/${_getTotalSets()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kontynuuj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zakończ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    _addEvent(WorkoutEventType.finishWorkout);
    _workoutTimer?.cancel();
    _restTimer?.cancel();

    final workoutData = {
      'planName': _planName,
      'startTime': _workoutStartTime?.toIso8601String(),
      'endTime': DateTime.now().toIso8601String(),
      'durationSeconds': _totalDuration.inSeconds,
      'timeline': _timeline.map((e) => e.toMap()).toList(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Świetna robota! Trening ukończony w ${_formatDuration(_totalDuration)}',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Błąd zapisu treningu: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===== HELPERS =====

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _getTotalCompletedSets() {
    if (_exerciseLogs == null) return 0;
    return _exerciseLogs!.fold(0, (sum, ex) => sum + ex.completedSetsCount);
  }

  int _getTotalSets() {
    if (_exerciseLogs == null) return 0;
    return _exerciseLogs!.fold(0, (sum, ex) => sum + ex.sets.length);
  }

  // ===== BUILD =====

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_exerciseLogs == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_planName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_exerciseLogs!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_planName)),
        body: const Center(
          child: Text('Brak ćwiczeń w tym treningu'),
        ),
      );
    }

    if (!_workoutStarted) {
      return _buildStartScreen(theme);
    }

    return _buildActiveWorkoutScreen(theme);
  }

  Widget _buildStartScreen(ThemeData theme) {
    final exerciseCount = _exerciseLogs!.length;
    final totalSets = _getTotalSets();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              
              const Spacer(),
              
              Text(
                'Gotowy na',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _planName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.fitness_center,
                    label: '$exerciseCount ćwiczeń',
                    theme: theme,
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    icon: Icons.repeat,
                    label: '$totalSets serii',
                    theme: theme,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: _exerciseLogs!.take(5).map((ex) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ex.name,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${ex.sets.length} x ${ex.sets.first.suggestedReps}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              if (_exerciseLogs!.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${_exerciseLogs!.length - 5} więcej...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton(
                  onPressed: _startWorkout,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Rozpocznij trening',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWorkoutScreen(ThemeData theme) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildProgressIndicator(theme),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exerciseLogs!.length,
                onPageChanged: (index) {
                  setState(() => _currentExerciseIndex = index);
                },
                itemBuilder: (context, index) {
                  return _buildExercisePage(_exerciseLogs![index], theme);
                },
              ),
            ),
            if (_remainingRestSeconds > 0)
              _buildRestTimerWidget(theme),
            _buildNavigation(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Przerwać trening?'),
                  content: const Text('Twój postęp nie zostanie zapisany.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Kontynuuj'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Przerwij'),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.close),
          ),
          
          Expanded(
            child: Column(
              children: [
                Text(
                  _planName,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_totalDuration),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          FilledButton.tonal(
            onPressed: _isSaving ? null : _finishWorkout,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Zakończ'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_exerciseLogs!.length, (index) {
          final exercise = _exerciseLogs![index];
          final isCurrent = index == _currentExerciseIndex;
          final isCompleted = exercise.isCompleted;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success
                            : isCurrent
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExercisePage(ExerciseLog exercise, ThemeData theme) {
    final unitLabel = _converter.unitLabel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (exercise.type != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatExerciseType(exercise.type!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    Text(
                      exercise.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (exercise.equipment != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              _getEquipmentIcon(exercise.equipment!),
                              size: 16,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatEquipment(exercise.equipment!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: exercise.sets.isEmpty
                          ? 0
                          : exercise.completedSetsCount / exercise.sets.length,
                      strokeWidth: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: AppColors.success,
                    ),
                    Text(
                      '${exercise.completedSetsCount}/${exercise.sets.length}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Expanded(flex: 1, child: Text('Seria', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(flex: 2, child: Text('Ciężar ($unitLabel)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                const Expanded(flex: 2, child: Center(child: Text('Powtórzenia', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))),
                const SizedBox(width: 56),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          ...exercise.sets.map((set) => _buildSetRow(set, exercise, theme)),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSetRow(SetLog set, ExerciseLog exercise, ThemeData theme) {
    final bool isCompleted = set.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.successLight
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 1,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                        '${set.setNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: set.weightController,
                textAlign: TextAlign.center,
                enabled: !isCompleted,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? AppColors.success : null,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0',
                  filled: true,
                  fillColor: isCompleted
                      ? Colors.transparent
                      : theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRepButton(
                  icon: Icons.remove,
                  onPressed: isCompleted
                      ? null
                      : () {
                          if (set.reps > 0) {
                            setState(() => set.reps--);
                          }
                        },
                  theme: theme,
                ),
                Container(
                  width: 48,
                  alignment: Alignment.center,
                  child: Text(
                    '${set.reps}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? AppColors.success : null,
                    ),
                  ),
                ),
                _buildRepButton(
                  icon: Icons.add,
                  onPressed: isCompleted
                      ? null
                      : () {
                          setState(() => set.reps++);
                        },
                  theme: theme,
                ),
              ],
            ),
          ),

          SizedBox(
            width: 56,
            child: isCompleted
                ? IconButton(
                    onPressed: () => _undoSet(set),
                    icon: const Icon(Icons.undo, color: AppColors.success),
                    tooltip: 'Cofnij',
                  )
                : FilledButton(
                    onPressed: () => _completeSet(set, exercise),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.check, size: 20),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ThemeData theme,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: onPressed != null
              ? theme.colorScheme.surfaceContainerHighest
              : Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildRestTimerWidget(ThemeData theme) {
    final minutes = (_remainingRestSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (_remainingRestSeconds % 60).toString().padLeft(2, '0');
    final progress = _remainingRestSeconds / _defaultRestTime;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  color: theme.colorScheme.primary,
                ),
                Text(
                  '$minutes:$seconds',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Odpoczynek',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Przygotuj się do następnej serii',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _stopRestTimer,
            child: const Text('Pomiń'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation(ThemeData theme) {
    final isFirstExercise = _currentExerciseIndex == 0;
    final isLastExercise = _currentExerciseIndex == _exerciseLogs!.length - 1;
    final currentExercise = _exerciseLogs![_currentExerciseIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isFirstExercise ? null : _goToPreviousExercise,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Poprzednie'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isLastExercise
                    ? (currentExercise.isCompleted ? _finishWorkout : null)
                    : _goToNextExercise,
                icon: Icon(isLastExercise ? Icons.flag : Icons.arrow_forward),
                label: Text(isLastExercise ? 'Zakończ' : 'Następne'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== HELPER FORMATTERS =====

  String _formatExerciseType(String type) {
    final types = {
      'knee_dominant': 'Nogi (kolana)',
      'hip_dominant': 'Nogi (biodra)',
      'push_horizontal': 'Pchnięcie poziome',
      'push_vertical': 'Pchnięcie pionowe',
      'pull_horizontal': 'Ciągnięcie poziome',
      'pull_vertical': 'Ciągnięcie pionowe',
      'isolation': 'Izolacja',
      'core': 'Core / Brzuch',
      'carry': 'Carry',
      'full_body': 'Full body',
      'olympic_lift': 'Podnoszenie olimpijskie',
    };
    return types[type] ?? type.replaceAll('_', ' ');
  }

  String _formatEquipment(String equipment) {
    final equipments = {
      'barbell': 'Sztanga',
      'dumbbell': 'Hantle',
      'kettlebell': 'Kettlebell',
      'cable': 'Wyciąg',
      'machine': 'Maszyna',
      'bodyweight': 'Ciężar ciała',
      'other': 'Inne',
    };
    return equipments[equipment] ?? equipment;
  }

  IconData _getEquipmentIcon(String equipment) {
    final icons = {
      'barbell': Icons.fitness_center,
      'dumbbell': Icons.fitness_center,
      'kettlebell': Icons.fitness_center,
      'cable': Icons.cable,
      'machine': Icons.precision_manufacturing,
      'bodyweight': Icons.accessibility_new,
      'other': Icons.sports_gymnastics,
    };
    return icons[equipment] ?? Icons.fitness_center;
  }
}