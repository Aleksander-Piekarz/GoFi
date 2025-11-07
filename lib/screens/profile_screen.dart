import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/providers.dart';
import '../services/api/user_service.dart';
import 'questionnaire_screen.dart';
import 'starting_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifEnabled = true;
  String _unitSystem = "metric"; // "metric" | "imperial"

  String? _userName;
  String? _email;
  bool _loadingMe = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final auth = ref.read(authServiceProvider);
      final me = await auth.me(); // { id, email, username, unitSystem, notifEnabled, ... }
      if (!mounted) return;
      final rawNotif = me['notifEnabled'];

      setState(() {
        _userName = (me['username'] as String?)?.trim();
        _email = (me['email'] as String?)?.trim();
        _unitSystem = (me['unitSystem'] as String?) ?? 'metric';
        _notifEnabled = rawNotif is bool ? rawNotif : rawNotif == 1;
        _loadingMe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMe = false);
      _showSnack('Nie udało się pobrać profilu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nameToShow =
        _userName?.isNotEmpty == true ? _userName! : 'Użytkownik';
    final emailToShow = _email ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: Text('Profil', style: textTheme.titleLarge),
        centerTitle: true,
      ),
      body: _loadingMe
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Nagłówek profilu
                Row(
                  children: [
                    GestureDetector(
                      onTap: _changeAvatar,
                      child: const CircleAvatar(
                        radius: 36,
                        child: Icon(Icons.person, size: 36),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nameToShow,
                            style: textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emailToShow,
                            style: textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edytuj'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sekcja konta
                Text('Konto', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.alternate_email),
                        title: const Text('Email'),
                        subtitle: Text(emailToShow),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _changeEmail,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.edit_note_outlined),
                        title: const Text('Kwestionariusz'),
                        subtitle:
                            const Text('Uzupełnij lub edytuj odpowiedzi'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QuestionnaireScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Preferencje
                Text('Preferencje', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.straighten),
                        title: const Text('Jednostki'),
                        subtitle: Text(
                          _unitSystem == 'metric'
                              ? 'Metryczne (kg, cm)'
                              : 'Imperialne (lb, ft)',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickUnits,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active),
                        title: const Text('Powiadomienia'),
                        value: _notifEnabled,
                        onChanged: (v) => _toggleNotifications(v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Bezpieczeństwo
                Text('Bezpieczeństwo', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.key),
                        title: const Text('Zmień hasło'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _changePassword,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Wyloguj'),
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'GoFi • v0.1.0 (demo)',
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- Akcje --- //

  void _editProfile() {
    _showSnack('Edytuj profil (placeholder)');
  }

  void _changeEmail() {
    _showSnack('Zmiana emaila (placeholder)');
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _notifEnabled = enabled);
    try {
      final userService = ref.read(userServiceProvider);
      await userService.updateSettings(notifEnabled: enabled);
    } catch (e) {
      _showSnack('Nie udało się zapisać ustawienia: $e');
    }
  }

  void _pickUnits() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Metryczne (kg, cm)'),
              value: 'metric',
              groupValue: _unitSystem,
              onChanged: (v) => Navigator.pop(context, v),
            ),
            RadioListTile<String>(
              title: const Text('Imperialne (lb, ft)'),
              value: 'imperial',
              groupValue: _unitSystem,
              onChanged: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null && choice != _unitSystem) {
      setState(() => _unitSystem = choice);
      try {
        final userService = ref.read(userServiceProvider);
        await userService.updateSettings(unitSystem: choice);
      } catch (e) {
        _showSnack('Nie udało się zapisać jednostek: $e');
      }
    }
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Zmień hasło'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                decoration: const InputDecoration(labelText: 'Aktualne hasło'),
                obscureText: true,
              ),
              TextField(
                controller: newCtrl,
                decoration: const InputDecoration(labelText: 'Nowe hasło'),
                obscureText: true,
              ),
              TextField(
                controller: confirmCtrl,
                decoration:
                    const InputDecoration(labelText: 'Powtórz nowe hasło'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    if (newCtrl.text != confirmCtrl.text) {
      _showSnack('Nowe hasła nie są takie same');
      return;
    }
    if (newCtrl.text.length < 6) {
      _showSnack('Nowe hasło powinno mieć min. 6 znaków');
      return;
    }

    try {
      final userService = ref.read(userServiceProvider);
      await userService.changePassword(
        currentPassword: currentCtrl.text,
        newPassword: newCtrl.text,
      );
      _showSnack('Hasło zostało zmienione');
    } catch (e) {
      _showSnack('Błąd zmiany hasła: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final auth = ref.read(authServiceProvider);
      await auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const StartingScreen()),
        (_) => false,
      );
    } catch (e) {
      _showSnack('Błąd wylogowania: $e');
    }
  }

  void _changeAvatar() {
    _showSnack('Zmiana avatara (placeholder)');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
