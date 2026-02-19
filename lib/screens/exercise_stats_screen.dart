import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gofi/services/api/providers.dart';
import 'package:intl/intl.dart';
import '../utils/converters.dart';
import '../utils/language_settings.dart';
import '../app/theme.dart';

class _WorkoutDataPoint {
  final DateTime date;
  final double maxWeight;
  final int sets;
  final int reps;
  final double volume;

  _WorkoutDataPoint({
    required this.date,
    required this.maxWeight,
    required this.sets,
    required this.reps,
    required this.volume,
  });
}

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
    final lang = ref.watch(languageProvider);

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
      ),
      body: asyncHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '${lang == 'pl' ? 'Błąd ładowania historii' : 'Error loading history'}:\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
        data: (data) {
          if (data.isEmpty || data.length < 2) {
            return _buildNotEnoughData(context, lang, data.length);
          }

          // Parse data
          final List<_WorkoutDataPoint> dataPoints = [];
          double maxWeight = 0;
          double minWeight = double.infinity;
          int totalSetsAll = 0;
          double totalVolumeAll = 0;
          int totalRepsAll = 0;

          for (final entry in data) {
            final date = DateTime.parse(entry['date'] as String);
            final weightInKg = double.tryParse(entry['max_weight'].toString()) ?? 0.0;
            final displayWeight = converter.displayWeight(weightInKg);
            final sets = int.tryParse(entry['total_sets']?.toString() ?? '0') ?? 0;
            final reps = int.tryParse(entry['total_reps']?.toString() ?? '0') ?? 0;
            final volumeKg = double.tryParse(entry['total_volume']?.toString() ?? '0') ?? 0.0;
            final displayVolume = converter.displayWeight(volumeKg);

            if (displayWeight > maxWeight) maxWeight = displayWeight;
            if (displayWeight < minWeight) minWeight = displayWeight;
            totalSetsAll += sets;
            totalVolumeAll += displayVolume;
            totalRepsAll += reps;

            dataPoints.add(_WorkoutDataPoint(
              date: date,
              maxWeight: displayWeight,
              sets: sets,
              reps: reps,
              volume: displayVolume,
            ));
          }

          dataPoints.sort((a, b) => a.date.compareTo(b.date));

          final spots = dataPoints
              .map((dp) => FlSpot(
                    dp.date.millisecondsSinceEpoch.toDouble(),
                    dp.maxWeight,
                  ))
              .toList();

          final avgSetsPerWorkout = (totalSetsAll / dataPoints.length).toStringAsFixed(1);
          final avgVolumePerWorkout = (totalVolumeAll / dataPoints.length).toStringAsFixed(0);

          final firstWeight = dataPoints.first.maxWeight;
          final latestWeight = dataPoints.last.maxWeight;
          final weightDiff = latestWeight - firstWeight;
          final weightDiffPercent = firstWeight > 0
              ? ((weightDiff / firstWeight) * 100).toStringAsFixed(1)
              : '0';

          return ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              _buildPRCard(context, lang, maxWeight, unitLabel),
              const SizedBox(height: 16),
              _buildProgressCard(context, lang, weightDiff, weightDiffPercent, unitLabel),
              const SizedBox(height: 24),
              Text(
                lang == 'pl' ? 'PROGRESJA SIŁOWA' : 'STRENGTH PROGRESSION',
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildChart(context, spots, maxWeight, minWeight, unitLabel),
              const SizedBox(height: 24),
              Text(
                lang == 'pl' ? 'SZCZEGÓŁY' : 'DETAILS',
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildStatsGrid(context, lang, unitLabel, dataPoints.length,
                  totalSetsAll, totalRepsAll, totalVolumeAll, avgSetsPerWorkout, avgVolumePerWorkout),
              const SizedBox(height: 24),
              Text(
                lang == 'pl' ? 'HISTORIA TRENINGÓW' : 'WORKOUT HISTORY',
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              ...dataPoints.reversed.map((dp) => _buildWorkoutHistoryItem(context, lang, dp, unitLabel)),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotEnoughData(BuildContext context, String lang, int count) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.query_stats, size: 64, color: AppColors.textDim.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              lang == 'pl' ? 'Za mało danych' : 'Not enough data',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              lang == 'pl'
                  ? 'Potrzebujesz co najmniej 2 treningów z tym ćwiczeniem.\nAktualnie: $count/2'
                  : 'You need at least 2 workouts with this exercise.\nCurrently: $count/2',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim),
            ),
            const SizedBox(height: 24),
            Container(
              width: 200,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: count / 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentSecondary],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPRCard(BuildContext context, String lang, double record, String unit) {
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
              Text(
                lang == 'pl' ? 'Twój Rekord (PR)' : 'Personal Record (PR)',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12),
              ),
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

  Widget _buildProgressCard(BuildContext context, String lang, double diff, String percent, String unit) {
    final isPositive = diff >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == 'pl' ? 'Progresja od początku' : 'Progress since start',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sign${diff.toStringAsFixed(1)} $unit ($sign$percent%)',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<FlSpot> spots, double maxVal, double minVal, String unitLabel) {
    return Container(
      height: 300,
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
                    const TextStyle(color: AppColors.textDim, fontSize: 12),
                    children: [
                      TextSpan(
                        text: '${spot.y} $unitLabel',
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
                interval: (maxVal - minVal) > 5 ? null : 5,
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
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
    );
  }

  Widget _buildStatsGrid(
      BuildContext context, String lang, String unitLabel,
      int workoutCount, int totalSets, int totalReps,
      double totalVolume, String avgSets, String avgVolume) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statTile(
                  icon: Icons.calendar_today,
                  value: '$workoutCount',
                  label: lang == 'pl' ? 'Treningów' : 'Workouts',
                  color: AppColors.accent,
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white10),
              Expanded(
                child: _statTile(
                  icon: Icons.repeat,
                  value: '$totalSets',
                  label: lang == 'pl' ? 'Serii łącznie' : 'Total sets',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Divider(color: Colors.white.withOpacity(0.05), height: 24),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  icon: Icons.fitness_center,
                  value: '$totalReps',
                  label: lang == 'pl' ? 'Powtórzeń łącznie' : 'Total reps',
                  color: Colors.orange,
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white10),
              Expanded(
                child: _statTile(
                  icon: Icons.monitor_weight_outlined,
                  value: '${totalVolume.toStringAsFixed(0)} $unitLabel',
                  label: lang == 'pl' ? 'Objętość łącznie' : 'Total volume',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          Divider(color: Colors.white.withOpacity(0.05), height: 24),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  icon: Icons.show_chart,
                  value: avgSets,
                  label: lang == 'pl' ? 'Śr. serii/trening' : 'Avg sets/workout',
                  color: Colors.purple,
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white10),
              Expanded(
                child: _statTile(
                  icon: Icons.bar_chart,
                  value: '$avgVolume $unitLabel',
                  label: lang == 'pl' ? 'Śr. objętość/trening' : 'Avg vol/workout',
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: AppColors.textDim, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutHistoryItem(BuildContext context, String lang, _WorkoutDataPoint dp, String unitLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(dp.date),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(dp.date),
                  style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dp.maxWeight} $unitLabel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _miniStat(Icons.repeat, '${dp.sets} ${lang == 'pl' ? 'serii' : 'sets'}'),
                    const SizedBox(width: 12),
                    _miniStat(Icons.fitness_center, '${dp.reps} ${lang == 'pl' ? 'powt' : 'reps'}'),
                    const SizedBox(width: 12),
                    _miniStat(Icons.monitor_weight_outlined, '${dp.volume.toStringAsFixed(0)} $unitLabel'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textDim),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
      ],
    );
  }
}