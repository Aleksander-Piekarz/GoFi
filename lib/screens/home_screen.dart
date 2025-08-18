import 'package:flutter/material.dart';
import 'package:gofi/screens/questionnaire_screen.dart';

class HomeScreen extends StatelessWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ekran główny")),
      
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              "Witaj! Twoje ID to: $userId",
              style: const TextStyle(fontSize: 18),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => QuestionnaireScreen(userId: userId),
  ),
);
              },
              child: const Text("Wypełnij ankietę"),
            ),
          ],
        ),
      ),
    );
  }
}
