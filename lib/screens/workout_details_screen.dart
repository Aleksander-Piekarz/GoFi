
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gofi/services/api/providers.dart';
import 'package:gofi/screens/exercise_stats_screen.dart'; 
import 'package:intl/intl.dart';
import '../utils/converters.dart'; 

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
        data: (exercises) {
          if (exercises.isEmpty) {
            return const Center(child: Text('Ten trening nie zawierał żadnych zapisanych serii.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index] as Map;
              final name = exercise['name']?.toString() ?? 'Nieznane ćwiczenie';
              final code = exercise['code']?.toString() ?? '';
              final sets = (exercise['sets'] as List?) ?? [];

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
                              child: Text(
                                name,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            const Icon(Icons.show_chart, size: 20),
                          ],
                        ),
                      ),
                      const Divider(height: 16),
                      
                      
                      ...sets.map((s) {
                        final set = s as Map;
                        
                        final weightInKg = double.tryParse(set['weight'].toString()) ?? 0.0;
                        
                        
                        final displayValue = converter.displayWeight(weightInKg);

                        
                        final weightStr = displayValue == displayValue.toInt() 
                            ? displayValue.toInt().toString() 
                            : displayValue.toStringAsFixed(1); 

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            
                            'Seria ${set['set']}:   $weightStr $unitLabel x ${set['reps']} powt.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        );
                      }),
                      
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}