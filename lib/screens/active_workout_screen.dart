import 'dart:async'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';
import '../utils/converters.dart';




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

  ExerciseLog({required this.code, required this.name, required this.sets});

  void dispose() {
    for (var set in sets) {
      set.dispose();
    }
  }
  
  Map<String, dynamic> toMap() => {
    'code': code,
    'sets': sets.where((s) => s.isCompleted).map((s) => s.toMap()).toList(),
  };
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dobra robota! Trening zapisany.'),
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
                    : const Text('Zakończ'),
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
                      return _buildExerciseCard(exercise);
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

  Widget _buildExerciseCard(ExerciseLog exercise) {
    
    final unitLabel = _converter.unitLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.name, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  const Expanded(flex: 2, child: Text('Seria')),
                  Expanded(flex: 3, child: Text('Waga ($unitLabel)')), 
                  const Expanded(flex: 4, child: Center(child: Text('Powt.'))),
                  const Expanded(flex: 2, child: Center(child: Text('Done'))),
                ],
              ),
            ),
            ...exercise.sets.map((set) => _buildSetRow(set)), 
          ],
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
    final minutes = (_remainingSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      color: theme.colorScheme.surfaceVariant,
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
              child: const Text('Pomiń'),
            )
          ],
        ),
      ),
    );
  }
}