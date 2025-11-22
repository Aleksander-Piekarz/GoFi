import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/converters.dart';


typedef OnExerciseChanged = void Function(
  int dayIndex,
  int exerciseIndex,
  Map<String, dynamic> newValues,
);

class PlanView extends StatelessWidget {
  final Map<String, dynamic> plan;
  final OnExerciseChanged? onExerciseChanged;
  final String unitSystem;

  const PlanView({
    super.key,
    required this.plan,
    this.onExerciseChanged,
    this.unitSystem = 'metric',
  });

  @override
  Widget build(BuildContext context) {
    final split = plan['split']?.toString() ?? 'Brak nazwy planu';
    final week = (plan['week'] as List?) ?? const [];
    final progression = (plan['progression'] as List?) ?? const [];
    final bool isEditable = onExerciseChanged != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          split,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (isEditable)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Kliknij ikonę (i), by zobaczyć opis, lub (✎), by edytować.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        ...week.asMap().entries.map((dayEntry) {
          final int dayIndex = dayEntry.key;
          final Map d = dayEntry.value as Map;
          final day = (d['day'] ?? d['block'] ?? 'Dzień').toString();
          final exercises = (d['exercises'] as List?) ?? const [];
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Divider(height: 16),
                  if (exercises.isEmpty)
                    const Text('Brak ćwiczeń na ten dzień.')
                  else
                    ...exercises.asMap().entries.map((exEntry) {
                      final int exerciseIndex = exEntry.key;
                      final Map exercise = exEntry.value as Map;
                      return _buildExerciseTile(
                        context,
                        exercise,
                        dayIndex,
                        exerciseIndex,
                        isEditable,
                      );
                    }),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),
        Text('Progresja', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...progression.map((p) {
          final m = p as Map;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text('${m['week']}')),
            title: Text(m['note'].toString()),
          );
        }),
      ],
    );
  }

  
  Widget _buildExerciseTile(
    BuildContext context,
    Map exercise,
    int dayIndex,
    int exerciseIndex,
    bool isEditable,
  ) {
    final converter = UnitConverter(unitSystem: unitSystem);
    final name = exercise['name']?.toString() ?? 'Nieznane ćwiczenie';
    final sets = exercise['sets']?.toString() ?? '-';
    final reps = exercise['reps']?.toString() ?? '-';
final double? weightKg = double.tryParse(exercise['weight']?.toString() ?? '');
    
    final String weightString = (weightKg != null) 
      ? '${converter.displayWeight(weightKg)}${converter.unitLabel}' 
      : '-';

    final description = exercise['description'] as String?;
    final videoUrl = exercise['video_url'] as String?;
    final bool hasDetails = (description != null && description.isNotEmpty) || 
                            (videoUrl != null && videoUrl.isNotEmpty);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(Icons.fitness_center_outlined,
          color: Theme.of(context).colorScheme.primary),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$sets x $reps @ $weightString'), 
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDetails)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Pokaż opis i wideo',
              onPressed: () {
                _showExerciseDetails(context, name, description, videoUrl);
              },
            ),
          if (isEditable)
            IconButton(
              icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              tooltip: 'Edytuj ćwiczenie',
              onPressed: () {
                _showEditDialog(context, exercise, dayIndex, exerciseIndex, converter); 
              },
            ),
        ],
      ),
      onTap: null,
    );
  }

  void _showEditDialog(
    BuildContext context,
    Map exercise,
    int dayIndex,
    int exerciseIndex,
    UnitConverter converter,
  ) {
    final setsCtrl = TextEditingController(text: exercise['sets']?.toString() ?? '');
    final repsCtrl = TextEditingController(text: exercise['reps']?.toString() ?? '');
    
    
    final double? weightKg = double.tryParse(exercise['weight']?.toString() ?? '');
    final String displayWeight = (weightKg != null)
        ? converter.displayWeight(weightKg).toString()
        : '';
    final weightCtrl = TextEditingController(text: displayWeight);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edytuj: ${exercise['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: setsCtrl,
                        decoration: const InputDecoration(labelText: 'Sety'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: repsCtrl,
                        decoration: const InputDecoration(labelText: 'Powtórzenia'),
                        keyboardType: TextInputType.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: weightCtrl,
                  decoration: InputDecoration(labelText: 'Waga (${converter.unitLabel})'), 
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Anuluj'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            FilledButton(
              child: const Text('Zapisz'),
              onPressed: () {
                final displayValue = double.tryParse(weightCtrl.text) ?? 0.0;
                final kgToSave = converter.saveWeight(displayValue);
                onExerciseChanged?.call(
                  dayIndex,
                  exerciseIndex,
                  {
                    'sets': setsCtrl.text,
                    'reps': repsCtrl.text,
                    'weight': kgToSave.toString(),
                    'name': exercise['name'],
                    'code': exercise['code'],
                    'description': exercise['description'],
                    'video_url': exercise['video_url'],
                  },
                );
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  
  void _showExerciseDetails(BuildContext context, String name, String? description, String? videoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: Text(description ?? 'Brak opisu dla tego ćwiczenia.'),
        ),
        actions: [
          TextButton(
            child: const Text('Zamknij'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          if (videoUrl != null && videoUrl.isNotEmpty)
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Zobacz Wideo'),
              onPressed: () {
                _launchURL(videoUrl);
              },
            ),
        ],
      ),
    );
  }

  
  Future<void> _launchURL(String urlString) async {
    final uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('Could not launch $urlString');
    }
  }
}