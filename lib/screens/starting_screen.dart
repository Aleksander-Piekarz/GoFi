import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/providers.dart'; 
import 'home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class StartingScreen extends ConsumerStatefulWidget {
  const StartingScreen({super.key});
  @override
  ConsumerState<StartingScreen> createState() => _StartingScreenState();
}

class _StartingScreenState extends ConsumerState<StartingScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final storage = ref.read(secureStorageProvider);
    final tok = await storage.read(key: 'token');

    ref.read(authTokenProvider.notifier).state = tok;

    if (!mounted) return;

    if (tok != null && tok.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // 1. TŁO - Powrót do Alignment.center (domyślne)
          Positioned.fill(
            child: Image.asset(
              'assets/images/startingbackground2.png', 
              fit: BoxFit.cover,
              alignment: Alignment.center, // <-- Gwarantuje widoczność logo na środku
            ),
          ),
          
          // 2. CIEMNIEJSZY GRADIENT (Dla lepszej czytelności przycisków)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.8), // Mocniejsze przyciemnienie na dole
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // 3. PRZYCISKI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Przycisk "Rozpocznij Teraz"
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFD605B),
                        foregroundColor: Colors.white,
                        elevation: 4, // Lekki cień dla lepszego wyróżnienia
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        "Rozpocznij Teraz",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700, // Pogrubienie
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Link "Zaloguj się"
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: Container(
                        // Dodatkowy kontener zwiększający obszar kliknięcia
                        padding: const EdgeInsets.all(8.0),
                        child: RichText(
                          text: TextSpan(
                            text: "Masz już konto? ",
                            style: const TextStyle(
                              color: Colors.white70, 
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: "Zaloguj się",
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}