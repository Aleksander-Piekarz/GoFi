import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;


class QuestionnaireService {
  static const String _baseUrl = 'http://10.0.2.2:3000'; // iOS: 127.0.0.1

  static Future<Map<String, dynamic>?> getStatus(String userId) async {
    final uri = Uri.parse('$_baseUrl/users/$userId/questionnaire');
    final r = await http.get(uri).timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(r.body));
    if (r.statusCode == 404) return null;
    throw Exception('Server error ${r.statusCode}: ${r.body}');
  }

  static Future<Map<String, dynamic>> upsert(String userId, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/users/$userId/questionnaire');
    final payload = Map<String, dynamic>.from(data)..remove('id');
    final r = await http
        .put(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(r.body));
    throw Exception('Server error ${r.statusCode}: ${r.body}');
  }

  static Future<Map<String, dynamic>> submit(String userId) async {
    final uri = Uri.parse('$_baseUrl/users/$userId/questionnaire/submit');
    final r = await http
        .post(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));
    final Map<String, dynamic> body =
        r.body.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(r.body)) : <String, dynamic>{};
    if (r.statusCode == 200 || r.statusCode == 400 || r.statusCode == 404) return body;
    throw Exception('Server error ${r.statusCode}: ${r.body}');
  }
}

class QuestionnaireScreen extends StatefulWidget {
  final String userId;
  const QuestionnaireScreen({super.key, required this.userId});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  double _progress = 0.0; // 0..1 z API
  String _status = 'DRAFT';
  List<String> _missing = const [];

  // Kontrolery
  final ageCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  String? gender; // Dropdown

  final goalCtrl = TextEditingController();
  final motivationCtrl = TextEditingController();
  final experienceCtrl = TextEditingController();
  String? activityLevel; // Dropdown

  final sleepHoursCtrl = TextEditingController();
  final workTypeCtrl = TextEditingController();
  final availableDaysCtrl = TextEditingController();
  final sessionLengthCtrl = TextEditingController();

