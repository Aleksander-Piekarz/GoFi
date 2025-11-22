import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  


  Future<void> _editStepGoal(int currentGoal) async {
    final newGoalCtrl = TextEditingController(text: currentGoal.toString());

    final newGoal = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zmień dzienny cel kroków'),
        content: TextField(
          controller: newGoalCtrl,
          decoration: const InputDecoration(labelText: 'Liczba kroków'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, newGoalCtrl.text),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );

    if (newGoal != null && newGoal.isNotEmpty) {
      final newStepCount = int.tryParse(newGoal);
      
      if (newStepCount != null && newStepCount > 0 && newStepCount != currentGoal) {
        try {
          final userService = ref.read(userServiceProvider);
          
          await userService.updateSettings(dailySteps: newStepCount);
          
          ref.invalidate(userProfileProvider);
        } catch (e) {
          _showSnack('Nie udało się zapisać celu: $e');
        }
      }
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    try {
      final userService = ref.read(userServiceProvider);
      await userService.updateSettings(notifEnabled: enabled);
      ref.invalidate(userProfileProvider); 
    } catch (e) {
      
      
      _showSnack('Nie udało się zapisać ustawienia: $e');
      ref.invalidate(userProfileProvider);
    }
  }

  void _pickUnits(String currentUnit) async {
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
              groupValue: currentUnit,
              onChanged: (v) => Navigator.pop(context, v),
            ),
            RadioListTile<String>(
              title: const Text('Imperialne (lb, ft)'),
              value: 'imperial',
              groupValue: currentUnit,
              onChanged: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    
    if (choice != null && choice != currentUnit) {
      try {
        final userService = ref.read(userServiceProvider);
        await userService.updateSettings(unitSystem: choice);
        ref.invalidate(userProfileProvider); 
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
      
      ref.invalidate(userProfileProvider); 
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const StartingScreen()),
        (_) => false,
      );
    } catch (e) {
      _showSnack('Błąd wylogowania: $e');
    }
  }
  
  
  
  void _editProfile() { _showSnack('Edytuj profil (placeholder)'); }
  void _changeEmail() { _showSnack('Zmiana emaila (placeholder)'); }
  void _changeAvatar() { _showSnack('Zmiana avatara (placeholder)'); }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    
    final asyncProfile = ref.watch(userProfileProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profil', style: textTheme.titleLarge),
        centerTitle: true,
      ),
      
      body: asyncProfile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
            child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Błąd ładowania profilu: $err'),
        )),
        data: (profile) {
          
          final nameToShow = (profile['username'] as String?)?.trim() ?? 'Użytkownik';
          final emailToShow = (profile['email'] as String?)?.trim() ?? '—';
          final unitSystem = (profile['unitSystem'] as String?) ?? 'metric';
          final notifEnabled = (profile['notifEnabled'] as bool?) ?? true;
          final dailySteps = (profile['dailySteps'] as int?) ?? 10000;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              
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

              
              Text('Preferencje', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    
                    ListTile(
                      leading: const Icon(Icons.directions_walk),
                      title: const Text('Dzienny cel kroków'),
                      subtitle: Text('$dailySteps kroków'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editStepGoal(dailySteps),
                    ),
                    const Divider(height: 1),
                    
                    ListTile(
                      leading: const Icon(Icons.straighten),
                      title: const Text('Jednostki'),
                      subtitle: Text(
                        unitSystem == 'metric'
                            ? 'Metryczne (kg, cm)'
                            : 'Imperialne (lb, ft)',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickUnits(unitSystem),
                    ),
                    const Divider(height: 1),
                    
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active),
                      title: const Text('Powiadomienia'),
                      value: notifEnabled,
                      onChanged: (v) => _toggleNotifications(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              
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
          );
        },
      ),
    );
  }
}