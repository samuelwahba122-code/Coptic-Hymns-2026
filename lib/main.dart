import 'package:flutter/material.dart';

import 'screens/auth_home_screen.dart';
import 'screens/groups_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ===== Global Coptic-inspired theme =====
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC9A24A), // gold
          brightness: Brightness.dark,
          surface: const Color(0xFF0F1633),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1026),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1026),
          foregroundColor: Colors.white,
        ),
      ),

      // ===== App entry =====
      home: Builder(
        builder: (context) {
          return AuthHomeScreen(
            onContinue: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const GroupsScreen()),
              );
            },
          );
        },
      ),
    );
  }
}