  final equipmentCtrl = TextEditingController();
  final preferredExercisesCtrl = TextEditingController();
  final injuriesCtrl = TextEditingController();
  final illnessesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      ageCtrl,
      weightCtrl,
      heightCtrl,
      goalCtrl,
      motivationCtrl,
      experienceCtrl,
      sleepHoursCtrl,
      workTypeCtrl,
      availableDaysCtrl,
      sessionLengthCtrl,
      equipmentCtrl,
      preferredExercisesCtrl,
      injuriesCtrl,
      illnessesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await QuestionnaireService.getStatus(widget.userId);
      if (status != null) {
        _status = (status['status'] as String?) ?? 'DRAFT';
        _progress = (status['progress'] as num?)?.toDouble() ?? 0.0;
        _missing = (status['missing'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final q = status['questionnaire'] as Map<String, dynamic>?;
        if (q != null) _fillFrom(q);
      }
    } catch (e) {
      if (mounted) _showSnack('Błąd pobierania: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillFrom(Map<String, dynamic> q) {
    String? s(dynamic v) => v == null ? null : v.toString();
    ageCtrl.text = s(q['age']) ?? '';
    weightCtrl.text = s(q['weight']) ?? '';
    heightCtrl.text = s(q['height']) ?? '';
    gender = s(q['gender']);
    goalCtrl.text = s(q['goal']) ?? '';
    motivationCtrl.text = s(q['motivation']) ?? '';
    experienceCtrl.text = s(q['experience']) ?? '';
    activityLevel = s(q['activityLevel']);
    sleepHoursCtrl.text = s(q['sleepHours']) ?? '';
    workTypeCtrl.text = s(q['workType']) ?? '';
    availableDaysCtrl.text = s(q['availableDays']) ?? '';
    sessionLengthCtrl.text = s(q['sessionLength']) ?? '';
    equipmentCtrl.text = s(q['equipment']) ?? '';
    preferredExercisesCtrl.text = s(q['preferredExercises']) ?? '';
    injuriesCtrl.text = s(q['injuries']) ?? '';
    illnessesCtrl.text = s(q['illnesses']) ?? '';
  }

  Map<String, dynamic> _collectPayload() {
    num? n(String s) => s.trim().isEmpty ? null : num.tryParse(s.trim());
    String? t(String s) => s.trim().isEmpty ? null : s.trim();

    return {
      'age': n(ageCtrl.text)?.toInt(),
      'weight': n(weightCtrl.text)?.toDouble(),
      'height': n(heightCtrl.text)?.toDouble(),
      'gender': gender,
      'goal': t(goalCtrl.text),
      'motivation': t(motivationCtrl.text),
      'experience': t(experienceCtrl.text),
      'activityLevel': activityLevel,
      'sleepHours': n(sleepHoursCtrl.text)?.toDouble(),
      'workType': t(workTypeCtrl.text),
      'availableDays': t(availableDaysCtrl.text),
      'sessionLength': n(sessionLengthCtrl.text)?.toInt(),
      'equipment': t(equipmentCtrl.text),
      'preferredExercises': t(preferredExercisesCtrl.text),
      'injuries': t(injuriesCtrl.text),
      'illnesses': t(illnessesCtrl.text),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await QuestionnaireService.upsert(widget.userId, _collectPayload());
      setState(() {
        _status = (res['status'] as String?) ?? 'DRAFT';
        _progress = (res['progress'] as num?)?.toDouble() ?? _progress;
        _missing = (res['missing'] as List?)?.map((e) => e.toString()).toList() ?? _missing;
      });
      _showSnack('Zapisano');
    } catch (e) {
      _showSnack('Błąd zapisu: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final res = await QuestionnaireService.submit(widget.userId);
      if (res['error'] != null) {
        final missing = (res['missing'] as List?)?.map((e) => e.toString()).join(', ') ?? '';
        _showSnack('Niekompletna: $missing');
      } else {
        _showSnack('Wysłano ankietę');
        setState(() => _status = 'SUBMITTED');
      }
    } catch (e) {
      _showSnack('Błąd wysyłki: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kwestionariusz'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  LinearProgressIndicator(value: _progress, minHeight: 8),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: _numField('Wiek', ageCtrl, min: 10, max: 120)),
                      const SizedBox(width: 12),
                      Expanded(child: _numField('Waga (kg)', weightCtrl, min: 20, max: 400, allowDecimal: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _numField('Wzrost (cm)', heightCtrl, min: 100, max: 250, allowDecimal: true)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: gender,
                          decoration: const InputDecoration(labelText: 'Płeć'),
                          items: const [
                            DropdownMenuItem(value: 'Mężczyzna', child: Text('Mężczyzna')),
                            DropdownMenuItem(value: 'Kobieta', child: Text('Kobieta')),
                            DropdownMenuItem(value: 'Inna', child: Text('Inna')),
                          ],
                          onChanged: (v) => setState(() => gender = v),
                          validator: (v) => v == null || v.isEmpty ? 'Wybierz płeć' : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  _textField('Cel (goal)', goalCtrl, maxLines: 2),
                  _textField('Motywacja', motivationCtrl, maxLines: 2),
                  _textField('Doświadczenie', experienceCtrl, maxLines: 2),

                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: activityLevel,
                    decoration: const InputDecoration(labelText: 'Poziom aktywności'),
                    items: const [
                      DropdownMenuItem(value: 'niski', child: Text('Niski')),
                      DropdownMenuItem(value: 'umiarkowany', child: Text('Umiarkowany')),
                      DropdownMenuItem(value: 'wysoki', child: Text('Wysoki')),
                    ],
                    onChanged: (v) => setState(() => activityLevel = v),
                    validator: (v) => v == null || v.isEmpty ? 'Wybierz poziom aktywności' : null,
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _numField('Sen (h)', sleepHoursCtrl, min: 0, max: 24, allowDecimal: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _numField('Sesja (min)', sessionLengthCtrl, min: 10, max: 240)),
                    ],
                  ),

                  const SizedBox(height: 12),
                  _textField('Rodzaj pracy', workTypeCtrl),
                  _textField('Dostępne dni', availableDaysCtrl, hint: 'np. Pon, Śr, Pt'),
                  _textField('Sprzęt', equipmentCtrl),
                  _textField('Preferowane ćwiczenia', preferredExercisesCtrl),
                  _textField('Kontuzje', injuriesCtrl),
                  _textField('Choroby', illnessesCtrl),

                  const SizedBox(height: 16),
                  if (_missing.isNotEmpty)
                    Text('Brakuje: ${_missing.join(', ')}', style: const TextStyle(color: Colors.red)),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Zapisz'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.send),
                          label: const Text('Wyślij'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }


  Widget _textField(String label, TextEditingController c, {int maxLines = 1, String? hint}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Wymagane pole' : null,
    );
  }

  Widget _numField(String label, TextEditingController c, {double? min, double? max, bool allowDecimal = false}) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(allowDecimal ? r'[0-9\.]' : r'[0-9]')),
      ],
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Wymagane pole';
        final val = double.tryParse(v.trim());
        if (val == null) return 'Nieprawidłowa liczba';
        if (min != null && val < min) return 'Min $min';
        if (max != null && val > max) return 'Max $max';
        return null;
      },
    );
  }
}
