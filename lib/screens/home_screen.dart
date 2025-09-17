import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../widgets/buttons.dart';

class HomeScreen extends StatelessWidget {
    final String userId;
  const HomeScreen({super.key, required this.userId});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title:  Text(
          "Welcome back $userId",
          style: TextStyle(color: AppColors.text),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings, color: AppColors.textDim),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your stats",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),

            // 🔹 Kafle statystyk
            Row(
              children: [
                Expanded(child: _StatCard(title: "Steps", value: "5,421")),
                const SizedBox(width: 16),
                Expanded(child: _StatCard(title: "Calories", value: "324")),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _StatCard(title: "Workout", value: "Today")),
                const SizedBox(width: 16),
                Expanded(child: _StatCard(title: "Sleep", value: "7h 45m")),
              ],
            ),

            const SizedBox(height: 24),

            // 🔹 CTA
            PrimaryButton(
              label: "Start Workout",
              onPressed: () {},
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.bgAlt,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textDim,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: "Plans"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Progress"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.stroke, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textDim)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
