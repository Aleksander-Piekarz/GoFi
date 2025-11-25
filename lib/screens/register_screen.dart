import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Klucz formularza niezbędny do walidacji
  final _formKey = GlobalKey<FormState>();
  
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool _loading = false;

  Future<void> _doRegister() async {
    // 1. Sprawdź czy formularz jest poprawny (uruchamia walidatory pól)
    if (!_formKey.currentState!.validate()) {
      return; // Jeśli są błędy, przerywamy
    }

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

  // --- Walidatory ---
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Adres email jest wymagany';
    }
    // Prosty Regex do emaila
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Podaj poprawny adres email';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nazwa użytkownika jest wymagana';
    }
    if (value.length < 3) {
      return 'Minimum 3 znaki';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Hasło jest wymagane';
    }
    if (value.length < 6) {
      return 'Hasło musi mieć min. 6 znaków';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejestracja')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        // Opakowujemy pola w Form
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Używamy TextFormField zamiast TextField
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Nazwa użytkownika'),
                validator: _validateUsername,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Hasło'),
                obscureText: true,
                validator: _validatePassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _doRegister,
                  child: Text(_loading ? 'Rejestrowanie…' : 'Zarejestruj'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}