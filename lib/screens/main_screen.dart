import 'package:flutter/material.dart';

import 'package:gofi/screens/login_screen.dart';
import 'package:gofi/screens/register_screen.dart';
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoFi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),

        '/login': (context) => const LoginScreen(), // jeśli masz
        '/register': (context) => const RegisterScreen(), // jeśli masz
      },
    );
  }
}