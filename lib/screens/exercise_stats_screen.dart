import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gofi/services/api/providers.dart';
import 'package:intl/intl.dart'; 
import '../utils/converters.dart'; 

class ExerciseStatsScreen extends ConsumerWidget {
  final String exerciseCode;
  final String exerciseName;
  final String unitSystem; 

  const ExerciseStatsScreen({
    super.key,
    required this.exerciseCode,
    required this.exerciseName,
    this.unitSystem = 'metric', 
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(exerciseHistoryProvider(exerciseCode));
    
    
    final converter = UnitConverter(unitSystem: unitSystem);
    final unitLabel = converter.unitLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(exerciseName),
      ),
      body: asyncHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Błąd ładowania historii: $err')),
        data: (data) {
          if (data.isEmpty) {
            return const Center(
              child: Text('Brak wystarczających danych do narysowania wykresu.'),
            );
          }

          final List<FlSpot> spots;
          try {
            
            spots = data.map((entry) {
              final date = DateTime.parse(entry['date'] as String);
              
              final weightInKg = double.tryParse(entry['max_weight'].toString()) ?? 0.0;
              
              
              final displayValue = converter.displayWeight(weightInKg);
              
              return FlSpot(
                date.millisecondsSinceEpoch.toDouble(),
                displayValue, 
              );
            }).toList();
            
          } catch (e) {
            return Center(child: Text('Błąd parsowania danych wykresu: $e'));
          }
          
          if (spots.isEmpty) {
             return const Center(
              child: Text('Brak zalogowanych serii z wagą > 0.'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  'Postęp (max waga)',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 300,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 4,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            
                            getTitlesWidget: (value, meta) => Text('${value.toInt()}$unitLabel '),
                            reservedSize: 50,
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: spots.length > 3 
                                ? (spots.last.x - spots.first.x) / 3 
                                : null,
                            getTitlesWidget: (value, meta) {
                              final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(DateFormat('dd/MM').format(date)),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
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
}