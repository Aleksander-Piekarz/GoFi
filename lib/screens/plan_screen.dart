import 'package:flutter/material.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key, required this.plan});
  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final split = plan['split']?.toString() ?? '-';
    final week = (plan['week'] as List?) ?? const [];
    final progression = (plan['progression'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Twój Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Split: $split', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...week.map((d) {
            final day = (d as Map)['day'] ?? (d)['block'] ?? 'Dzień';
            final exercises = (d['exercises'] as List?) ?? const [];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...exercises.map((e) {
                      final m = e as Map;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('• ${m['name']} — ${m['sets']}x${m['reps']}'),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text('Progresja', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...progression.map((p) {
            final m = p as Map;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${m['week']}')),
              title: Text(m['note'].toString()),
            );
          }),
        ],
      ),
    );
  }
}
