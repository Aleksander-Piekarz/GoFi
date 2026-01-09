import 'dart:io';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gofi/screens/starting_screen.dart';
import 'package:pedometer/pedometer.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import '../utils/converters.dart';
import '../app/theme.dart';
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

// Provider dla biblioteki ćwiczeń
final exerciseLibraryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final String jsonString = await rootBundle.loadString('assets/exercises.json');
    final List<dynamic> data = json.decode(jsonString);
    return data.cast<Map<String, dynamic>>();
  } catch (e) {
    print('Błąd ładowania ćwiczeń: $e');
    return [];
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('GoFi', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.primary),
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
          const _LibraryTab(),
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
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Biblioteka',
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
          // ===== SEKCJA 1: PARAMETRY CIAŁA =====
          _buildSectionHeader(
            context,
            icon: Icons.monitor_weight_outlined,
            title: 'Parametry Ciała',
            subtitle: 'Historia pomiarów wagi',
          ),
          const SizedBox(height: 16),
          _buildWeightChart(context, asyncWeightHistory, converter, theme),
          
          const SizedBox(height: 32),
          
          // ===== SEKCJA 2: OBJĘTOŚĆ TRENINGOWA =====
          _buildSectionHeader(
            context,
            icon: Icons.fitness_center,
            title: 'Objętość Treningowa',
            subtitle: 'Całkowity podniesiony ciężar',
          ),
          const SizedBox(height: 16),
          _buildVolumeSection(context, asyncLogs, converter, theme),
          
          const SizedBox(height: 32),
          
          // ===== SEKCJA 3: FREKWENCJA =====
          _buildSectionHeader(
            context,
            icon: Icons.calendar_today,
            title: 'Frekwencja',
            subtitle: 'Regularność treningów',
          ),
          const SizedBox(height: 16),
          _buildFrequencySection(context, asyncLogs, theme),
          
          const SizedBox(height: 32),
          
          // ===== SEKCJA 4: HISTORIA TRENINGÓW =====
          _buildSectionHeader(
            context,
            icon: Icons.history,
            title: 'Historia Treningów',
            subtitle: 'Ostatnie sesje treningowe',
          ),
          const SizedBox(height: 16),
          _buildWorkoutHistory(context, asyncLogs, unitSystem, theme, ref),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeightChart(
    BuildContext context,
    AsyncValue<List<dynamic>> asyncWeightHistory,
    UnitConverter converter,
    ThemeData theme,
  ) {
    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(8, 24, 24, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: asyncWeightHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
              const SizedBox(height: 8),
              Text('Błąd wykresu', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
        data: (history) {
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.scale_outlined, color: theme.colorScheme.outline, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Brak pomiarów wagi',
                    style: TextStyle(color: theme.colorScheme.outline, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dodaj pierwszy pomiar na ekranie głównym',
                    style: TextStyle(color: theme.colorScheme.outline.withOpacity(0.7), fontSize: 12),
                  ),
                ],
              ),
            );
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
          
          if (days.isEmpty) {
            return Center(
              child: Text('Brak poprawnych danych.', style: TextStyle(color: theme.colorScheme.outline)),
            );
          }

          for (int i = 0; i < days.length; i++) {
            final date = days[i];
            final weightKg = dailyWeights[date]!;
            final val = converter.displayWeight(weightKg);
            
            if (val < minWeight) minWeight = val;
            if (val > maxWeight) maxWeight = val;

            spots.add(FlSpot(i.toDouble(), val));
          }

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
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    interval: isSmallRange ? (maxY - minY) / 4 : (maxY - minY) / 5,
                    getTitlesWidget: (val, meta) {
                       if (val == minY || val == maxY) return const SizedBox.shrink();
                       if (isSmallRange) {
                         return Text(
                           val.toStringAsFixed(1),
                           style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                         );
                       }
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
                        '${spot.y.toStringAsFixed(1)} ${converter.unitLabel}',
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
                        theme.colorScheme.primary.withOpacity(0.2),
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
    );
  }

  Widget _buildVolumeSection(
    BuildContext context,
    AsyncValue<List<dynamic>> asyncLogs,
    UnitConverter converter,
    ThemeData theme,
  ) {
    return asyncLogs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildEmptyState(theme, 'Błąd ładowania danych'),
      data: (logs) {
        if (logs.isEmpty) {
          return _buildEmptyState(theme, 'Brak danych treningowych');
        }

        // Oblicz volume z logów
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final monthStart = DateTime(now.year, now.month, 1);

        double weeklyVolume = 0;
        double monthlyVolume = 0;
        double totalVolume = 0;
        
        // Obliczenia volume tygodniowego po dniach
        final Map<String, double> dailyVolume = {};
        
        for (final log in logs) {
          final dateStr = log['date_completed']?.toString();
          if (dateStr == null) continue;
          
          final date = DateTime.parse(dateStr);
          final dayKey = DateFormat('yyyy-MM-dd').format(date);
          
          // Pobierz exercises z loga (jeśli są dostępne)
          final exercises = log['exercises'] as List? ?? [];
          double logVolume = 0;
          
          for (final ex in exercises) {
            final sets = (ex as Map)['sets'] as List? ?? [];
            for (final set in sets) {
              final weight = double.tryParse((set as Map)['weight']?.toString() ?? '0') ?? 0;
              final reps = int.tryParse(set['reps']?.toString() ?? '0') ?? 0;
              logVolume += weight * reps;
            }
          }
          
          // Jeśli nie ma szczegółowych danych, użyj szacowanego volume
          if (logVolume == 0) {
            logVolume = 2000; // Szacunkowa wartość
          }
          
          totalVolume += logVolume;
          dailyVolume[dayKey] = (dailyVolume[dayKey] ?? 0) + logVolume;
          
          if (date.isAfter(weekStart.subtract(const Duration(days: 1)))) {
            weeklyVolume += logVolume;
          }
          if (date.isAfter(monthStart.subtract(const Duration(days: 1)))) {
            monthlyVolume += logVolume;
          }
        }

        final displayWeeklyVolume = converter.displayWeight(weeklyVolume);
        final displayMonthlyVolume = converter.displayWeight(monthlyVolume);

        return Column(
          children: [
            // Volume cards
            Row(
              children: [
                Expanded(
                  child: _buildVolumeCard(
                    context,
                    title: 'Ten tydzień',
                    value: '${_formatVolume(displayWeeklyVolume)} ${converter.unitLabel}',
                    color: theme.colorScheme.primary,
                    icon: Icons.calendar_view_week,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildVolumeCard(
                    context,
                    title: 'Ten miesiąc',
                    value: '${_formatVolume(displayMonthlyVolume)} ${converter.unitLabel}',
                    color: AppColors.accentSecondary,
                    icon: Icons.calendar_month,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Weekly volume chart
            _buildWeeklyVolumeChart(context, dailyVolume, converter, theme),
          ],
        );
      },
    );
  }

  Widget _buildVolumeCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyVolumeChart(
    BuildContext context,
    Map<String, double> dailyVolume,
    UnitConverter converter,
    ThemeData theme,
  ) {
    final now = DateTime.now();
    final weekDays = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return DateFormat('yyyy-MM-dd').format(date);
    });
    
    final dayNames = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];
    
    double maxVolume = 0;
    for (final day in weekDays) {
      final vol = dailyVolume[day] ?? 0;
      if (vol > maxVolume) maxVolume = vol;
    }
    if (maxVolume == 0) maxVolume = 1000;

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Objętość ostatnich 7 dni',
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final dayKey = weekDays[i];
                final volume = dailyVolume[dayKey] ?? 0;
                final displayVolume = converter.displayWeight(volume);
                final height = maxVolume > 0 ? (volume / maxVolume) * 80 : 0.0;
                final date = DateTime.parse(dayKey);
                final dayIndex = (date.weekday - 1) % 7;
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (volume > 0)
                      Text(
                        _formatVolume(displayVolume),
                        style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: height.clamp(4, 80),
                      decoration: BoxDecoration(
                        color: volume > 0 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.outline.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dayNames[dayIndex],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencySection(
    BuildContext context,
    AsyncValue<List<dynamic>> asyncLogs,
    ThemeData theme,
  ) {
    return asyncLogs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildEmptyState(theme, 'Błąd ładowania danych'),
      data: (logs) {
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final monthStart = DateTime(now.year, now.month, 1);
        
        int weeklyCount = 0;
        int monthlyCount = 0;
        
        for (final log in logs) {
          final dateStr = log['date_completed']?.toString();
          if (dateStr == null) continue;
          
          final date = DateTime.parse(dateStr);
          
          if (date.isAfter(weekStart.subtract(const Duration(days: 1)))) {
            weeklyCount++;
          }
          if (date.isAfter(monthStart.subtract(const Duration(days: 1)))) {
            monthlyCount++;
          }
        }
        
        // Określ cel (domyślnie 4 treningi tygodniowo)
        const weeklyGoal = 4;
        final monthlyGoal = (weeklyGoal * 4.3).round();
        
        return Row(
          children: [
            Expanded(
              child: _buildFrequencyCard(
                context,
                title: 'Ten tydzień',
                current: weeklyCount,
                goal: weeklyGoal,
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFrequencyCard(
                context,
                title: 'Ten miesiąc',
                current: monthlyCount,
                goal: monthlyGoal,
                theme: theme,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFrequencyCard(
    BuildContext context, {
    required String title,
    required int current,
    required int goal,
    required ThemeData theme,
  }) {
    final progress = (current / goal).clamp(0.0, 1.0);
    final isGoalMet = current >= goal;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: theme.colorScheme.outline.withOpacity(0.1),
                  color: isGoalMet ? AppColors.success : theme.colorScheme.primary,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$current',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isGoalMet ? AppColors.success : theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '/ $goal',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isGoalMet)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'Cel osiągnięty!',
                  style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                ),
              ],
            )
          else
            Text(
              'Jeszcze ${goal - current}',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkoutHistory(
    BuildContext context,
    AsyncValue<List<dynamic>> asyncLogs,
    String unitSystem,
    ThemeData theme,
    WidgetRef ref,
  ) {
    return asyncLogs.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (e, _) => Center(
        child: TextButton.icon(
          onPressed: () => ref.refresh(workoutLogsProvider),
          icon: Icon(Icons.refresh, color: theme.colorScheme.outline),
          label: Text('Odśwież', style: TextStyle(color: theme.colorScheme.outline)),
        ),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Icon(Icons.fitness_center, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 12),
                Text(
                  'Brak historii treningów',
                  style: TextStyle(color: theme.colorScheme.outline, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ukończ pierwszy trening, aby zobaczyć historię',
                  style: TextStyle(color: theme.colorScheme.outline.withOpacity(0.7), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length.clamp(0, 10),
          separatorBuilder: (_,__) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final log = logs[i] as Map;
            final logId = log['id'] as int;
            final name = log['plan_name'] ?? 'Trening';
            final date = DateTime.parse(log['date_completed'].toString());
            
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check, color: AppColors.success, size: 20),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  DateFormat('EEEE, d MMM yyyy', 'pl_PL').format(date),
                  style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
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
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: theme.colorScheme.outline),
        ),
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}k';
    }
    return volume.toStringAsFixed(0);
  }
}

// --- LIBRARY TAB ---

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncExercises = ref.watch(exerciseLibraryProvider);
    final theme = Theme.of(context);

    return asyncExercises.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Nie udało się załadować biblioteki',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.refresh(exerciseLibraryProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
      data: (exercises) {
        if (exercises.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fitness_center, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'Biblioteka ćwiczeń jest pusta',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          );
        }

        // Grupuj ćwiczenia po primary_muscle
        final Map<String, List<Map<String, dynamic>>> groupedExercises = {};
        
        for (final exercise in exercises) {
          final muscle = exercise['primary_muscle']?.toString() ?? 'Inne';
          final muscleFormatted = _formatMuscleGroup(muscle);
          
          if (!groupedExercises.containsKey(muscleFormatted)) {
            groupedExercises[muscleFormatted] = [];
          }
          groupedExercises[muscleFormatted]!.add(exercise);
        }

        // Sortuj grupy mięśniowe alfabetycznie
        final sortedMuscleGroups = groupedExercises.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: sortedMuscleGroups.length,
          itemBuilder: (context, index) {
            final muscleGroup = sortedMuscleGroups[index];
            final exercisesInGroup = groupedExercises[muscleGroup]!;
            
            return _MuscleGroupSection(
              muscleGroup: muscleGroup,
              exercises: exercisesInGroup,
            );
          },
        );
      },
    );
  }

  String _formatMuscleGroup(String muscle) {
    final translations = {
      'quadriceps': 'Mięsień czworogłowy',
      'hamstrings': 'Mięśnie kulszowo-goleniowe',
      'glutes': 'Pośladki',
      'calves': 'Łydki',
      'chest': 'Klatka piersiowa',
      'lats': 'Najszerszy grzbietu',
      'traps': 'Mięśnie czworoboczne',
      'rhomboids': 'Mięśnie równoległoboczne',
      'shoulders': 'Barki',
      'anterior_deltoid': 'Przedni naramienny',
      'lateral_deltoid': 'Boczny naramienny',
      'posterior_deltoid': 'Tylny naramienny',
      'biceps': 'Biceps',
      'triceps': 'Triceps',
      'forearms': 'Przedramiona',
      'core': 'Core / Tułów',
      'lower_back': 'Dolny odcinek pleców',
      'upper_back': 'Górny odcinek pleców',
      'hip_flexors': 'Zginacze biodrowe',
      'adductors': 'Przywodziciele',
      'abductors': 'Odwodziciele',
    };
    
    return translations[muscle.toLowerCase()] ?? 
           muscle.replaceAll('_', ' ').split(' ').map((word) => 
             word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : ''
           ).join(' ');
  }
}

class _MuscleGroupSection extends StatefulWidget {
  final String muscleGroup;
  final List<Map<String, dynamic>> exercises;

  const _MuscleGroupSection({
    required this.muscleGroup,
    required this.exercises,
  });

  @override
  State<_MuscleGroupSection> createState() => _MuscleGroupSectionState();
}

class _MuscleGroupSectionState extends State<_MuscleGroupSection> {
  bool _isExpanded = false;

  IconData _getMuscleIcon(String muscle) {
    final icons = {
      'Klatka piersiowa': Icons.airline_seat_flat,
      'Najszerszy grzbietu': Icons.back_hand,
      'Barki': Icons.accessibility_new,
      'Biceps': Icons.fitness_center,
      'Triceps': Icons.fitness_center,
      'Mięsień czworogłowy': Icons.directions_walk,
      'Mięśnie kulszowo-goleniowe': Icons.directions_run,
      'Pośladki': Icons.accessibility,
      'Łydki': Icons.directions_walk,
      'Core / Tułów': Icons.self_improvement,
    };
    
    return icons[muscle] ?? Icons.fitness_center;
  }

  Color _getMuscleColor(String muscle, ThemeData theme) {
    final colors = {
      'Klatka piersiowa': AppColors.accent,
      'Najszerszy grzbietu': AppColors.accentSecondary,
      'Barki': Colors.orange,
      'Biceps': Colors.teal,
      'Triceps': Colors.purple,
      'Mięsień czworogłowy': Colors.blue,
      'Mięśnie kulszowo-goleniowe': Colors.green,
      'Pośladki': Colors.pink,
      'Łydki': Colors.cyan,
      'Core / Tułów': Colors.amber,
    };
    
    return colors[muscle] ?? theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muscleColor = _getMuscleColor(widget.muscleGroup, theme);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: muscleColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getMuscleIcon(widget.muscleGroup),
                      color: muscleColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.muscleGroup,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.exercises.length} ćwiczeń',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.exercises.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                    color: theme.colorScheme.outline.withOpacity(0.05),
                  ),
                  itemBuilder: (context, index) {
                    final exercise = widget.exercises[index];
                    return _ExerciseListTile(
                      exercise: exercise,
                      muscleColor: muscleColor,
                    );
                  },
                ),
              ],
            ),
            crossFadeState: _isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _ExerciseListTile extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final Color muscleColor;

  const _ExerciseListTile({
    required this.exercise,
    required this.muscleColor,
  });

  String _formatDifficulty(String? difficulty) {
    final translations = {
      'beginner': 'Początkujący',
      'intermediate': 'Średniozaawansowany',
      'advanced': 'Zaawansowany',
    };
    return translations[difficulty?.toLowerCase()] ?? difficulty ?? 'Nieznany';
  }

  String _formatEquipment(String? equipment) {
    final translations = {
      'barbell': 'Sztanga',
      'dumbbell': 'Hantle',
      'machine': 'Maszyna',
      'cable': 'Wyciąg',
      'bodyweight': 'Masa ciała',
      'kettlebell': 'Kettlebell',
      'band': 'Gumy',
      'other': 'Inne',
    };
    return translations[equipment?.toLowerCase()] ?? equipment ?? 'Brak';
  }

  String _formatPattern(String? pattern) {
    final translations = {
      'push_horizontal': 'Poziomy push',
      'push_vertical': 'Pionowy push',
      'pull_horizontal': 'Poziomy pull',
      'pull_vertical': 'Pionowy pull',
      'knee_dominant': 'Ruch kolano-dominujący',
      'hip_dominant': 'Ruch biodro-dominujący',
      'isolation': 'Izolacja',
      'carry': 'Noszenie',
      'rotation': 'Rotacja',
    };
    return translations[pattern?.toLowerCase()] ?? pattern ?? '';
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'beginner':
        return AppColors.success;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = exercise['name']?.toString() ?? 'Nieznane ćwiczenie';
    final difficulty = exercise['difficulty']?.toString();
    final equipment = exercise['equipment']?.toString();
    final pattern = exercise['pattern']?.toString();

    return InkWell(
      onTap: () => _showExerciseDetails(context, theme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: muscleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.fitness_center,
                size: 18,
                color: muscleColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (equipment != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatEquipment(equipment),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (difficulty != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(difficulty).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDifficulty(difficulty),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getDifficultyColor(difficulty),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseDetails(BuildContext context, ThemeData theme) {
    final name = exercise['name']?.toString() ?? 'Nieznane ćwiczenie';
    final difficulty = exercise['difficulty']?.toString();
    final equipment = exercise['equipment']?.toString();
    final pattern = exercise['pattern']?.toString();
    final primaryMuscle = exercise['primary_muscle']?.toString();
    final mechanics = exercise['mechanics']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Exercise name
            Text(
              name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Info grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (difficulty != null)
                  _buildInfoChip(
                    context,
                    icon: Icons.speed,
                    label: 'Poziom',
                    value: _formatDifficulty(difficulty),
                    color: _getDifficultyColor(difficulty),
                  ),
                if (equipment != null)
                  _buildInfoChip(
                    context,
                    icon: Icons.sports_gymnastics,
                    label: 'Sprzęt',
                    value: _formatEquipment(equipment),
                    color: theme.colorScheme.primary,
                  ),
                if (pattern != null)
                  _buildInfoChip(
                    context,
                    icon: Icons.swap_calls,
                    label: 'Wzorzec',
                    value: _formatPattern(pattern),
                    color: AppColors.accentSecondary,
                  ),
                if (mechanics != null)
                  _buildInfoChip(
                    context,
                    icon: Icons.settings,
                    label: 'Mechanika',
                    value: mechanics == 'compound' ? 'Wielostawowe' : 'Izolacja',
                    color: Colors.teal,
                  ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Zamknij'),
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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