import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';
import 'home_screen.dart';
import 'custom_plan_builder_screen.dart';
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  // --- NAGŁÓWEK SEKCJI ---
  Widget _buildSectionHeader(Map q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q['label'] ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          if (q['description'] != null) ...[
            const SizedBox(height: 8),
            Text(
              q['description'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- WIDOK PYTANIA ---
  Widget _buildQuestion(Map q) {
    final id = q['id'] as String;
    final type = q['type'] as String;
    final label = q['label'] as String? ?? id;
    final icon = q['icon'] as String?;
    final hint = q['hint'] as String?;

    // Dla nagłówków sekcji
    if (type == 'header') {
      return _buildSectionHeader(q);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
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
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (q['optional'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Opcjonalne',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
          const SizedBox(height: 16),
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
        
        return Column(
          children: options.map((opt) {
            final value = opt['value'].toString();
            final isSelected = current == value;
            final description = opt['description'] as String?;
            
            return GestureDetector(
              onTap: () => setState(() {
                _answers[id] = value;
                if (id == 'location') _answers.remove('equipment');
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent.withOpacity(0.15) : const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : Colors.white10,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.accent : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? AppColors.accent : Colors.white30,
                          width: 2,
                        ),
                      ),
                      child: isSelected 
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt['label']?.toString() ?? value,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          if (description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white60 : Colors.white38,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
        final type = q['type'] as String?;
        
        // Pomijamy nagłówki sekcji - nie wymagają odpowiedzi
        if (type == 'header') continue;
        
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Twój Profil',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Odpowiedz na pytania, stworzymy Twój plan',
                          style: TextStyle(fontSize: 13, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // --- PROGRESS BAR ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _calculateProgress(),
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // --- LISTA PYTAŃ ---
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _questions.length,
                itemBuilder: (_, i) {
                  final q = _questions[i] as Map;
                  if (!_shouldShow(q)) return const SizedBox.shrink();
                  if (i == _questions.length - 1) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 140),
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
      // --- FIXED BOTTOM ---
      bottomSheet: Container(
        color: AppColors.bg,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Przycisk generowania planu
            SizedBox(
              width: double.infinity,
              height: 54,
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
                            'Wygeneruj plan',
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
            const SizedBox(height: 12),
            // Przycisk własnego planu
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomPlanBuilderScreen()),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.build_outlined, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Stwórz własny plan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateProgress() {
    if (_questions.isEmpty) return 0;
    int answered = 0;
    int total = 0;
    for (final q in _questions) {
      final map = q as Map;
      if (map['type'] == 'header') continue;
      if (!_shouldShow(map)) continue;
      if (map['optional'] == true) continue;
      total++;
      final id = map['id'];
      final val = _answers[id];
      if (val != null && (val is! List || val.isNotEmpty)) {
        answered++;
      }
    }
    return total > 0 ? answered / total : 0;
  }
}