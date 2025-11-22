
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:device_info_plus/device_info_plus.dart'; 
import 'package:intl/intl.dart'; 
import '../utils/converters.dart';
import 'profile_screen.dart';
import '../services/api/questionnaire_service.dart';
import 'plan_view.dart';
import 'questionnaire_screen.dart';
import '../services/api/providers.dart'; 
import 'active_workout_screen.dart';
import 'workout_details_screen.dart'; 
import 'exercise_stats_screen.dart'; 



final planProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final svc = ref.read(questionnaireServiceProvider);
  final plan = await svc.getLatestPlan();
  if (plan.isEmpty) return null;
  return plan;
});


final stepCountProvider = StreamProvider<int>((ref) async* {
  bool isEmulator = false;
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    isEmulator = !androidInfo.isPhysicalDevice;
  }
  if (isEmulator) {
    yield 0;
    return; 
  }
  try {
    await for (final stepCount in Pedometer.stepCountStream) {
      yield stepCount.steps;
    }
  } catch (e) {
    print('Błąd strumienia kroków: $e');
    if (e.toString().contains('Permission denied')) {
       throw 'Brak uprawnień do liczenia kroków. Włącz je w ustawieniach.';
    }
    throw 'Nie można pobrać kroków. Sprawdź uprawnienia w ustawieniach telefonu.';
  }
});


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('GoFi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(planProvider: planProvider),
          const _StatsTab(),
          _PlanTab(planProvider: planProvider),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: theme.colorScheme.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Statystyki',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Plan',
          ),
        ],
      ),
    );
  }
}


class _HomeTab extends ConsumerWidget {
  final FutureProvider<Map<String, dynamic>?> planProvider;
  const _HomeTab({required this.planProvider});

  
  void _showLogWeightDialog(BuildContext context, WidgetRef ref, UnitConverter converter) {
    final weightCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zapisz wagę'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Najlepiej ważyć się rano, na czczo i po wizycie w toalecie, aby pomiar był jak najbardziej wiarygodny.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: weightCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Waga (${converter.unitLabel})', 
                suffixText: converter.unitLabel,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () async {
              final displayValue = double.tryParse(weightCtrl.text); 
              if (displayValue == null || displayValue <= 0) return;
              
              
              final kgToSave = converter.saveWeight(displayValue);

              try {
                await ref.read(logServiceProvider).saveWeight(kgToSave); 
                ref.invalidate(userProfileProvider);
                if (context.mounted) Navigator.pop(ctx);
              } catch (e) {
                
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlan = ref.watch(planProvider);
    final asyncSteps = ref.watch(stepCountProvider);
    final asyncProfile = ref.watch(userProfileProvider);
    final textTheme = Theme.of(context).textTheme;

    return asyncPlan.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Błąd ładowania: $err')),
      data: (plan) {
        
        final (int stepGoal, String unitSystem, double? latestWeight) = asyncProfile.when(
          data: (profile) {
            final goal = profile['dailySteps'] as int? ?? 10000;
            final unit = profile['unitSystem'] as String? ?? 'metric';
            final weight = (profile['latestWeight'] == null) 
              ? null 
              : double.tryParse(profile['latestWeight'].toString());
            return (goal, unit, weight);
          },
          loading: () => (10000, 'metric', null),
          error: (e, s) => (10000, 'metric', null),
        );
        final converter = UnitConverter(unitSystem: unitSystem);

        if (plan == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Witaj w GoFi!', style: textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  const Text(
                    'Wygląda na to, że nie masz jeszcze planu. Wypełnij kwestionariusz, abyśmy mogli go dla Ciebie przygotować.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Wypełnij kwestionariusz'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
                      );
                    },
                  )
                ],
              ),
            ),
          );
        }

        final today = DateTime.now().weekday;
        final week = (plan['week'] as List?) ?? [];
        Map? todaysWorkout;
        if (week.isNotEmpty) {
          final dayMap = { 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun' };
          final todayKey = dayMap[today];
          todaysWorkout = week.firstWhere(
            (d) => (d['day'] as String?)?.startsWith(todayKey ?? '') ?? false,
            orElse: () => null,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Witaj z powrotem!', style: textTheme.headlineMedium),
            Text('Gotowy na dzisiejszy trening?', style: textTheme.bodyLarge),
            
            const SizedBox(height: 24),
            Text('TWOJA AKTYWNOŚĆ', style: textTheme.labelLarge),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildActivityCard(context, asyncSteps, stepGoal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWeightLogCard(context, ref, latestWeight, converter),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text('DZISIEJSZY TRENING', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            if (todaysWorkout != null)
              _buildTodayWorkoutCard(context, todaysWorkout, unitSystem)
            else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.coffee_outlined),
                  title: Text('Dzień wolny'),
                  subtitle: Text('Brak zaplanowanego treningu na dzisiaj.'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActivityCard(BuildContext context, AsyncValue<int> asyncSteps, int stepGoal) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: asyncSteps.when(
                data: (steps) {
                  final progress = (stepGoal > 0 ? (steps / stepGoal) : 0.0).clamp(0.0, 1.0);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        color: theme.colorScheme.primary,
                      ),
                      Icon(Icons.directions_walk, size: 24)
                    ],
                  );
                },
                loading: () => CircularProgressIndicator(
                  strokeWidth: 5,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                ),
                error: (_, __) => Icon(Icons.error_outline,
                    color: theme.colorScheme.error, size: 30),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: asyncSteps.when(
                data: (steps) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$steps', style: theme.textTheme.headlineSmall),
                    Text('z $stepGoal', style: theme.textTheme.bodySmall),
                  ],
                ),
                loading: () => const Text('Ładuję...'),
                error: (err, __) => Text(
                  'Błąd',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildWeightLogCard(BuildContext context, WidgetRef ref, double? latestWeightKg, UnitConverter converter) {
    final theme = Theme.of(context);
    
    
    final String displayWeight = latestWeightKg != null
        ? converter.displayWeight(latestWeightKg).toString()
        : '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(/* ... (ikona bez zmian) ... */),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$displayWeight${converter.unitLabel}', 
                    style: theme.textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text('Ostatnia waga', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: theme.colorScheme.primary, size: 30),
              onPressed: () {
                _showLogWeightDialog(context, ref, converter); 
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTodayWorkoutCard(BuildContext context, Map workout, String unitSystem) {
     final title = (workout['day'] ?? workout['block'] ?? 'Trening').toString();
    final exercises = (workout['exercises'] as List?) ?? [];
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 8),
            Text(
              '${exercises.length} ćwiczeń do wykonania:',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            ...exercises.take(3).map((e) => Text(
                  '• ${(e as Map)['name']}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                  overflow: TextOverflow.ellipsis,
                )),
            if (exercises.length > 3)
              Text('• ...i ${exercises.length - 3} więcej',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveWorkoutScreen(
                        workout: workout,
                        unitSystem: unitSystem,
                      ),
                    ),
                  );
                },
                child: const Text('Rozpocznij'),
              ),
            )
          ],
        ),
      ),
    );
  }
}


