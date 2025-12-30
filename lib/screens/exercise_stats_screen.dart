import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gofi/services/api/providers.dart';
import 'package:intl/intl.dart';
import '../utils/converters.dart';
import '../app/theme.dart'; // Import motywu

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

  // --- FUNKCJA GENERUJĄCA DANE TESTOWE ---
  Future<void> _generateSampleData(BuildContext context, WidgetRef ref) async {
    final logService = ref.read(logServiceProvider);
    final random = Random();
    
    // Bazowa waga startowa (np. między 40 a 60 kg)
    double currentWeight = 40.0 + random.nextInt(20);

    try {
      // Generujemy 10 wpisów wstecz
      for (int i = 9; i >= 0; i--) {
        // Data co ok. 5 dni
        final date = DateTime.now().subtract(Duration(days: i * 5));
        
        // Lekki progres wagi (+0 do +2.5 kg co trening)
        currentWeight += (random.nextInt(6) * 0.5); 

        // Tworzymy strukturę treningu
        final workoutData = {
          'name': 'Trening Generowany',
          'date_completed': date.toIso8601String(),
          'exercises': [
            {
              'code': exerciseCode,
              'name': exerciseName,
              'sets': [
                {'weight': currentWeight, 'reps': 10, 'rpe': 8},
                {'weight': currentWeight, 'reps': 10, 'rpe': 9},
                {'weight': currentWeight, 'reps': 8, 'rpe': 10},
              ]
            }
          ]
        };

        await logService.saveWorkout(workoutData);
      }
      
      // Odśwież widok po zakończeniu
      ref.invalidate(exerciseHistoryProvider(exerciseCode));
      ref.invalidate(workoutLogsProvider); // Odśwież też historię ogólną
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dodano przykładowe dane!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd generowania danych: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(exerciseHistoryProvider(exerciseCode));
    
    final converter = UnitConverter(unitSystem: unitSystem);
    final unitLabel = converter.unitLabel;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          exerciseName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Przycisk do generowania danych (dla test@test.pl)
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: AppColors.accent),
            tooltip: 'Generuj przykładowe dane',
            onPressed: () => _showGenerateDialog(context, ref),
          )
        ],
      ),
      body: asyncHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Błąd ładowania historii:\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
        data: (data) {
          if (data.isEmpty) {
            return _buildEmptyState(context, ref);
          }

          final List<FlSpot> spots;
          double maxVal = 0;
          double minVal = double.infinity;

          try {
            spots = data.map((entry) {
              final date = DateTime.parse(entry['date'] as String);
              final weightInKg = double.tryParse(entry['max_weight'].toString()) ?? 0.0;
              final displayValue = converter.displayWeight(weightInKg);
              
              if (displayValue > maxVal) maxVal = displayValue;
              if (displayValue < minVal) minVal = displayValue;

              return FlSpot(
                date.millisecondsSinceEpoch.toDouble(),
                displayValue,
              );
            }).toList();
            
            // Sortowanie po dacie (X)
            spots.sort((a, b) => a.x.compareTo(b.x));

          } catch (e) {
            return Center(child: Text('Błąd przetwarzania danych: $e', style: const TextStyle(color: Colors.red)));
          }
          
          if (spots.isEmpty) {
             return _buildEmptyState(context, ref);
          }

          // Obliczanie "Best Lift" (Rekord)
          final personalRecord = maxVal;

          return ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              // Karta statystyk (Rekord)
              _buildStatCard(context, personalRecord, unitLabel),
              
              const SizedBox(height: 24),
              
              const Text(
                'PROGRESJA SIŁOWA',
                style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Kontener z wykresem
              Container(
                height: 350,
                padding: const EdgeInsets.only(right: 24, left: 12, top: 32, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgAlt,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AppColors.bg,
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(12),
                        tooltipBorder: const BorderSide(color: AppColors.stroke),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                            final dateStr = DateFormat('dd MMM').format(date);
                            return LineTooltipItem(
                              '$dateStr\n',
                              const TextStyle(
                                color: AppColors.textDim,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: '${spot.y} $unitLabel', // <--- POPRAWKA TUTAJ
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AppColors.accent,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.bg,
                              strokeWidth: 2,
                              strokeColor: AppColors.accent,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent.withOpacity(0.25),
                              AppColors.accent.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value == value.toInt()) {
                              return Text(
                                '${value.toInt()}',
                                style: const TextStyle(color: AppColors.textDim, fontSize: 10),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 30,
                          interval: (maxVal - minVal) > 5 ? null : 5, // Auto interwał
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          // Pokazuj max 5 dat na osi X
                          interval: spots.length > 4 
                              ? (spots.last.x - spots.first.x) / 4 
                              : null,
                          getTitlesWidget: (value, meta) {
                            final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('dd.MM').format(date),
                                style: const TextStyle(color: AppColors.textDim, fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, double record, String unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.bgAlt, Color(0xFF252525)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events, color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Twój Rekord (PR)', 
                style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$record',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: Text(
                      unit,
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats, size: 64, color: AppColors.textDim.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'Brak danych',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Wykonaj trening z tym ćwiczeniem, aby zobaczyć wykres postępu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textDim),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
             style: FilledButton.styleFrom(
              backgroundColor: AppColors.bgAlt,
              foregroundColor: AppColors.accent,
             ),
             icon: const Icon(Icons.auto_fix_high),
             label: const Text('Generuj przykładowe dane'),
             onPressed: () => _showGenerateDialog(context, ref),
          )
        ],
      ),
    );
  }

  void _showGenerateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgAlt,
        title: const Text('Generowanie danych', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Ta opcja doda 10 fikcyjnych treningów z przeszłości dla tego ćwiczenia, aby przetestować wygląd wykresu. Czy kontynuować?',
          style: TextStyle(color: AppColors.textDim),
        ),
        actions: [
          TextButton(
            child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Generuj'),
            onPressed: () {
              Navigator.pop(ctx);
              _generateSampleData(context, ref);
            },
          ),
        ],
      ),
    );
  }
}