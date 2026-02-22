import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/profile_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Make sure to update firebase_options.dart with your credentials!');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'Blogger Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  int _screenIndex = 0; // 0: Login, 1: Signup, 2: Dashboard

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    if (_authService.isLoggedIn) {
      setState(() => _screenIndex = 2);
      // Load profile in provider
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AppProvider>().loadProfile();
        }
      });
    }
  }

  void _handleLoginSuccess() {
    setState(() => _screenIndex = 2);
    context.read<AppProvider>().loadProfile();
  }

  void _handleLogout() async {
    await _authService.logout();
    setState(() => _screenIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_screenIndex == 0) {
      return LoginScreen(
        onLoginSuccess: _handleLoginSuccess,
        onGoToSignup: () => setState(() => _screenIndex = 1),
      );
    } else if (_screenIndex == 1) {
      return SignupScreen(
        onSignupSuccess: _handleLoginSuccess,
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Blogger Manager'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
            ),
          ],
        ),
        body: const ProfileDashboardScreen(),
      );
    }
  }
}