class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLogs = ref.watch(workoutLogsProvider);
    final unitSystem = ref.watch(userProfileProvider).when(
          data: (profile) => profile['unitSystem'] as String? ?? 'metric',
          loading: () => 'metric',
          error: (_, __) => 'metric',
        );

    return asyncLogs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Błąd ładowania statystyk: $err')),
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Nie zalogowałeś jeszcze żadnego treningu. Ukończ trening, aby zobaczyć tutaj swoją historię!',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(workoutLogsProvider.future),
          child: ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index] as Map;
              final logId = log['id'] as int;
              final planName = log['plan_name']?.toString() ?? 'Trening';
              
              String dateStr = 'Brak daty';
              if (log['date_completed'] != null) {
                final date = DateTime.parse(log['date_completed'] as String);
                dateStr = DateFormat('E, d MMM yyyy', 'pl_PL').format(date);
              }

              return ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(planName),
                subtitle: Text(dateStr),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutDetailsScreen(
                        logId: logId,
                        planName: planName,
                        unitSystem: unitSystem,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}



class _PlanTab extends ConsumerStatefulWidget {
  final FutureProvider<Map<String, dynamic>?> planProvider;
  const _PlanTab({required this.planProvider});

  @override
  ConsumerState<_PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends ConsumerState<_PlanTab> {
  Map<String, dynamic>? _editablePlan;

  void _updateExercise(
    int dayIndex,
    int exerciseIndex,
    Map<String, dynamic> newValues,
  ) {
    if (_editablePlan == null) return;
    try {
      final List week = (_editablePlan!['week'] as List);
      final Map day = week[dayIndex];
      final List exercises = (day['exercises'] as List);
      
      setState(() {
        exercises[exerciseIndex] = Map<String, dynamic>.from(newValues);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zapisano zmiany lokalnie.'), duration: Duration(seconds: 1)),
      );

    } catch (e) {
      print('Błąd podczas aktualizacji ćwiczenia: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPlan = ref.watch(widget.planProvider);
    final unitSystem = ref.watch(userProfileProvider).when(
          data: (profile) => profile['unitSystem'] as String? ?? 'metric',
          loading: () => 'metric',
          error: (_, __) => 'metric',
        );

    return asyncPlan.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) {
        _editablePlan = null;
        return Center(
          child: Text('Błąd pobierania planu:\n$err', textAlign: TextAlign.center),
        );
      },
      data: (plan) {
        if (plan == null) {
          _editablePlan = null;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Brak aktywnego planu',
                     style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Wypełnij kwestionariusz, aby wygenerować swój pierwszy plan treningowy.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Wypełnij kwestionariusz'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }

        if (_editablePlan == null || plan['split'] != _editablePlan!['split']) {
          _editablePlan = Map<String, dynamic>.from(plan.map(
            (key, value) => MapEntry(
                key,
                value is List
                    ? List.from(value.map((item) =>
                        item is Map ? Map<String, dynamic>.from(item) : item))
                    : value),
          ));
           if (_editablePlan!['week'] != null) {
            _editablePlan!['week'] = (plan['week'] as List).map((day) {
              final newDay = Map<String, dynamic>.from(day as Map);
              if (newDay['exercises'] != null) {
                newDay['exercises'] = (newDay['exercises'] as List)
                    .map((ex) => Map<String, dynamic>.from(ex as Map))
                    .toList();
              }
              return newDay;
            }).toList();
          }
        }

        return RefreshIndicator(
          onRefresh: () async {
            _editablePlan = null;
            return ref.refresh(widget.planProvider);
          },
          child: PlanView(
            plan: _editablePlan!,
            onExerciseChanged: _updateExercise,
            unitSystem: unitSystem,
          ),
        );
      },
    );
  }
}