import 'dart:io';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gofi/screens/starting_screen.dart';
import 'package:pedometer/pedometer.dart';
import 'package:device_info_plus/device_info_plus.dart'; 
import 'package:intl/intl.dart'; 
import '../app/theme.dart';
import '../utils/converters.dart';
import '../utils/language_settings.dart';
import 'profile_screen.dart';
import 'plan_view.dart';
import 'questionnaire_screen.dart';
import 'custom_plan_builder_screen.dart';
import '../services/api/providers.dart'; 
import '../services/api/workout_session_service.dart';
import '../widgets/update_dialog.dart';
import 'active_workout_screen.dart';
import 'workout_details_screen.dart'; 
import 'exercise_library_screen.dart'; 

// --- HELPERS ---

/// Helper to extract exercise name from different formats
String _getExerciseName(dynamic exercise, [String lang = 'pl']) {
  if (exercise == null) return lang == 'pl' ? 'Nieznane' : 'Unknown';
  if (exercise is String) return exercise;
  if (exercise is Map) {
    final name = exercise['name'];
    if (name is String) return name;
    if (name is Map) {
      return name[lang]?.toString() ?? name['en']?.toString() ?? name['pl']?.toString() ?? (lang == 'pl' ? 'Nieznane' : 'Unknown');
    }
    return exercise['name_$lang']?.toString() ?? 
           exercise['name_en']?.toString() ?? 
           exercise['name_pl']?.toString() ?? 
           exercise['code']?.toString() ?? 
           (lang == 'pl' ? 'Nieznane' : 'Unknown');
  }
  return exercise.toString();
}

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
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final versionService = ref.read(appVersionServiceProvider);
      final updateInfo = await versionService.checkForUpdate();

      if (!mounted) return;

      if (updateInfo != null && updateInfo.needsUpdate) {
        if (updateInfo.needsForceUpdate) {
          await UpdateDialog.show(context, updateInfo);
        } else {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            UpdateDialog.show(context, updateInfo);
          }
        }
      }
    } catch (e) {
      debugPrint('Błąd sprawdzania aktualizacji: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('GoFi', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          const LanguageSwitch(showLabel: false),
          const SizedBox(width: 4),
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
          const ExerciseLibraryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: AppTranslations.get('home', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: AppTranslations.get('statistics', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: AppTranslations.get('plan', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.library_books_outlined),
            selectedIcon: const Icon(Icons.library_books),
            label: AppTranslations.get('library', lang),
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
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Łączenie z serwerem...',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
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
                onPressed: () => ref.invalidate(planProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Spróbuj ponownie'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
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
          // Day names in both Polish and English for matching
          final dayMapPl = { 
            1: 'Poniedziałek', 2: 'Wtorek', 3: 'Środa', 4: 'Czwartek', 
            5: 'Piątek', 6: 'Sobota', 7: 'Niedziela' 
          };
          final dayMapEn = { 
            1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 
            5: 'Friday', 6: 'Saturday', 7: 'Sunday' 
          };
          final dayMapShort = { 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun' };
          
          final todayPl = dayMapPl[today];
          final todayEn = dayMapEn[today];
          final todayShort = dayMapShort[today];
          
          todaysWorkout = week.firstWhere(
            (d) {
              final dayName = (d['day']?.toString() ?? '').toLowerCase();
              return dayName.startsWith(todayPl?.toLowerCase() ?? '') ||
                     dayName.startsWith(todayEn?.toLowerCase() ?? '') ||
                     dayName.startsWith(todayShort?.toLowerCase() ?? '');
            },
            orElse: () => null,
          );
        }

        final lang = ref.watch(languageProvider);
        
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentSecondary],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'pl' ? 'Witaj z powrotem!' : 'Welcome back!',
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        lang == 'pl' ? 'Gotowy na trening?' : 'Ready to workout?',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 28),
            
            // Activity section header
            _buildHomeSectionHeader(
              context,
              icon: Icons.trending_up_rounded,
              title: lang == 'pl' ? 'Twoja aktywność' : 'Your Activity',
              color: AppColors.accent,
            ),
            const SizedBox(height: 16),

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

            const SizedBox(height: 28),

            // Resume paused workout banner
            _buildResumeWorkoutBanner(context, ref, todaysWorkout, unitSystem, lang),
            
            // Today's workout section header
            _buildHomeSectionHeader(
              context,
              icon: Icons.today_rounded,
              title: lang == 'pl' ? 'Dzisiejszy trening' : "Today's Workout",
              color: AppColors.accentSecondary,
            ),
            const SizedBox(height: 16),
            
            if (todaysWorkout != null)
              _buildTodayWorkoutCard(context, todaysWorkout, unitSystem, ref)
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.self_improvement, color: Colors.greenAccent, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'pl' ? 'Dzień wolny' : 'Rest day',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lang == 'pl' ? 'Odpocznij i zregeneruj siły!' : 'Take a break and recover!',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
  
  Widget _buildResumeWorkoutBanner(BuildContext context, WidgetRef ref, Map? todaysWorkout, String unitSystem, String lang) {
    final asyncSession = ref.watch(pausedSessionProvider);
    return asyncSession.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (session) {
        if (session == null) return const SizedBox.shrink();
        
        final startedAt = session.startedAt;
        final elapsed = DateTime.now().difference(startedAt);
        final elapsedStr = elapsed.inMinutes > 60
            ? '${elapsed.inHours}h ${elapsed.inMinutes % 60}min'
            : '${elapsed.inMinutes}min';

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.withOpacity(0.2), Colors.deepOrange.withOpacity(0.15)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause_circle_filled, color: Colors.orange, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'pl' ? 'Trening wstrzymany' : 'Workout paused',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${session.planName ?? (lang == 'pl' ? 'Trening' : 'Workout')} · $elapsedStr ${lang == 'pl' ? 'temu' : 'ago'}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          if (todaysWorkout != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActiveWorkoutScreen(
                                  workout: todaysWorkout,
                                  unitSystem: unitSystem,
                                ),
                              ),
                            ).then((_) {
                              ref.invalidate(pausedSessionProvider);
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: Text(lang == 'pl' ? 'Wznów' : 'Resume',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          final sessionService = ref.read(workoutSessionServiceProvider);
                          await sessionService.abandonSession(session.id);
                          ref.invalidate(pausedSessionProvider);
                        },
                        child: Text(
                          lang == 'pl' ? 'Porzuć' : 'Discard',
                          style: TextStyle(color: Colors.red[300], fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildHomeSectionHeader(BuildContext context, {required IconData icon, required String title, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildActivityCard(BuildContext context, AsyncValue<int> asyncSteps, int stepGoal) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_walk, color: AppColors.accent, size: 20),
              ),
              asyncSteps.when(
                data: (steps) {
                  final progress = (stepGoal > 0 ? (steps / stepGoal) : 0.0).clamp(0.0, 1.0);
                  return SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  );
                },
                loading: () => const SizedBox(width: 28, height: 28),
                error: (_,__) => Icon(Icons.error_outline, size: 20, color: Colors.red[300]),
              )
            ],
          ),
          const SizedBox(height: 14),
          const Text('Kroki', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 6),
          asyncSteps.when(
            data: (steps) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$steps', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text('/ $stepGoal', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            loading: () => const Text('...', style: TextStyle(fontSize: 20)),
            error: (_, __) => const Text('--', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightLogCard(BuildContext context, WidgetRef ref, double? latestWeightKg, UnitConverter converter) {
    final theme = Theme.of(context);
    final todayLogged = ref.watch(todayWeightLoggedProvider);
    
    final String displayWeight = latestWeightKg != null
        ? converter.displayWeight(latestWeightKg).toString()
        : '--';
    
    final bool isLoggedToday = todayLogged.when(
      data: (logged) => logged,
      loading: () => false,
      error: (_, __) => false,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showLogWeightDialog(context, ref, converter),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.monitor_weight_outlined, color: Colors.white, size: 20),
                    ),
                    // Indicator: logged today or add button
                    isLoggedToday
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                                SizedBox(width: 4),
                                Text('Dziś', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Waga', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, 
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(text: displayWeight),
                      TextSpan(
                        text: ' ${converter.unitLabel}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayWorkoutCard(BuildContext context, Map workout, String unitSystem, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final title = (workout['day'] ?? workout['block'] ?? (lang == 'pl' ? 'Trening' : 'Workout')).toString();
    final exercises = (workout['exercises'] as List?) ?? [];
    
    // Build exercise names with proper language
    final exerciseNames = exercises.take(3).map((e) => _getExerciseName(e, lang)).join(', ') +
        (exercises.length > 3 ? '...' : '');
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.accent,
            AppColors.accentSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${exercises.length} ${lang == 'pl' ? 'Ćwiczeń' : 'Exercises'}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            exerciseNames,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
                ).then((_) {
                  ref.invalidate(pausedSessionProvider);
                });
              },
              child: Text(lang == 'pl' ? 'Rozpocznij' : 'Start', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final lang = ref.watch(languageProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(workoutLogsProvider);
        ref.refresh(weightHistoryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentSecondary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == 'pl' ? 'Twoje statystyki' : 'Your Statistics',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      lang == 'pl' ? 'Śledź swoje postępy' : 'Track your progress',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // Sekcja wagi
          _buildSectionHeader(
            context,
            icon: Icons.monitor_weight_outlined,
            title: lang == 'pl' ? 'Waga' : 'Weight',
            color: AppColors.accent,
          ),
          const SizedBox(height: 16),
          
          // --- WYKRES WAGI ---
          Container(
            height: 300,
            padding: const EdgeInsets.fromLTRB(8, 24, 24, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: asyncWeightHistory.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.grey[600], size: 48),
                    const SizedBox(height: 12),
                    Text(lang == 'pl' ? 'Błąd wykresu' : 'Chart error', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
              data: (history) {
                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.scale_outlined, color: Colors.grey[600], size: 48),
                        const SizedBox(height: 12),
                        Text(
                          lang == 'pl' ? 'Brak pomiarów wagi' : 'No weight measurements',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang == 'pl' ? 'Dodaj pierwszy pomiar na stronie głównej' : 'Add first measurement on home page',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                    child: Text(
                      lang == 'pl' ? 'Brak poprawnych danych' : 'No valid data',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.1),
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
                        color: AppColors.accent,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: theme.colorScheme.surface,
                            strokeWidth: 3,
                            strokeColor: AppColors.accent,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent.withOpacity(0.3),
                              AppColors.accent.withOpacity(0.0),
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

          // Sekcja historii treningów
          _buildSectionHeader(
            context,
            icon: Icons.history_rounded,
            title: lang == 'pl' ? 'Historia treningów' : 'Workout History',
            color: AppColors.accentSecondary,
          ),
          const SizedBox(height: 16),
          
          asyncLogs.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (e, _) => Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.grey[600], size: 48),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      e.toString(),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ref.refresh(workoutLogsProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(lang == 'pl' ? 'Odśwież' : 'Refresh'),
                  ),
                ],
              ),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.fitness_center_outlined, color: Colors.grey[600], size: 48),
                      const SizedBox(height: 12),
                      Text(
                        lang == 'pl' ? 'Brak historii treningów' : 'No workout history',
                        style: TextStyle(color: Colors.grey[500], fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang == 'pl' ? 'Ukończ pierwszy trening, aby zobaczyć historię' : 'Complete a workout to see history',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (_,__) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final log = logs[i] as Map;
                  final logId = log['id'] as int;
                  final name = log['plan_name'] ?? 'Trening';
                  final date = DateTime.parse(log['date_completed'].toString());
                  final durationSec = log['duration_seconds'] as int?;
                  final restSec = log['rest_time_seconds'] as int?;
                  
                  // Format duration
                  String? durationStr;
                  if (durationSec != null && durationSec > 0) {
                    final mins = durationSec ~/ 60;
                    final secs = durationSec % 60;
                    durationStr = '${mins}m ${secs.toString().padLeft(2, '0')}s';
                  }
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentSecondary.withOpacity(0.3),
                              AppColors.accent.withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.greenAccent, size: 22),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, d MMM yyyy', 'pl_PL').format(date),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          if (durationStr != null)
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  durationStr,
                                  style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                if (restSec != null && restSec > 0) ...[
                                  const SizedBox(width: 10),
                                  const Icon(Icons.pause_circle_outline, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${restSec ~/ 60}m',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                      ),
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
  
  Widget _buildSectionHeader(BuildContext context, {required IconData icon, required String title, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
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
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _hasUnsavedChanges = false;

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
        _hasUnsavedChanges = true;
      });

    } catch (e) {
      print('Błąd podczas aktualizacji ćwiczenia: $e');
    }
  }

  Future<void> _savePlanToDatabase() async {
    if (_editablePlan == null || _isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      await ref.read(questionnaireServiceProvider).updateLatestPlan(_editablePlan!);
      
      // Invaliduj planProvider żeby _HomeTab pobrał zaktualizowany plan
      ref.invalidate(planProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zapisano zmiany.'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      print('Błąd zapisu planu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addExercise(int dayIndex, Map<String, dynamic> exercise) {
    if (_editablePlan == null) return;
    try {
      final List week = (_editablePlan!['week'] as List);
      final Map day = Map<String, dynamic>.from(week[dayIndex]);
      final List exercises = List.from(day['exercises'] ?? []);
      
      exercises.add(exercise);
      day['exercises'] = exercises;
      
      // If it was a rest day, make it a workout day
      if (day['type'] == 'rest') {
        day['type'] = 'workout';
      }
      
      week[dayIndex] = day;
      
      setState(() {
        _hasUnsavedChanges = true;
      });
    } catch (e) {
      print('Błąd podczas dodawania ćwiczenia: $e');
    }
  }

  void _removeExercise(int dayIndex, int exerciseIndex) {
    if (_editablePlan == null) return;
    try {
      final List week = (_editablePlan!['week'] as List);
      final Map day = Map<String, dynamic>.from(week[dayIndex]);
      final List exercises = List.from(day['exercises'] ?? []);
      
      if (exerciseIndex >= 0 && exerciseIndex < exercises.length) {
        exercises.removeAt(exerciseIndex);
        day['exercises'] = exercises;
        week[dayIndex] = day;
        
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      print('Błąd podczas usuwania ćwiczenia: $e');
    }
  }

  void _addDay(Map<String, dynamic> day) {
    if (_editablePlan == null) return;
    try {
      final List week = List.from(_editablePlan!['week'] ?? []);
      week.add(day);
      _editablePlan!['week'] = week;
      
      setState(() {
        _hasUnsavedChanges = true;
      });
    } catch (e) {
      print('Błąd podczas dodawania dnia: $e');
    }
  }

  void _removeDay(int dayIndex) {
    if (_editablePlan == null) return;
    try {
      final List week = List.from(_editablePlan!['week'] ?? []);
      
      if (dayIndex >= 0 && dayIndex < week.length) {
        week.removeAt(dayIndex);
        _editablePlan!['week'] = week;
        
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      print('Błąd podczas usuwania dnia: $e');
    }
  }

  void _changeDay(int dayIndex, Map<String, dynamic> newDayData) {
    if (_editablePlan == null) return;
    try {
      final List week = List.from(_editablePlan!['week'] ?? []);
      
      if (dayIndex >= 0 && dayIndex < week.length) {
        // Zachowaj ćwiczenia z oryginalnego dnia jeśli nowe dane ich nie mają
        final oldDay = Map<String, dynamic>.from(week[dayIndex] as Map);
        if (newDayData['exercises'] == null || (newDayData['exercises'] as List).isEmpty) {
          newDayData['exercises'] = oldDay['exercises'];
        }
        week[dayIndex] = newDayData;
        _editablePlan!['week'] = week;
        
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      print('Błąd podczas zmiany dnia: $e');
    }
  }

  Future<void> _exportPlan() async {
    if (_editablePlan == null) return;
    
    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(_editablePlan);
      
      // Use share functionality
      await Share.share(jsonStr, subject: 'GoFi Training Plan');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan został wyeksportowany'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      print('Błąd eksportu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd eksportu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importPlan() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content;
        
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          content = await File(file.path!).readAsString();
        } else {
          throw Exception('Nie można odczytać pliku');
        }
        
        final parsed = jsonDecode(content);
        
        if (parsed is Map && parsed.containsKey('week')) {
          setState(() {
            _editablePlan = Map<String, dynamic>.from(parsed);
            _hasUnsavedChanges = true;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Plan został zaimportowany'), duration: Duration(seconds: 2)),
            );
          }
        } else {
          throw Exception('Nieprawidłowy format planu');
        }
      }
    } catch (e) {
      print('Błąd importu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd importu: $e'), backgroundColor: Colors.red),
        );
      }
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
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Ładowanie planu...',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
      error: (err, stack) {
        _editablePlan = null;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text('Nie można połączyć z serwerem', style: TextStyle(color: Colors.grey.shade300, fontSize: 16)),
              const SizedBox(height: 8),
              Text('$err', style: TextStyle(color: Colors.grey.shade500, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.invalidate(widget.planProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Spróbuj ponownie'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
      data: (plan) {
        if (plan == null) {
          _editablePlan = null;
          final lang = ref.watch(languageProvider);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.2),
                          AppColors.accentSecondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.calendar_month_outlined, color: AppColors.accent, size: 56),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    lang == 'pl' ? 'Brak aktywnego planu' : 'No active plan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang == 'pl' 
                        ? 'Wypełnij kwestionariusz, aby wygenerować swój pierwszy plan treningowy'
                        : 'Fill out the questionnaire to generate your first workout plan',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: Text(lang == 'pl' ? 'Wypełnij kwestionariusz' : 'Fill questionnaire'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
                        );
                      },
                    ),
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

        final lang = ref.watch(languageProvider);

        return RefreshIndicator(
          onRefresh: () async {
            _editablePlan = null;
            _isEditMode = false;
            _hasUnsavedChanges = false;
            return ref.refresh(widget.planProvider);
          },
          child: Column(
            children: [
              // Przyciski akcji
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _isEditMode
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close, size: 18, color: Colors.white),
                              label: Text(
                                lang == 'pl' ? 'Anuluj' : 'Cancel',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEditMode = false;
                                  // Odrzuć zmiany - ponownie załaduj plan
                                  _editablePlan = null;
                                  _hasUnsavedChanges = false;
                                });
                                ref.invalidate(widget.planProvider);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded, size: 18),
                              label: Text(lang == 'pl' ? 'Zapisz' : 'Save'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _hasUnsavedChanges
                                    ? AppColors.accent
                                    : Colors.grey[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _isSaving
                                  ? null
                                  : () async {
                                      await _savePlanToDatabase();
                                      setState(() {
                                        _isEditMode = false;
                                        _hasUnsavedChanges = false;
                                      });
                                    },
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                              label: Text(
                                lang == 'pl' ? 'Nowa ankieta' : 'New questionnaire',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: Text(lang == 'pl' ? 'Edytuj plan' : 'Edit plan'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEditMode = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              
              // Plan view
              Expanded(
                child: PlanView(
                  plan: _editablePlan!,
                  onExerciseChanged: _isEditMode ? _updateExercise : null,
                  onExerciseAdded: _isEditMode ? _addExercise : null,
                  onExerciseRemoved: _isEditMode ? _removeExercise : null,
                  onDayAdded: _isEditMode ? _addDay : null,
                  onDayRemoved: _isEditMode ? _removeDay : null,
                  onDayChanged: _isEditMode ? _changeDay : null,
                  onPlanExport: _isEditMode ? _exportPlan : null,
                  onPlanImport: _isEditMode ? _importPlan : null,
                  unitSystem: unitSystem,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}