import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool _loading = false;

  Future<void> _doRegister() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);

      
      final user = await auth.register(
        email: emailController.text.trim(),
        password: passwordController.text,
        username: usernameController.text.trim(),
      );

      if (user != null) {
        debugPrint('Zarejestrowano użytkownika: $user');
      }

      if (!mounted) return;
      
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd rejestracji: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejestracja')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: usernameController,
              decoration:
                  const InputDecoration(labelText: 'Nazwa użytkownika'),
            ),
            TextField(
              controller: passwordController,
              decoration:
                  const InputDecoration(labelText: 'Hasło'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _doRegister,
              child: Text(_loading ? 'Rejestrowanie…' : 'Zarejestruj'),
            ),
          ],
        ),
      ),
    );
  }
}
