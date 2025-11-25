import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gofi/screens/profile_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/theme.dart';
import 'screens/starting_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl_PL', null);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme, 
        routes: {
        '/': (context) => const StartingScreen(),
        '/profile': (context) => const ProfileScreen(),
      },

    );
    
  }
}
