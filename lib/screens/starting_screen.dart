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
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/startingbackground.png',
              fit: BoxFit.cover,
            ),
          ),
          
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.15))),
          Column(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFD605B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 5,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: const Text(
                          "Get Started",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: const [
                        Expanded(child: Divider(color: Colors.orange, thickness: 1, endIndent: 8)),
                        Text("OR", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                        Expanded(child: Divider(color: Colors.orange, thickness: 1, indent: 8)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                        ),
                        onPressed: () {
                          
                        },
                        child: const Text(
                          "Sign Up with Google",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF31343D),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text.rich(
                        TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(color: Colors.white70),
                          children: [
                            TextSpan(
                              text: "Sign In",
                              style: TextStyle(
                                color: Color(0xFFFD605B),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
}
