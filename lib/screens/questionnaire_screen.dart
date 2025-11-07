import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/questionnaire_service.dart';
import 'plan_screen.dart';

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
      final latest = await svc.getLatestAnswers(); // <-- PREFILL
      setState(() {
        _questions = qs;
        _answers.addAll(latest); // wstępne odpowiedzi
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
                    if (id == 'location') _answers.remove('equipment'); // czyszczenie zależnych
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
                    if (on) set.add(value); else set.remove(value);
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // prosta walidacja: wymagamy odpowiedzi dla widocznych pytań
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
      await svc.saveAnswers(_answers);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano odpowiedzi')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndGenerate() async {
  setState(() => _saving = true);
  try {
    // 1) walidacja jak w _save()
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
    final result = await svc.submitAndGetPlan(_answers);
    if (!mounted) return;

    // przejście do PlanScreen z wynikiem
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => PlanScreen(plan: result['plan'] as Map<String, dynamic>)));
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
bottomNavigationBar: SafeArea(
  minimum: const EdgeInsets.all(16),
  child: Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Zapisywanie…' : 'Zapisz'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: _saving ? null : _saveAndGenerate,
          child: Text(_saving ? 'Generowanie…' : 'Zapisz + Plan'),
        ),
      ),
    ],
  ),
),
      
    );
  }
}
