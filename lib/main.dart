import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_providers.dart';
import 'users/login_page.dart';
import 'users/force_change_password_page.dart';
import 'screentabs/homepage.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LeaveSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthWrapper(),
      routes: {'/home': (context) => const AuthWrapper()},
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isLoggedIn) {
      return const LoginPage();
    }

    if (authProvider.mustChangePassword) {
      return const ForceChangePasswordPage();
    }

    return const HomePage();
  }
}
