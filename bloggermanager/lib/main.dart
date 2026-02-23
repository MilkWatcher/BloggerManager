import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _screen = 0; // 0: login, 1: signup, 2: dashboard

  void _onLoginSuccess() => setState(() => _screen = 2);
  void _onSignupSuccess() => setState(() => _screen = 2);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _screen == 0
        ? LoginScreen(onLoginSuccess: _onLoginSuccess)
        : _screen == 1
          ? SignupScreen(onSignupSuccess: _onSignupSuccess)
          : const DashboardScreen(),
      routes: {
        '/signup': (context) => SignupScreen(onSignupSuccess: _onSignupSuccess),
      },
    );
  }
}
