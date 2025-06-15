import 'package:flutter/material.dart';
import './screens/starting_screen.dart'; // Upewnij się, że ścieżka jest poprawna

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoFi',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StartingScreen(), // Ustawienie ekranu startowego
    );
  }
}
