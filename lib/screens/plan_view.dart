import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../services/api/providers.dart';
import '../utils/language_settings.dart';
import '../models/exercise.dart';
import '../widgets/exercise_image.dart';
import 'exercise_detail_screen.dart';

/// Helper do wyciągnięcia nazwy ćwiczenia (obsługuje różne formaty)
String _getExerciseName(dynamic exercise, [String lang = 'pl']) {
  if (exercise == null) return 'Nieznane';
  if (exercise is String) return exercise;
  if (exercise is Map) {
    final name = exercise['name'];
    if (name is String) return name;
    if (name is Map) {
      return name[lang]?.toString() ?? name['en']?.toString() ?? name['pl']?.toString() ?? 'Nieznane';
    }
    return exercise['name_$lang']?.toString() ?? 
           exercise['name_en']?.toString() ?? 
           exercise['name_pl']?.toString() ?? 
           exercise['code']?.toString() ?? 
           'Nieznane';
  }
  return exercise.toString();
}

typedef OnExerciseChanged = void Function(
  int dayIndex,
  int exerciseIndex,
  Map<String, dynamic> newValues,
);

typedef OnExerciseAdded = void Function(
  int dayIndex,
  Map<String, dynamic> exercise,
);

typedef OnExerciseRemoved = void Function(
  int dayIndex,
  int exerciseIndex,
);

typedef OnDayAdded = void Function(Map<String, dynamic> day);
typedef OnDayRemoved = void Function(int dayIndex);
typedef OnDayChanged = void Function(int dayIndex, Map<String, dynamic> newDayData);
typedef OnPlanExport = void Function();
typedef OnPlanImport = void Function();

class PlanView extends ConsumerWidget {
  final Map<String, dynamic> plan;
  final OnExerciseChanged? onExerciseChanged;
  final OnExerciseAdded? onExerciseAdded;
  final OnExerciseRemoved? onExerciseRemoved;
  final OnDayAdded? onDayAdded;
  final OnDayRemoved? onDayRemoved;
  final OnDayChanged? onDayChanged;
  final OnPlanExport? onPlanExport;
  final OnPlanImport? onPlanImport;
  final String unitSystem;

