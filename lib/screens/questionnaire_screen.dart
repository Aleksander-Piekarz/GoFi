import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';
import 'home_screen.dart';

class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});
  @override
  ConsumerState<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  List<dynamic> _questions = [];
  final Map<String, dynamic> _answers = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final svc = ref.read(questionnaireServiceProvider);
      final qs = await svc.getQuestions();
      final latest = await svc.getLatestAnswers();
      setState(() {
        _questions = qs;
        _answers.addAll(latest);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd kwestionariusza: $e')));
    }
  }

  bool _shouldShow(Map q) {
    final cond = q['showIf'];
    if (cond is Map) {
      for (final entry in cond.entries) {
        final key = entry.key as String;
        final allowed = (entry.value as List).map((e) => e.toString()).toList();
        final val = _answers[key]?.toString();
        if (val == null || !allowed.contains(val)) return false;
      }
    }
    return true;
  }

  Widget _buildQuestion(Map q) {
    final id = q['id'] as String;
    final type = q['type'] as String;
    final label = q['label'] as String? ?? id;

    switch (type) {
      case 'single':
        final options = (q['options'] as List).cast<Map>();
        final current = _answers[id]?.toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: options.map((opt) {
                final value = opt['value'].toString();
                return ChoiceChip(
                  label: Text(opt['label']?.toString() ?? value),
                  selected: current == value,
                  onSelected: (_) => setState(() {
                    _answers[id] = value;
                    // Reset sprzętu przy zmianie lokalizacji (UX)
                    if (id == 'location') _answers.remove('equipment');
                  }),
                );
              }).toList(),
            ),
          ],
        );

      case 'multi':
        final options = (q['options'] as List).cast<Map>();
        final current = (_answers[id] as List?)?.map((e) => e.toString()).toSet() ?? <String>{};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: options.map((opt) {
                final value = opt['value'].toString();
                final selected = current.contains(value);
                return FilterChip(
                  label: Text(opt['label']?.toString() ?? value),
                  selected: selected,
                  onSelected: (on) => setState(() {
                    final set = (_answers[id] as List?)?.map((e) => e.toString()).toSet() ?? <String>{};
                    
                    // --- POPRAWKA LOGIKI "NONE" ---
                    if (value == 'none') {
                      // Jeśli użytkownik klika "Brak":
                      if (on) {
                        set.clear();      // Usuwamy wszystko inne
                        set.add('none');  // Zaznaczamy tylko "Brak"
                      } else {
                        set.remove('none');
                      }
                    } else {
                      // Jeśli użytkownik klika cokolwiek innego (np. hantle):
                      if (on) {
                        set.remove('none'); // Automatycznie odznaczamy "Brak"
                        set.add(value);
                      } else {
                        set.remove(value);
                      }
                    }
                    // -------------------------------

                    _answers[id] = set.toList();
                  }),
                );
              }).toList(),
            ),
          ],
        );

      case 'number':
        final min = q['min'] is num ? q['min'] as num : null;
        final max = q['max'] is num ? q['max'] as num : null;
        final controller = TextEditingController(text: _answers[id]?.toString() ?? '');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: (min != null && max != null) ? '$min – $max' : null,
                border: const OutlineInputBorder(), isDense: true,
              ),
              onChanged: (v) {
                final n = int.tryParse(v);
                setState(() => _answers[id] = n);
              },
            ),
          ],
        );

      default:
        return Text('Nieobsługiwany typ: $type');
    }
  }

  Future<void> _submitAndNavigate() async {
    setState(() => _saving = true);
    try {
      for (final raw in _questions) {
        final q = raw as Map;
        if (!_shouldShow(q)) continue;
        final id = q['id'];
        final optional = (q['optional'] ?? false) as bool;
        final v = _answers[id];
        if (!optional && (v == null || (v is List && v.isEmpty))) {
          throw 'Uzupełnij: ${q['label'] ?? id}';
        }
      }

      final svc = ref.read(questionnaireServiceProvider);
      await svc.submitAndGetPlan(_answers);
      if (!mounted) return;

      ref.invalidate(planProvider);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Kwestionariusz')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: _questions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, i) {
            final q = _questions[i] as Map;
            if (!_shouldShow(q)) return const SizedBox.shrink();
            return _buildQuestion(q);
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _saving ? null : _submitAndNavigate,
          child: Text(_saving ? 'Generowanie planu…' : 'Zapisz i Generuj Plan'),
        ),
      ),
    );
  }
}