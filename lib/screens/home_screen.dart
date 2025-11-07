// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_screen.dart';
import '../services/api/questionnaire_service.dart';

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
        automaticallyImplyLeading: false, // <-- usuwa strzałkę
        title: const Text('GoFi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeTab(),
          _StatsTab(),
          _PlanTab(), // <-- nasz plan
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: theme.colorScheme.secondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Statystyki',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Plan',
          ),
        ],
      ),
    );
  }
}

// --- zakładka Home (placeholder) ---
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Strona główna'),
    );
  }
}

// --- zakładka Statystyki (placeholder) ---
class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Statystyki (w budowie)'),
    );
  }
}

// --- zakładka Plan: pobiera ostatni plan z API i wyświetla ---
class _PlanTab extends ConsumerStatefulWidget {
  const _PlanTab();

  @override
  ConsumerState<_PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends ConsumerState<_PlanTab> {
  bool _loading = true;
  Map<String, dynamic>? _plan;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(questionnaireServiceProvider);
      final plan = await svc.getLatestPlan();
      if (!mounted) return;
      if (plan.isEmpty) {
        setState(() {
          _plan = null;
          _loading = false;
        });
      } else {
        setState(() {
          _plan = plan;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Błąd pobierania planu:\n$_error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadPlan,
                child: const Text('Spróbuj ponownie'),
              ),
            ],
          ),
        ),
      );
    }
    if (_plan == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Brak planu.\nWypełnij kwestionariusz, aby wygenerować pierwszy plan.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final split = _plan!['split']?.toString() ?? '-';
    final week = (_plan!['week'] as List?) ?? const [];
    final progression = (_plan!['progression'] as List?) ?? const [];

    return RefreshIndicator(
      onRefresh: _loadPlan,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Split: $split',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          // dni tygodnia
          ...week.map((d) {
            final m = d as Map;
            final day = (m['day'] ?? m['block'] ?? 'Dzień').toString();
            final exercises = (m['exercises'] as List?) ?? const [];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...exercises.map((e) {
                      final ex = e as Map;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '• ${ex['name']} — ${ex['sets']}x${ex['reps']}',
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          Text('Progresja',
              style: Theme.of(context).textTheme.titleMedium),
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
