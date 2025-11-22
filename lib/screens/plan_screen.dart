import 'package:flutter/material.dart';
import 'plan_view.dart'; 

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key, required this.plan});
  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Twój Plan')),
      body: PlanView(plan: plan), 
    );
  }
}