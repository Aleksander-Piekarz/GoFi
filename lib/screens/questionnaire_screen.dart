import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';
import 'home_screen.dart';
import '../app/theme.dart';

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

  // --- WIDOK PYTANIA ---
  Widget _buildQuestion(Map q) {
    final id = q['id'] as String;
    final type = q['type'] as String;
    final label = q['label'] as String? ?? id;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildInputContent(type, id, q),
        ],
      ),
    );
  }

  Widget _buildInputContent(String type, String id, Map q) {
    switch (type) {
      case 'single':
        final options = (q['options'] as List).cast<Map>();
        final current = _answers[id]?.toString();
        
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.map((opt) {
            final value = opt['value'].toString();
            final isSelected = current == value;
            
            return _buildModernChip(
              label: opt['label']?.toString() ?? value,
              isSelected: isSelected,
              onTap: () => setState(() {
                _answers[id] = value;
                if (id == 'location') _answers.remove('equipment');
              }),
            );
          }).toList(),
        );

      case 'multi':
        final options = (q['options'] as List).cast<Map>();
        final current = (_answers[id] as List?)?.map((e) => e.toString()).toSet() ?? <String>{};
        
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.map((opt) {
            final value = opt['value'].toString();
            final isSelected = current.contains(value);

            return _buildModernChip(
              label: opt['label']?.toString() ?? value,
              isSelected: isSelected,
              isMulti: true,
              onTap: () => setState(() {
                final set = (_answers[id] as List?)?.map((e) => e.toString()).toSet() ?? <String>{};
                
                if (value == 'none') {
                  if (!isSelected) { 
                    set.clear();
                    set.add('none');
                  } else {
                    set.remove('none');
                  }
                } else {
                  if (!isSelected) { 
                    set.remove('none');
                    set.add(value);
                  } else {
                    set.remove(value);
                  }
                }
                _answers[id] = set.toList();
              }),
            );
          }).toList(),
        );

      case 'number':
        final min = q['min'] is num ? q['min'] as num : null;
        final max = q['max'] is num ? q['max'] as num : null;
        
        return Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: AppColors.accent,
              selectionColor: Color(0x55FD605B),
            ),
          ),
          child: TextFormField(
            initialValue: _answers[id]?.toString() ?? '',
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bg,
              hintText: '0',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              helperText: (min != null && max != null) ? 'Przedział: $min - $max' : null,
              helperStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: const Icon(Icons.tag, color: Colors.white24),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
            onChanged: (v) {
              final n = int.tryParse(v);
              _answers[id] = n;
            },
          ),
        );

      default:
        return Text('Nieznany typ: $type', style: const TextStyle(color: Colors.red));
    }
  }

  // --- NOWOCZESNY CHIP (NAPRAWIONY OVERFLOW) ---
  Widget _buildModernChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isMulti = false,
  }) {
    // Obliczamy bezpieczną szerokość dla elementu
    // Szerokość ekranu - paddingi ekranu (40) - paddingi karty (48) - margines błędu
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 100; 

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        constraints: BoxConstraints(maxWidth: availableWidth), // KLUCZOWA ZMIANA
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white10,
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center, // Wyrównanie do środka
          children: [
            if (isMulti) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white38,
                    width: 2,
                  ),
                ),
                child: isSelected 
                  ? const Icon(Icons.check, size: 14, color: AppColors.accent)
                  : null,
              ),
              const SizedBox(width: 12),
            ],
            // Flexible pozwala tekstowi się zwijać wewnątrz Row
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15,
                  height: 1.2, // Lepszy odstęp między liniami
                ),
                softWrap: true, // Zezwalamy na zawijanie
                maxLines: 4,    // Maksymalnie 4 linie tekstu (dla bardzo długich opcji)
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
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
          throw 'Uzupełnij pole: ${q['label'] ?? id}';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        )
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Twój Profil',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // --- LISTA PYTAŃ ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _questions.length,
                itemBuilder: (_, i) {
                  final q = _questions[i] as Map;
                  if (!_shouldShow(q)) return const SizedBox.shrink();
                  // Dodajemy padding na dole ostatniego elementu
                  if (i == _questions.length - 1) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: _buildQuestion(q),
                    );
                  }
                  return _buildQuestion(q);
                },
              ),
            ),
          ],
        ),
      ),
      // --- FIXED BOTTOM BUTTON ---
      bottomSheet: Container(
        color: AppColors.bg,
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: AppColors.accent.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _saving ? null : _submitAndNavigate,
            child: _saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome),
                      SizedBox(width: 10),
                      Text(
                        'Generuj Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}