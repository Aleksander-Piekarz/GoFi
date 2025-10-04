import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gofi/screens/login_screen.dart';
import '../providers/user_provider.dart';
import '../repositories/auth_repository.dart';
import '../services/api/api_client.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(title: Text(user != null ? 'Welcome, ${user.username} 👋' : 'Welcome 👋')),
      body: Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(user != null ? "UserID: ${user.id}" : "Brak usera"),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: () async {
          final repo = AuthRepository(ApiClient(baseUrl: 'https://helloichangeitlater.com'));
          await repo.logout();
          ref.read(userProvider.notifier).state = null;
          ref.read(authTokenProvider.notifier).state = null;

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        },
        child: const Text("Logout"),
      ),
    ],
  ),
),

    );
  }
}
