
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gofi/services/api/providers.dart';
import 'package:gofi/screens/exercise_stats_screen.dart'; 
import 'package:intl/intl.dart';
import '../utils/converters.dart';
import '../app/theme.dart';

class WorkoutDetailsScreen extends ConsumerWidget {
  final int logId;
  final String planName;
  final String unitSystem; 

  const WorkoutDetailsScreen({
    super.key,
    required this.logId,
    required this.planName,
    this.unitSystem = 'metric', 
  });

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs.toString().padLeft(2, '0')}s';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetails = ref.watch(workoutLogDetailsProvider(logId));
    final theme = Theme.of(context);
    
    
    final converter = UnitConverter(unitSystem: unitSystem);
    final unitLabel = converter.unitLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(planName),
      ),
      body: asyncDetails.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Błąd ładowania szczegółów: $err')),
        data: (data) {
          final workoutInfo = data['workout'] as Map<String, dynamic>? ?? {};
          final exercises = (data['exercises'] as List<dynamic>?) ?? [];
          
          if (exercises.isEmpty) {
            return const Center(child: Text('Ten trening nie zawierał żadnych zapisanych serii.'));
          }

          // Calculate totals
          int totalDuration = workoutInfo['duration_seconds'] as int? ?? 0;
          int totalRest = workoutInfo['rest_time_seconds'] as int? ?? 0;
          int totalSets = 0;
          for (final ex in exercises) {
            totalSets += ((ex as Map)['sets'] as List?)?.length ?? 0;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withOpacity(0.2),
                      AppColors.accentSecondary.withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      icon: Icons.fitness_center,
                      value: exercises.length.toString(),
                      label: 'Ćwiczeń',
                      color: AppColors.accent,
                    ),
                    _buildSummaryItem(
                      icon: Icons.repeat,
                      value: totalSets.toString(),
                      label: 'Serii',
                      color: Colors.blue,
                    ),
                    _buildSummaryItem(
                      icon: Icons.timer,
                      value: _formatDuration(totalDuration),
                      label: 'Trening',
                      color: Colors.green,
                    ),
                    if (totalRest > 0)
                      _buildSummaryItem(
                        icon: Icons.pause_circle_outline,
                        value: _formatDuration(totalRest),
                        label: 'Przerwy',
                        color: Colors.orange,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Exercise list
              ...exercises.map((exercise) {
                final ex = exercise as Map;
                final name = ex['name']?.toString() ?? 'Nieznane ćwiczenie';
                final code = ex['code']?.toString() ?? '';
                final sets = (ex['sets'] as List?) ?? [];
                final exerciseTotalDuration = ex['totalDuration'] as int? ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExerciseStatsScreen(
                                  exerciseCode: code,
                                  exerciseName: name,
                                  unitSystem: unitSystem, 
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    if (exerciseTotalDuration > 0)
                                      Row(
                                        children: [
                                          Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Łącznie: ${_formatDuration(exerciseTotalDuration)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.show_chart, size: 20),
                            ],
                          ),
                        ),
                        const Divider(height: 16),
                        
                        // Header row
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const SizedBox(width: 40, child: Text('Seria', style: TextStyle(fontSize: 12, color: Colors.grey))),
                              Expanded(child: Text('Ciężar ($unitLabel)', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                              const SizedBox(width: 60, child: Text('Powt.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                              const SizedBox(width: 60, child: Text('Czas', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
                            ],
                          ),
                        ),
                        
                        ...sets.map((s) {
                          final set = s as Map;
                          
                          final weightInKg = double.tryParse(set['weight'].toString()) ?? 0.0;
                          final displayValue = converter.displayWeight(weightInKg);
                          final weightStr = displayValue == displayValue.toInt() 
                              ? displayValue.toInt().toString() 
                              : displayValue.toStringAsFixed(1); 
                          final setDuration = set['duration_seconds'] as int?;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${set['set']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$weightStr $unitLabel',
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '${set['reps']}x',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: setDuration != null && setDuration > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _formatDuration(setDuration),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      )
                                    : Text(
                                        '-',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        textAlign: TextAlign.right,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }),
                        
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value.isEmpty ? '-' : value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}