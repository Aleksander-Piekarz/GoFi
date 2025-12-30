import 'dart:io'; 
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gofi/screens/starting_screen.dart';
import 'package:pedometer/pedometer.dart';
import 'package:device_info_plus/device_info_plus.dart'; 
import 'package:intl/intl.dart'; 
import '../utils/converters.dart';
import 'profile_screen.dart';
import 'plan_view.dart';
import 'questionnaire_screen.dart';
import '../services/api/providers.dart'; 
import 'active_workout_screen.dart';
import 'workout_details_screen.dart'; 

// --- PROVIDERS ---

final planProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(authTokenProvider);
  
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

// --- HOME SCREEN ---

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
        title: const Text('GoFi', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statystyki',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Plan',
          ),
        ],
      ),
    );
  }
}

// --- TABS ---

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
              'Najlepiej ważyć się rano, na czczo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: weightCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Waga (${converter.unitLabel})', 
                suffixText: converter.unitLabel,
                border: const OutlineInputBorder(),
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
                ref.invalidate(weightHistoryProvider);
                if (context.mounted) Navigator.pop(ctx);
              } catch (e) {
                print('Błąd zapisu: $e');
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
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Wystąpił problem:\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  final auth = ref.read(authServiceProvider);
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const StartingScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Wyloguj się'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                ),
              ),
            ],
          ),
        ),
      ),
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
                    'Nie masz jeszcze planu. Wypełnij kwestionariusz.',
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
            Text('Witaj z powrotem!', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('Gotowy na trening?', style: textTheme.bodyLarge?.copyWith(color: Colors.grey)),
            
            const SizedBox(height: 24),
            Text('TWOJA AKTYWNOŚĆ', style: textTheme.labelLarge?.copyWith(letterSpacing: 1.0)),
            const SizedBox(height: 12),

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
            Text('DZISIEJSZY TRENING', style: textTheme.labelLarge?.copyWith(letterSpacing: 1.0)),
            const SizedBox(height: 12),
            if (todaysWorkout != null)
              _buildTodayWorkoutCard(context, todaysWorkout, unitSystem)
            else
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                child: const ListTile(
                  leading: Icon(Icons.coffee_outlined),
                  title: Text('Dzień wolny'),
                  subtitle: Text('Odpocznij i zregeneruj siły!'),
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
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Icon(Icons.directions_walk, color: theme.colorScheme.primary),
                 asyncSteps.when(
                  data: (steps) {
                     final progress = (stepGoal > 0 ? (steps / stepGoal) : 0.0).clamp(0.0, 1.0);
                     return SizedBox(
                       width: 24, height: 24,
                       child: CircularProgressIndicator(
                         value: progress,
                         strokeWidth: 3,
                         backgroundColor: theme.colorScheme.surfaceDim,
                       ),
                     );
                  },
                  loading: () => const SizedBox(),
                  error: (_,__) => const Icon(Icons.error, size: 16, color: Colors.red),
                 )
              ],
            ),
            const SizedBox(height: 12),
            const Text('Kroki', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            asyncSteps.when(
                data: (steps) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$steps', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Text('/ $stepGoal', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                  ],
                ),
                loading: () => const Text('...'),
                error: (_, __) => const Text('--'),
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
        : '--';

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _showLogWeightDialog(context, ref, converter),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.monitor_weight_outlined, color: theme.colorScheme.onPrimaryContainer),
                  Icon(Icons.add_circle, color: theme.colorScheme.onPrimaryContainer),
                ],
              ),
              const SizedBox(height: 12),
              Text('Waga', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, 
                    color: theme.colorScheme.onPrimaryContainer
                  ),
                  children: [
                    TextSpan(text: displayWeight),
                    TextSpan(
                      text: ' ${converter.unitLabel}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
              const Text(' ', style: TextStyle(fontSize: 12)), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayWorkoutCard(BuildContext context, Map workout, String unitSystem) {
    final title = (workout['day'] ?? workout['block'] ?? 'Trening').toString();
    final exercises = (workout['exercises'] as List?) ?? [];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${exercises.length} Ćwiczeń',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            exercises.take(3).map((e) => (e as Map)['name']).join(', ') + 
            (exercises.length > 3 ? '...' : ''),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
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
              child: const Text('Rozpocznij', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLogs = ref.watch(workoutLogsProvider);
    final asyncWeightHistory = ref.watch(weightHistoryProvider);
    final unitSystem = ref.watch(userProfileProvider).when(
          data: (profile) => profile['unitSystem'] as String? ?? 'metric',
          loading: () => 'metric',
          error: (_, __) => 'metric',
        );
    
    final converter = UnitConverter(unitSystem: unitSystem);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(workoutLogsProvider);
        ref.refresh(weightHistoryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Twoja Waga', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // --- WYKRES WAGI Z POPRAWKĄ DUBLUJĄCYCH SIĘ ETYKIET ---
          Container(
            height: 300,
            padding: const EdgeInsets.fromLTRB(8, 24, 24, 10), // Mniejszy padding z lewej
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: asyncWeightHistory.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('Błąd wykresu')),
              data: (history) {
                if (history.isEmpty) {
                  return const Center(child: Text('Brak pomiarów wagi.', style: TextStyle(color: Colors.grey)));
                }
                
                final sortedHistory = List.from(history);
                sortedHistory.sort((a, b) {
                  final da = DateTime.parse(a['date_logged'].toString());
                  final db = DateTime.parse(b['date_logged'].toString());
                  return da.compareTo(db);
                });

                final spots = <FlSpot>[];
                double minWeight = double.infinity;
                double maxWeight = double.negativeInfinity;

                final Map<String, double> dailyWeights = {};
                for (final entry in sortedHistory) {
                   final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(entry['date_logged'].toString()));
                   final w = double.tryParse(entry['weight'].toString()) ?? 0.0;
                   if (w > 0) dailyWeights[dateStr] = w;
                }
                
                final days = dailyWeights.keys.toList();
                
                if (days.isEmpty) return const Center(child: Text('Brak poprawnych danych.'));

                for (int i = 0; i < days.length; i++) {
                  final date = days[i];
                  final weightKg = dailyWeights[date]!;
                  final val = converter.displayWeight(weightKg);
                  
                  if (val < minWeight) minWeight = val;
                  if (val > maxWeight) maxWeight = val;

                  spots.add(FlSpot(i.toDouble(), val));
                }

                // Logika skali: jeśli różnica jest mała, pokazujemy z dokładnością do 1 miejsca
                double minY, maxY;
                final weightDiff = maxWeight - minWeight;
                final isSmallRange = weightDiff < 5.0;

                if (weightDiff == 0) {
                   minY = minWeight - 2;
                   maxY = maxWeight + 2;
                } else {
                   minY = (minWeight - (weightDiff * 0.2)).floorToDouble();
                   maxY = (maxWeight + (weightDiff * 0.2)).ceilToDouble();
                }
                if (minY < 0) minY = 0;

                return LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.colorScheme.onSurface.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 46, // Więcej miejsca na etykiety z przecinkiem
                          interval: isSmallRange ? (maxY - minY) / 4 : (maxY - minY) / 5,
                          getTitlesWidget: (val, meta) {
                             if (val == minY || val == maxY) return const SizedBox.shrink(); // Ukryj skrajne by nie ucinało
                             
                             // Jeśli zakres jest mały, używaj 1 miejsca po przecinku
                             if (isSmallRange) {
                               return Text(
                                 val.toStringAsFixed(1),
                                 style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                               );
                             }
                             // Standardowo liczby całkowite
                             return Text(
                               val.toStringAsFixed(0),
                               style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                             );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: spots.length > 5 ? (spots.length / 4).ceilToDouble() : 1,
                          getTitlesWidget: (val, meta) {
                            final index = val.toInt();
                            if (index < 0 || index >= days.length) return const SizedBox.shrink();
                            
                            final date = DateTime.parse(days[index]);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('d MMM', 'pl_PL').format(date),
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => theme.colorScheme.surface,
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y} ${converter.unitLabel}',
                              TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: theme.colorScheme.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: theme.colorScheme.surface,
                            strokeWidth: 3,
                            strokeColor: theme.colorScheme.primary,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.3),
                              theme.colorScheme.primary.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          Text('Historia Treningów', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          asyncLogs.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (e, _) => Center(
              child: TextButton.icon(
                onPressed: () => ref.refresh(workoutLogsProvider),
                icon: const Icon(Icons.refresh, color: Colors.grey),
                label: const Text('Odśwież', style: TextStyle(color: Colors.grey)),
              ),
            ),
            data: (logs) {
              if (logs.isEmpty) return const Text('Brak historii treningów.');
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (_,__) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final log = logs[i] as Map;
                  final logId = log['id'] as int;
                  final name = log['plan_name'] ?? 'Trening';
                  final date = DateTime.parse(log['date_completed'].toString());
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.check, color: theme.colorScheme.onSecondaryContainer),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('EEEE, d MMM yyyy', 'pl_PL').format(date)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutDetailsScreen(
                              logId: logId,
                              planName: name.toString(),
                              unitSystem: unitSystem,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- PLAN TAB ---

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