  const PlanView({
    super.key,
    required this.plan,
    this.onExerciseChanged,
    this.onExerciseAdded,
    this.onExerciseRemoved,
    this.onDayAdded,
    this.onDayRemoved,
    this.onDayChanged,
    this.onPlanExport,
    this.onPlanImport,
    this.unitSystem = 'metric',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obsługa obu kluczy: 'split' i 'splitName' (kompatybilność z różnymi źródłami)
    String split = plan['split']?.toString() ?? plan['splitName']?.toString() ?? 'Twój Plan';
    
    // Dodaj "(FB)" jeśli użyto fallback (lokalnego algorytmu zamiast AI)
    final usedFallback = plan['usedFallback'] == true;
    if (usedFallback) {
      split = '$split (FB)';
    }
    
    final week = (plan['week'] as List?) ?? const [];
    final isEditable = onExerciseChanged != null;
    final lang = ref.watch(languageProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // --- NAGŁÓWEK PLANU ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentSecondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            split.toUpperCase(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AppColors.accent,
                                ),
                          ),
                        ),
                        if (usedFallback) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: lang == 'pl' 
                                ? 'Plan wygenerowany lokalnie (Fallback)\nAI było niedostępne'
                                : 'Plan generated locally (Fallback)\nAI was unavailable',
                            child: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.orange[400],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang == 'pl' ? 'Harmonogram tygodniowy' : 'Weekly Schedule',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        if (isEditable)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withOpacity(0.08),
                  AppColors.accentSecondary.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.touch_app_rounded, size: 16, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang == 'pl' 
                        ? 'Dotknij ćwiczenia, aby edytować'
                        : 'Tap exercise to edit',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        
        // --- PRZYCISKI EXPORT/IMPORT ---
        if (isEditable && (onPlanExport != null || onPlanImport != null))
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                if (onPlanExport != null)
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.ios_share_rounded,
                      label: lang == 'pl' ? 'Eksportuj' : 'Export',
                      onTap: onPlanExport!,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                if (onPlanExport != null && onPlanImport != null)
                  Container(
                    width: 1,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.white.withOpacity(0.1),
                  ),
                if (onPlanImport != null)
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.folder_open_rounded,
                      label: lang == 'pl' ? 'Importuj' : 'Import',
                      onTap: onPlanImport!,
                      color: const Color(0xFF2196F3),
                    ),
                  ),
              ],
            ),
          ),

        // --- LISTA DNI ---
        ...week.asMap().entries.map((dayEntry) {
          final int dayIndex = dayEntry.key;
          final Map d = dayEntry.value as Map;
          final exercises = (d['exercises'] as List?) ?? const [];
          
          if (exercises.isEmpty) {
            return _buildRestDayCard(context, d, dayIndex, isEditable, ref);
          }

          return _buildWorkoutDayCard(
            context,
            ref,
            d,
            exercises,
            dayIndex,
            isEditable,
          );
        }),
        
        // --- PRZYCISK DODAJ DZIEŃ ---
        if (isEditable && onDayAdded != null)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 24),
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddDayDialog(context, ref),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.15),
                        AppColors.accentSecondary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        lang == 'pl' ? 'Dodaj dzień treningowy' : 'Add training day',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddDayDialog(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(languageProvider);
    final focusCtrl = TextEditingController();
    String? selectedDay;
    
    final daysOfWeek = lang == 'pl' 
        ? ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela']
        : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    final daysOfWeekEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final daysOfWeekPl = ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'];
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(lang == 'pl' ? 'Nowy dzień' : 'New day'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang == 'pl' ? 'Wybierz dzień tygodnia:' : 'Select day of week:',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedDay,
                    hint: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        lang == 'pl' ? 'Wybierz dzień...' : 'Select day...',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.arrow_drop_down, color: AppColors.accent),
                    ),
                    items: daysOfWeek.map((day) {
                      return DropdownMenuItem(
                        value: day,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(day, style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedDay = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                lang == 'pl' ? 'Focus (opcjonalnie):' : 'Focus (optional):',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: focusCtrl,
                decoration: InputDecoration(
                  hintText: lang == 'pl' ? 'np. Klatka, Barki' : 'e.g. Chest, Shoulders',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang == 'pl' ? 'Anuluj' : 'Cancel'),
            ),
            FilledButton(
              onPressed: selectedDay == null ? null : () {
                final dayIndex = daysOfWeek.indexOf(selectedDay!);
                Navigator.pop(ctx, {
                  'day': selectedDay,
                  'dayName': selectedDay,
                  'day_en': daysOfWeekEn[dayIndex],
                  'day_pl': daysOfWeekPl[dayIndex],
                  'dayIndex': dayIndex,
                  'focus': focusCtrl.text,
                  'exercises': [],
                  'estimatedDuration': 0,
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: selectedDay == null ? Colors.grey[700] : AppColors.accent,
              ),
              child: Text(lang == 'pl' ? 'Dodaj' : 'Add'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      onDayAdded?.call(result);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestDayCard(BuildContext context, Map dayData, int dayIndex, bool isEditable, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    // Get localized day name
    final dayName = lang == 'pl' 
        ? (dayData['day_pl'] ?? dayData['day'] ?? dayData['block'] ?? 'Dzień').toString()
        : (dayData['day_en'] ?? dayData['day'] ?? dayData['block'] ?? 'Day').toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3D2F).withOpacity(0.4),
            const Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.greenAccent.withOpacity(0.2),
                        Colors.tealAccent.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.self_improvement_rounded, color: Colors.greenAccent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lang == 'pl' ? '😴 Regeneracja' : '😴 Rest day',
                          style: TextStyle(color: Colors.greenAccent[200], fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEditable && onDayRemoved != null)
                  _buildDeleteButton(() => _confirmDeleteDay(context, ref, dayIndex)),
              ],
            ),
          ),
          if (isEditable && onExerciseAdded != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildAddExerciseButton(
                context,
                lang,
                () => _showAddExerciseDialog(context, ref, dayIndex),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeleteButton(VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
        ),
      ),
    );
  }

  Widget _buildAddExerciseButton(BuildContext context, String lang, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: AppColors.accent.withOpacity(0.8), size: 18),
              const SizedBox(width: 8),
              Text(
                lang == 'pl' ? 'Dodaj ćwiczenie' : 'Add exercise',
                style: TextStyle(
                  color: AppColors.accent.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDay(BuildContext context, WidgetRef ref, int dayIndex) async {
    final lang = ref.read(languageProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(lang == 'pl' ? 'Usuń dzień?' : 'Delete day?'),
        content: Text(lang == 'pl' ? 'Czy na pewno chcesz usunąć ten dzień z planu?' : 'Are you sure you want to delete this day from the plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang == 'pl' ? 'Anuluj' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang == 'pl' ? 'Usuń' : 'Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      onDayRemoved?.call(dayIndex);
    }
  }

  Future<void> _showEditDayDialog(BuildContext context, WidgetRef ref, int dayIndex, Map dayData) async {
    final lang = ref.read(languageProvider);
    final focusCtrl = TextEditingController(text: (dayData['focus'] ?? '').toString());
    
    final currentDayName = lang == 'pl'
        ? (dayData['day_pl'] ?? dayData['day'] ?? '').toString()
        : (dayData['day_en'] ?? dayData['day'] ?? '').toString();
    
    String? selectedDay = currentDayName;
    
    final daysOfWeek = lang == 'pl' 
        ? ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela']
        : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    final daysOfWeekEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final daysOfWeekPl = ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'];
    
    // Upewnij się, że selectedDay jest w liście
    if (!daysOfWeek.contains(selectedDay)) {
      selectedDay = null;
    }
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_calendar_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(lang == 'pl' ? 'Edytuj dzień' : 'Edit day'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang == 'pl' ? 'Dzień tygodnia:' : 'Day of week:',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedDay,
                    hint: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        lang == 'pl' ? 'Wybierz dzień...' : 'Select day...',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.arrow_drop_down, color: AppColors.accent),
                    ),
                    items: daysOfWeek.map((day) {
                      return DropdownMenuItem(
                        value: day,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(day, style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedDay = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                lang == 'pl' ? 'Focus (opcjonalnie):' : 'Focus (optional):',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: focusCtrl,
                decoration: InputDecoration(
                  hintText: lang == 'pl' ? 'np. Klatka, Barki' : 'e.g. Chest, Shoulders',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang == 'pl' ? 'Anuluj' : 'Cancel'),
            ),
            FilledButton(
              onPressed: selectedDay == null ? null : () {
                final dayIdx = daysOfWeek.indexOf(selectedDay!);
                final newDayData = Map<String, dynamic>.from(dayData);
                newDayData['day'] = selectedDay;
                newDayData['dayName'] = selectedDay;
                newDayData['day_en'] = daysOfWeekEn[dayIdx];
                newDayData['day_pl'] = daysOfWeekPl[dayIdx];
                newDayData['dayIndex'] = dayIdx;
                newDayData['focus'] = focusCtrl.text;
                Navigator.pop(ctx, newDayData);
              },
              style: FilledButton.styleFrom(
                backgroundColor: selectedDay == null ? Colors.grey[700] : AppColors.accent,
              ),
              child: Text(lang == 'pl' ? 'Zapisz' : 'Save'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      onDayChanged?.call(dayIndex, result);
    }
  }

  Future<void> _showAddExerciseDialog(BuildContext context, WidgetRef ref, int dayIndex) async {
    final selected = await _showExerciseLibraryPicker(context, ref);
    if (selected != null) {
      final newExercise = <String, dynamic>{
        'code': selected.code,
        'name': selected.getName('pl'),
        'name_en': selected.getName('en'),
        'name_pl': selected.getName('pl'),
        'pattern': selected.pattern,
        'primary_muscle': selected.primaryMuscle,
        'equipment': selected.equipment,
        'sets': '3',
        'reps': '10',
        'rest': '90',
      };
      onExerciseAdded?.call(dayIndex, newExercise);
    }
  }

  Future<void> _confirmDeleteExercise(BuildContext context, WidgetRef ref, int dayIndex, int exerciseIndex) async {
    final lang = ref.read(languageProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(lang == 'pl' ? 'Usuń ćwiczenie?' : 'Delete exercise?'),
        content: Text(lang == 'pl' ? 'Czy na pewno chcesz usunąć to ćwiczenie?' : 'Are you sure you want to delete this exercise?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang == 'pl' ? 'Anuluj' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang == 'pl' ? 'Usuń' : 'Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      onExerciseRemoved?.call(dayIndex, exerciseIndex);
    }
  }

  Widget _buildWorkoutDayCard(
    BuildContext context,
    WidgetRef ref,
    Map dayData,
    List exercises,
    int dayIndex,
    bool isEditable,
  ) {
    final lang = ref.watch(languageProvider);
    // Get localized day name
    final dayName = lang == 'pl' 
        ? (dayData['day_pl'] ?? dayData['day'] ?? dayData['block'] ?? 'Dzień').toString()
        : (dayData['day_en'] ?? dayData['day'] ?? dayData['block'] ?? 'Day').toString();
    final focus = (dayData['focus'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nagłówek dnia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withOpacity(0.15),
                  AppColors.accentSecondary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent.withOpacity(0.25),
                              AppColors.accentSecondary.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.fitness_center_rounded, color: AppColors.accent, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            if (focus.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                focus,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.format_list_numbered_rounded, size: 14, color: AppColors.accent.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Text(
                            '${exercises.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isEditable && onDayChanged != null) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showEditDayDialog(context, ref, dayIndex, dayData),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_rounded, color: AppColors.accent, size: 20),
                          ),
                        ),
                      ),
                    ],
                    if (isEditable && onDayRemoved != null) ...[
                      const SizedBox(width: 10),
                      _buildDeleteButton(() => _confirmDeleteDay(context, ref, dayIndex)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Lista ćwiczeń
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            itemCount: exercises.length,
            separatorBuilder: (ctx, i) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
            itemBuilder: (ctx, i) {
              return _buildExerciseRow(
                context,
                ref,
                exercises[i] as Map,
                dayIndex,
                i,
                isEditable,
              );
            },
          ),
          
          // Przycisk dodawania ćwiczenia
          if (isEditable && onExerciseAdded != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _buildAddExerciseButton(
                context,
                lang,
                () => _showAddExerciseDialog(context, ref, dayIndex),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(
    BuildContext context,
    WidgetRef ref,
    Map exercise,
    int dayIndex,
    int exerciseIndex,
    bool isEditable,
  ) {
    final lang = ref.watch(languageProvider);
    final name = _getExerciseName(exercise, lang);
    final sets = exercise['sets']?.toString() ?? '0';
    final reps = exercise['reps']?.toString() ?? '0';
    final exerciseCode = exercise['code']?.toString() ?? '';
    
    // Check if exercise has code to show details
    final bool hasCode = exerciseCode.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Numer ćwiczenia
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withOpacity(0.2),
                  AppColors.accentSecondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${exerciseIndex + 1}',
              style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          
          // Treść
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildStatBadge(context, sets, lang == 'pl' ? 'serii' : 'sets'),
                    const SizedBox(width: 8),
                    _buildStatBadge(context, reps, lang == 'pl' ? 'powt' : 'reps'),
                  ],
                )
              ],
            ),
          ),

          // Akcje (Info / Edit / Delete) - w poziomie
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasCode)
                _buildActionIconButton(
                  icon: Icons.info_outline_rounded,
                  color: Colors.white38,
                  onTap: () => _navigateToExerciseDetails(context, exerciseCode, name),
                ),
              if (isEditable)
                _buildActionIconButton(
                  icon: Icons.edit_rounded,
                  color: AppColors.accent,
                  onTap: () => _showEditDialog(context, ref, exercise, dayIndex, exerciseIndex),
                ),
              if (isEditable && onExerciseRemoved != null)
                _buildActionIconButton(
                  icon: Icons.close_rounded,
                  color: Colors.red.withOpacity(0.8),
                  onTap: () => _confirmDeleteExercise(context, ref, dayIndex, exerciseIndex),
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label.toLowerCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // --- DIALOGI I LOGIKA EDYCJI ---

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Map currentExercise,
    int dayIndex,
    int exerciseIndex,
  ) {
    final setsCtrl = TextEditingController(text: currentExercise['sets']?.toString() ?? '');
    final repsCtrl = TextEditingController(text: currentExercise['reps']?.toString() ?? '');
    final restCtrl = TextEditingController(text: currentExercise['rest']?.toString() ?? '90');
    final lang = ref.read(languageProvider);
    
    // Zmienne stanu dialogu
    List<Map<String, dynamic>> alternatives = [];
    bool isLoadingAlts = true;
    bool requestSent = false;
    Map<String, dynamic>? selectedAlternative; // Jeśli null, używamy currentExercise

    // Helper to safely get equipment string
    String _getEquipmentString(dynamic equipment) {
      if (equipment == null) return '-';
      if (equipment is String) return equipment;
      if (equipment is List) {
        return equipment.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).join(', ');
      }
      return '-';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Pierwsze uruchomienie wewnątrz dialogu - pobranie danych
            if (isLoadingAlts && !requestSent) {
              requestSent = true;
              ref.read(exerciseServiceProvider).getAlternatives(currentExercise['code']?.toString() ?? '')
                .then((alts) {
                  if (context.mounted) {
                    setDialogState(() {
                      alternatives = alts;
                      isLoadingAlts = false;
                    });
                  }
                }).catchError((e) {
                  if (context.mounted) {
                    setDialogState(() {
                      alternatives = [];
                      isLoadingAlts = false;
                    });
                  }
                });
            }

            final activeExercise = selectedAlternative ?? currentExercise;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                lang == 'pl' ? 'Edytuj ćwiczenie' : 'Edit exercise',
                style: const TextStyle(fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- ZMIANA PARAMETRÓW ---
                      Text(
                        lang == 'pl' ? 'Parametry treningowe:' : 'Training parameters:',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: setsCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: lang == 'pl' ? 'Serie' : 'Sets',
                                filled: true,
                                fillColor: Colors.black12,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: repsCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: lang == 'pl' ? 'Powtórzenia' : 'Reps',
                                filled: true,
                                fillColor: Colors.black12,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: TextInputType.text,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // --- PRZERWA MIĘDZY SERIAMI ---
                      TextField(
                        controller: restCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: lang == 'pl' ? 'Przerwa między seriami (sekundy)' : 'Rest between sets (seconds)',
                          filled: true,
                          fillColor: Colors.black12,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: 's',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),

                      // --- WYBÓR ĆWICZENIA ---
                      Text(
                        lang == 'pl' ? 'Wymień ćwiczenie na inne:' : 'Swap exercise for another:',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      
                      // Obecnie wybrane
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _getExerciseName(activeExercise, lang),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Lista alternatyw
                      if (isLoadingAlts)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ))
                      else if (alternatives.isEmpty)
                        Text(
                          lang == 'pl' 
                            ? 'Brak dostępnych alternatyw dla tego ćwiczenia.'
                            : 'No alternatives available for this exercise.',
                          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        )
                      else
                        ...alternatives.map((alt) {
                          // Nie pokazujemy na liście tego, co jest aktualnie wybrane
                          final altCode = alt['code']?.toString();
                          final activeCode = activeExercise['code']?.toString();
                          if (altCode != null && altCode == activeCode) return const SizedBox.shrink();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.swap_horiz, color: Colors.grey),
                            title: Text(
                              _getExerciseName(alt, lang),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            subtitle: Text(
                              '${lang == 'pl' ? 'Sprzęt' : 'Equipment'}: ${_getEquipmentString(alt['equipment'])}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            onTap: () {
                              setDialogState(() {
                                selectedAlternative = Map<String, dynamic>.from(alt);
                              });
                            },
                          );
                        }),
                        
                        // Opcja powrotu do oryginału
                        if (selectedAlternative != null && selectedAlternative!['code']?.toString() != currentExercise['code']?.toString())
                           ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.undo, color: Colors.orangeAccent),
                            title: Text(
                              '${lang == 'pl' ? 'Przywróć' : 'Restore'}: ${_getExerciseName(currentExercise, lang)}',
                              style: const TextStyle(color: Colors.orangeAccent),
                            ),
                            onTap: () {
                              setDialogState(() {
                                selectedAlternative = null; // Reset do oryginału
                              });
                            },
                          ),
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),
                      
                      // Przycisk do pełnej biblioteki ćwiczeń
                      Text(
                        lang == 'pl' ? 'Lub wybierz z biblioteki:' : 'Or choose from library:',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop(); // Zamknij dialog
                          final selected = await _showExerciseLibraryPicker(context, ref);
                          if (selected != null) {
                            final newExerciseData = <String, dynamic>{
                              'code': selected.code,
                              'name': selected.getName(lang),
                              'name_en': selected.getName('en'),
                              'name_pl': selected.getName('pl'),
                              'pattern': selected.pattern,
                              'primary_muscle': selected.primaryMuscle,
                              'equipment': selected.equipment,
                              'sets': setsCtrl.text.isNotEmpty ? setsCtrl.text : currentExercise['sets']?.toString() ?? '3',
                              'reps': repsCtrl.text.isNotEmpty ? repsCtrl.text : currentExercise['reps']?.toString() ?? '8-12',
                              'rest': restCtrl.text.isNotEmpty ? restCtrl.text : currentExercise['rest']?.toString() ?? '90',
                            };
                            onExerciseChanged?.call(dayIndex, exerciseIndex, newExerciseData);
                          }
                        },
                        icon: const Icon(Icons.fitness_center, size: 18),
                        label: Text(lang == 'pl' ? 'Przeglądaj wszystkie ćwiczenia' : 'Browse all exercises'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Przycisk tworzenia własnego ćwiczenia
                      Text(
                        lang == 'pl' ? 'Lub dodaj własne ćwiczenie:' : 'Or add your own exercise:',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          // Zapisz wartości PRZED zamknięciem dialogu
                          final savedSets = setsCtrl.text.isNotEmpty ? setsCtrl.text : '3';
                          final savedReps = repsCtrl.text.isNotEmpty ? repsCtrl.text : '10';
                          final savedRest = restCtrl.text.isNotEmpty ? restCtrl.text : '90';
                          
                          Navigator.of(ctx).pop();
                          final customExercise = await _showCreateCustomExerciseDialog(context, ref);
                          if (customExercise != null) {
                            final newExerciseData = <String, dynamic>{
                              'code': 'custom_${customExercise['id']}',
                              'name': customExercise['name_pl'] ?? customExercise['name_en'],
                              'name_en': customExercise['name_en'],
                              'name_pl': customExercise['name_pl'],
                              'pattern': customExercise['pattern'] ?? 'accessory',
                              'primary_muscle': customExercise['primary_muscle'] ?? 'other',
                              'equipment': customExercise['equipment'] ?? 'body weight',
                              'sets': savedSets,
                              'reps': savedReps,
                              'rest': savedRest,
                              'is_custom': true,
                              'custom_exercise_id': customExercise['id'],
                            };
                            onExerciseChanged?.call(dayIndex, exerciseIndex, newExerciseData);
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: Text(lang == 'pl' ? 'Utwórz własne ćwiczenie' : 'Create custom exercise'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text(
                    lang == 'pl' ? 'Anuluj' : 'Cancel',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                FilledButton(
                  child: Text(lang == 'pl' ? 'Zapisz zmiany' : 'Save changes'),
                  onPressed: () {
                    final baseExercise = selectedAlternative ?? currentExercise;
                    
                    final newExerciseData = <String, dynamic>{};
                    baseExercise.forEach((key, value) {
                      newExerciseData[key.toString()] = value;
                    });
                    newExerciseData['sets'] = setsCtrl.text;
                    newExerciseData['reps'] = repsCtrl.text;
                    newExerciseData['rest'] = restCtrl.text.isNotEmpty ? restCtrl.text : '90';

                    onExerciseChanged?.call(
                      dayIndex,
                      exerciseIndex,
                      newExerciseData,
                    );
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToExerciseDetails(BuildContext context, String exerciseCode, String exerciseName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exerciseCode: exerciseCode,
          exerciseName: exerciseName,
        ),
      ),
    );
  }

  /// Pokazuje dialog do tworzenia własnego ćwiczenia
  Future<Map<String, dynamic>?> _showCreateCustomExerciseDialog(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(languageProvider);
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '10');
    final notesCtrl = TextEditingController();
    
    String selectedMuscle = 'chest';
    String selectedEquipment = 'body weight';
    String selectedPattern = 'accessory';
    
    final muscleGroups = [
      {'value': 'chest', 'label_pl': 'Klatka', 'label_en': 'Chest'},
      {'value': 'back', 'label_pl': 'Plecy', 'label_en': 'Back'},
      {'value': 'shoulders', 'label_pl': 'Barki', 'label_en': 'Shoulders'},
      {'value': 'biceps', 'label_pl': 'Biceps', 'label_en': 'Biceps'},
      {'value': 'triceps', 'label_pl': 'Triceps', 'label_en': 'Triceps'},
      {'value': 'quads', 'label_pl': 'Nogi - przód', 'label_en': 'Quads'},
      {'value': 'hamstrings', 'label_pl': 'Nogi - tył', 'label_en': 'Hamstrings'},
      {'value': 'glutes', 'label_pl': 'Pośladki', 'label_en': 'Glutes'},
      {'value': 'abs', 'label_pl': 'Brzuch', 'label_en': 'Abs'},
      {'value': 'calves', 'label_pl': 'Łydki', 'label_en': 'Calves'},
      {'value': 'forearms', 'label_pl': 'Przedramiona', 'label_en': 'Forearms'},
      {'value': 'other', 'label_pl': 'Inne', 'label_en': 'Other'},
    ];
    
    final equipmentTypes = [
      {'value': 'body weight', 'label_pl': 'Masa ciała', 'label_en': 'Body weight'},
      {'value': 'barbell', 'label_pl': 'Sztanga', 'label_en': 'Barbell'},
      {'value': 'dumbbell', 'label_pl': 'Hantle', 'label_en': 'Dumbbell'},
      {'value': 'cable', 'label_pl': 'Wyciąg', 'label_en': 'Cable'},
      {'value': 'machine', 'label_pl': 'Maszyna', 'label_en': 'Machine'},
      {'value': 'kettlebell', 'label_pl': 'Kettlebell', 'label_en': 'Kettlebell'},
      {'value': 'resistance band', 'label_pl': 'Guma', 'label_en': 'Resistance band'},
    ];
    
    final patternTypes = [
      {'value': 'compound', 'label_pl': 'Złożone', 'label_en': 'Compound'},
      {'value': 'accessory', 'label_pl': 'Izolowane', 'label_en': 'Accessory'},
    ];

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            lang == 'pl' ? 'Dodaj własne ćwiczenie' : 'Add custom exercise',
            style: const TextStyle(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nazwa ćwiczenia
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: lang == 'pl' ? 'Nazwa ćwiczenia *' : 'Exercise name *',
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Partia mięśniowa
                Text(
                  lang == 'pl' ? 'Partia mięśniowa:' : 'Muscle group:',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedMuscle,
                  dropdownColor: const Color(0xFF2A2A2A),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: muscleGroups.map((m) => DropdownMenuItem(
                    value: m['value'] as String,
                    child: Text(lang == 'pl' ? m['label_pl'] as String : m['label_en'] as String),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedMuscle = v ?? 'chest'),
                ),
                
                const SizedBox(height: 16),
                
                // Sprzęt
                Text(
                  lang == 'pl' ? 'Sprzęt:' : 'Equipment:',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedEquipment,
                  dropdownColor: const Color(0xFF2A2A2A),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: equipmentTypes.map((e) => DropdownMenuItem(
                    value: e['value'] as String,
                    child: Text(lang == 'pl' ? e['label_pl'] as String : e['label_en'] as String),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedEquipment = v ?? 'body weight'),
                ),
                
                const SizedBox(height: 16),
                
                // Typ ćwiczenia
                Text(
                  lang == 'pl' ? 'Typ ćwiczenia:' : 'Exercise type:',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPattern,
                  dropdownColor: const Color(0xFF2A2A2A),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: patternTypes.map((p) => DropdownMenuItem(
                    value: p['value'] as String,
                    child: Text(lang == 'pl' ? p['label_pl'] as String : p['label_en'] as String),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedPattern = v ?? 'accessory'),
                ),
                
                const SizedBox(height: 16),
                
                // Serie i powtórzenia
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: setsCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: lang == 'pl' ? 'Serie' : 'Sets',
                          filled: true,
                          fillColor: Colors.black12,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: repsCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: lang == 'pl' ? 'Powtórzenia' : 'Reps',
                          filled: true,
                          fillColor: Colors.black12,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Notatki
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: lang == 'pl' ? 'Notatki (opcjonalnie)' : 'Notes (optional)',
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                lang == 'pl' ? 'Anuluj' : 'Cancel',
                style: const TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            FilledButton(
              child: Text(lang == 'pl' ? 'Dodaj' : 'Add'),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'pl' ? 'Podaj nazwę ćwiczenia' : 'Enter exercise name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                try {
                  // Utwórz ćwiczenie przez API
                  final result = await ref.read(exerciseServiceProvider).createCustomExercise(
                    nameEn: nameCtrl.text.trim(),
                    namePl: nameCtrl.text.trim(),
                    primaryMuscle: selectedMuscle,
                    equipment: selectedEquipment,
                    pattern: selectedPattern,
                    setsDefault: int.tryParse(setsCtrl.text) ?? 3,
                    repsDefault: int.tryParse(repsCtrl.text) ?? 10,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  
                  Navigator.of(ctx).pop({
                    'id': result['id'],
                    'name_en': nameCtrl.text.trim(),
                    'name_pl': nameCtrl.text.trim(),
                    'primary_muscle': selectedMuscle,
                    'equipment': selectedEquipment,
                    'pattern': selectedPattern,
                    'sets_default': int.tryParse(setsCtrl.text) ?? 3,
                    'reps_default': int.tryParse(repsCtrl.text) ?? 10,
                    'notes': notesCtrl.text.trim(),
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'pl' ? 'Błąd tworzenia ćwiczenia: $e' : 'Error creating exercise: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pokazuje picker z pełną biblioteką ćwiczeń
  Future<Exercise?> _showExerciseLibraryPicker(BuildContext context, WidgetRef ref) async {
    // Pokaż loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    List<Exercise> exercises = [];
    try {
      final exerciseService = ref.read(exerciseServiceProvider);
      
      // Pobierz standardowe ćwiczenia
      final standardExercises = await exerciseService.getAllExercises(limit: 200)
          .timeout(const Duration(seconds: 10));
      
      // Pobierz własne ćwiczenia użytkownika
      final customExercisesRaw = await exerciseService.getCustomExercises();
      
      // Konwertuj własne ćwiczenia na model Exercise
      final customExercises = customExercisesRaw.map((raw) {
        final json = Map<String, dynamic>.from(raw);
        return Exercise.fromJson({
          'code': 'custom_${json['id']}',
          'name': {'en': json['name_en'] ?? '', 'pl': json['name_pl'] ?? ''},
          'pattern': json['pattern'] ?? 'accessory',
          'mechanics': 'compound',
          'difficulty': 'beginner',
          'equipment': json['equipment'] ?? 'body weight',
          'primary_muscle': json['primary_muscle'] ?? 'other',
          'secondary_muscles': json['secondary_muscles'] ?? [],
          'description': json['notes'] ?? '',
          'instructions': {'en': <String>[], 'pl': <String>[]},
          'images': <String>[],
          'common_mistakes': {'en': <String>[], 'pl': <String>[]},
          'safety': <String, dynamic>{},
          'is_custom': true,
        });
      }).toList();
      
      // Połącz własne ćwiczenia na początku listy
      exercises = [...customExercises, ...standardExercises];
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania ćwiczeń: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
    
    if (!context.mounted) return null;
    Navigator.pop(context);
    
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak ćwiczeń w bazie'), backgroundColor: Colors.orange),
      );
      return null;
    }
    
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _ExerciseLibraryPicker(
          exercises: exercises,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// Widget do wyboru ćwiczenia z pełnej biblioteki
class _ExerciseLibraryPicker extends StatefulWidget {
  final List<Exercise> exercises;
  final ScrollController scrollController;
  
  const _ExerciseLibraryPicker({required this.exercises, required this.scrollController});
  
  @override
  State<_ExerciseLibraryPicker> createState() => _ExerciseLibraryPickerState();
}

class _ExerciseLibraryPickerState extends State<_ExerciseLibraryPicker> {
  String _search = '';
  String? _selectedMuscle;
  String? _selectedEquipment;
  
  static const _muscleGroups = [
    {'value': 'chest', 'label': 'Klatka'},
    {'value': 'back', 'label': 'Plecy'},
    {'value': 'shoulders', 'label': 'Barki'},
    {'value': 'biceps', 'label': 'Biceps'},
    {'value': 'triceps', 'label': 'Triceps'},
    {'value': 'quads', 'label': 'Nogi przód'},
    {'value': 'hamstrings', 'label': 'Nogi tył'},
    {'value': 'glutes', 'label': 'Pośladki'},
    {'value': 'abs', 'label': 'Brzuch'},
    {'value': 'calves', 'label': 'Łydki'},
  ];
  
  static const _equipmentOptions = [
    {'value': 'body weight', 'label': 'Ciało'},
    {'value': 'barbell', 'label': 'Sztanga'},
    {'value': 'dumbbell', 'label': 'Hantle'},
    {'value': 'cable', 'label': 'Wyciąg'},
    {'value': 'machine', 'label': 'Maszyna'},
  ];
  
  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises.where((ex) {
      if (_search.isNotEmpty) {
        final name = ex.getName('pl').toLowerCase();
        final code = ex.code.toLowerCase();
        if (!name.contains(_search.toLowerCase()) && !code.contains(_search.toLowerCase())) {
          return false;
        }
      }
      if (_selectedMuscle != null && ex.primaryMuscle.toLowerCase() != _selectedMuscle!.toLowerCase()) {
        return false;
      }
      if (_selectedEquipment != null && ex.equipment.toLowerCase() != _selectedEquipment!.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
    
    filtered.sort((a, b) => a.getName('pl').compareTo(b.getName('pl')));
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Szukaj ćwiczenia...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        
        // Filtry partii mięśniowych
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildFilterChip(
                label: 'Wszystkie',
                isSelected: _selectedMuscle == null,
                onTap: () => setState(() => _selectedMuscle = null),
              ),
              ..._muscleGroups.map((m) => _buildFilterChip(
                label: m['label']!,
                isSelected: _selectedMuscle == m['value'],
                onTap: () => setState(() => _selectedMuscle = _selectedMuscle == m['value'] ? null : m['value']),
              )),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Filtry sprzętu
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              ..._equipmentOptions.map((e) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(e['label']!, style: const TextStyle(fontSize: 11)),
                  selected: _selectedEquipment == e['value'],
                  onSelected: (selected) => setState(() => _selectedEquipment = selected ? e['value'] : null),
                  selectedColor: Colors.blue.withOpacity(0.3),
                  backgroundColor: const Color(0xFF1E1E1E),
                  labelStyle: TextStyle(
                    color: _selectedEquipment == e['value'] ? Colors.blue : Colors.white70,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              )),
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${filtered.length} ćwiczeń',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final ex = filtered[i];
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.black26,
                      child: ExerciseImage(
                        exerciseCode: ex.code,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text(
                    ex.getName('pl'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Row(
                    children: [
                      _buildMiniTag(ex.getPrimaryMuscleLabel('pl'), AppColors.accent),
                      const SizedBox(width: 6),
                      _buildMiniTag(ex.getEquipmentLabel('pl'), Colors.blue),
                    ],
                  ),
                  trailing: const Icon(Icons.check_circle_outline, color: AppColors.accent),
                  onTap: () => Navigator.pop(context, ex),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}