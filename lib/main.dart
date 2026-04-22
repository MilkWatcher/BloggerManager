import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;

import 'firebase_options.dart';
import 'models/blogger_user.dart';
import 'services/google_geocoding_service.dart';
import 'services/auth_service.dart';
import 'screens/browsable_bloggers_screen.dart';
import 'screens/edit_blogger_profile_screen.dart';
import 'screens/home_blog_search_screen.dart';
import 'screens/upload_blog_screen.dart';
import 'screens/moderation_dashboard_screen.dart';
import 'widgets/tag_chip.dart';
import 'screens/force_password_change_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/tos_acceptance_screen.dart';
import 'screens/email_action_handler_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/recaptcha_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Widget _buildLogoTitle(String text) {
  return Row(
    children: [
      Image.asset(
        'lib/images/blogDB.png',
        height: 26,
      ),
      const SizedBox(width: 8),
      Text(text),
    ],
  );
}

Widget _buildLogoOnlyTitle() {
  return Image.asset(
    'lib/images/blogDB.png',
    height: 30,
  );
}

// Parsed from URL query parameters for Firebase email action handling
String? _actionMode;
String? _actionOobCode;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FirebaseApp app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  developer.log('Firebase projectId: ${app.options.projectId}', name: 'app.startup');

  // Parse email action URL parameters (e.g. ?mode=verifyEmail&oobCode=...)
  if (kIsWeb) {
    final uri = Uri.base;
    _actionMode = uri.queryParameters['mode'];
    _actionOobCode = uri.queryParameters['oobCode'];
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _handlingAction = false;

  @override
  void initState() {
    super.initState();
    if (_actionMode != null && _actionOobCode != null) {
      _handlingAction = true;
    }
  }

  void _clearActionAndContinue() {
    setState(() {
      _actionMode = null;
      _actionOobCode = null;
      _handlingAction = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blogger Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B68C8)),
        scaffoldBackgroundColor: const Color(0xFFD5D0EF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFDAD7FD),
          surfaceTintColor: Color(0xFFDAD7FD),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF3D2E8A)),
          actionsIconTheme: IconThemeData(color: Color(0xFF3D2E8A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1E1A3C),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFDAD7FD),
          selectedItemColor: Color(0xFF3D2E8A),
          unselectedItemColor: Color(0xFF8A80C4),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.22),
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: _handlingAction
          ? EmailActionHandlerScreen(
              mode: _actionMode!,
              oobCode: _actionOobCode!,
              onContinue: _clearActionAndContinue,
            )
          : const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  bool _isProfileComplete(Map<String, dynamic>? userData) {
    if (userData == null) {
      return false;
    }

    final bool explicitComplete =
        userData['profileSetupCompleted'] as bool? ?? false;
    if (explicitComplete) {
      return true;
    }

    final String displayName = (userData['displayName'] as String? ?? '').trim();
    final GeoPoint? location = userData['location'] as GeoPoint?;
    final List<String> tags =
        List<String>.from(userData['tags'] as List<dynamic>? ?? <dynamic>[])
            .where((String tag) => tag.trim().isNotEmpty)
            .toList();

    return displayName.isNotEmpty && location != null && tags.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    );

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final User? user = snapshot.data;
        if (snapshot.hasData && user != null) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: firestore.collection('users').doc(user.uid).snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> userSnapshot,
            ) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const _SplashScreen(message: 'Loading your profile…');
              }

              final Map<String, dynamic>? userData = userSnapshot.data?.data();

              // Check ban status
              final String userStatus = userData?['status'] as String? ?? 'active';
              if (userStatus == 'banned') {
                final DateTime? banExpiry = (userData?['banExpiry'] as Timestamp?)?.toDate();
                if (banExpiry != null && banExpiry.isAfter(DateTime.now())) {
                  return _BannedScreen(banExpiry: banExpiry, reason: null);
                }
                // Auto-unban if expired
                if (banExpiry != null && banExpiry.isBefore(DateTime.now())) {
                  firestore.collection('users').doc(user.uid).set({
                    'status': 'active',
                    'banExpiry': null,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
              }

              // Check if password change is required
              final bool mustChangePassword = userData?['mustChangePassword'] as bool? ?? false;
              if (mustChangePassword) {
                return const ForcePasswordChangeScreen();
              }

              // Check email verification (skip for admin/moderator)
              final String userRole = userData?['role'] as String? ?? 'blogger';
              if (userRole == 'blogger' && !user.emailVerified) {
                return EmailVerificationScreen(user: user);
              }

              // Check profile completion (skip for admin/moderator)
              final bool profileSetupCompleted = _isProfileComplete(userData);

              // New users (profile not yet completed) must accept ToS then set up profile
              if (userRole == 'blogger' && !profileSetupCompleted) {
                final String? tosVersion = userData?['tosVersion'] as String?;
                if (tosVersion != currentTosVersion) {
                  return TosAcceptanceScreen(user: user);
                }
                return CompleteProfileScreen(user: user);
              }

              return _PostLoginGate(user: user);
            },
          );
        }

        return const _UnauthenticatedFlow();
      },
    );
  }
}

/// Branded splash / loading screen shown during auth and profile loading.
class _SplashScreen extends StatelessWidget {
  final String? message;
  const _SplashScreen({this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('lib/images/blogDB.png', height: 72),
            const SizedBox(height: 20),
            Text(
              'Blogger Manager',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colorScheme.primary,
              ),
            ),
            if (message != null) ...[  
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Manages Welcome → AuthScreen transition when no user is signed in.
class _UnauthenticatedFlow extends StatefulWidget {
  const _UnauthenticatedFlow();

  @override
  State<_UnauthenticatedFlow> createState() => _UnauthenticatedFlowState();
}

class _UnauthenticatedFlowState extends State<_UnauthenticatedFlow> {
  bool _showWelcome = true;
  bool _signUpMode = false;

  void _goToAuth({required bool signUp}) {
    setState(() {
      _signUpMode = signUp;
      _showWelcome = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) {
      return WelcomeScreen(
        onGetStarted: () => _goToAuth(signUp: true),
        onLogin: () => _goToAuth(signUp: false),
      );
    }
    return AuthScreen(
      initialSignUp: _signUpMode,
      onBack: () => setState(() => _showWelcome = true),
    );
  }
}

/// Shows notification popups after login, then goes to dashboard.
class _PostLoginGate extends StatefulWidget {
  final User user;
  const _PostLoginGate({required this.user});

  @override
  State<_PostLoginGate> createState() => _PostLoginGateState();
}

class _PostLoginGateState extends State<_PostLoginGate> {
  final AuthService _authService = AuthService();
  bool _notificationsChecked = false;

  @override
  void initState() {
    super.initState();
    _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    try {
      final notifications = await _authService.getUnacknowledgedNotifications();
      if (!mounted) return;

      for (final notification in notifications) {
        if (notification.type == 'warn') {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Warning'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.message ?? 'You have received a warning.'),
                  if (notification.reason != null &&
                      notification.reason!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Reason: ${notification.reason}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Acknowledge'),
                ),
              ],
            ),
          );
          await _authService.acknowledgeNotification(notification.id);
        }
      }
    } catch (e) {
      developer.log('Error checking notifications: $e', error: e, name: 'PostLoginGate');
    }

    if (mounted) {
      setState(() {
        _notificationsChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_notificationsChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ProfileDashboardScreen(user: widget.user);
  }
}

/// Blocking screen shown to banned users
class _BannedScreen extends StatelessWidget {
  final DateTime banExpiry;
  final String? reason;
  const _BannedScreen({required this.banExpiry, this.reason});

  @override
  Widget build(BuildContext context) {
    final remaining = banExpiry.difference(DateTime.now());
    String remainingText;
    if (remaining.inDays > 0) {
      remainingText = '${remaining.inDays} day(s)';
    } else if (remaining.inHours > 0) {
      remainingText = '${remaining.inHours} hour(s)';
    } else {
      remainingText = '${remaining.inMinutes} minute(s)';
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.block, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Account Suspended',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your account has been temporarily banned.',
                      textAlign: TextAlign.center,
                    ),
                    if (reason != null && reason!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Reason: $reason',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 12),
                    Text('Remaining: $remainingText'),
                    const SizedBox(height: 8),
                    Text(
                      'Ban expires: ${banExpiry.toLocal().toString().split('.').first}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool initialSignUp;
  final VoidCallback? onBack;
  const AuthScreen({this.initialSignUp = false, this.onBack, super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
  late bool _isLoginMode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _isLoginMode = !widget.initialSignUp;
  }
  bool _captchaVerified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final GlobalKey<RecaptchaWidgetState> _recaptchaKey = GlobalKey<RecaptchaWidgetState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in email and password.')),
      );
      return;
    }

    if (kIsWeb && !_captchaVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the CAPTCHA verification.')),
      );
      return;
    }

    if (!_isLoginMode && confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm your password.')),
      );
      return;
    }

    if (!_isLoginMode && confirmPassword != password) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      late final UserCredential credential;
      if (_isLoginMode) {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      final User? user = credential.user;
      if (user == null) {
        throw Exception('Authentication returned no user.');
      }

      // Send verification email on signup
      if (!_isLoginMode && !user.emailVerified) {
        await user.sendEmailVerification(
          ActionCodeSettings(
            url: Uri.base.origin,
            handleCodeInApp: true,
          ),
        );
      }

      // If the Firestore doc was deleted (e.g. admin deletion) but the Auth
      // account still exists, treat the next sign-in as a fresh registration
      // so the user gets a valid verificationStatus and is visible again.
      final existingDoc = await _firestore.collection('users').doc(user.uid).get();
      final bool isNewDoc = !existingDoc.exists;

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'displayName': user.displayName ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!_isLoginMode || isNewDoc) 'createdAt': FieldValue.serverTimestamp(),
        if (!_isLoginMode || isNewDoc) 'verificationStatus': 'Approved',
        if (!_isLoginMode || isNewDoc) 'profileSetupCompleted': false,
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isLoginMode
                ? 'Logged in and synced to Firestore.'
                : 'Account created and saved to Firestore.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      // Reset CAPTCHA on failed auth attempt
      _recaptchaKey.currentState?.reset();
      setState(() => _captchaVerified = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.onBack != null
          ? AppBar(
              leading: BackButton(onPressed: widget.onBack),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo + App name
                        Image.asset(
                          'lib/images/blogDB.png',
                          height: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Blogger Manager',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Main card
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  _isLoginMode ? 'Welcome back!' : 'Create your account',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isLoginMode
                                      ? 'Sign in to continue to your dashboard.'
                                      : 'Sign up to get started with Blogger Manager.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Email field
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Password field
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                // Confirm password (sign-up only)
                                if (!_isLoginMode) ...<Widget>[
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                                // reCAPTCHA (web only)
                                if (kIsWeb) ...<Widget>[
                                  const SizedBox(height: 18),
                                  Center(
                                    child: RecaptchaWidget(
                                      key: _recaptchaKey,
                                      onVerified: (token) {
                                        setState(() => _captchaVerified = true);
                                      },
                                      onExpired: () {
                                        setState(() => _captchaVerified = false);
                                      },
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                // Submit button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: (_isSubmitting || (kIsWeb && !_captchaVerified)) ? null : _submitAuth,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_isLoginMode ? Icons.login : Icons.person_add, size: 20),
                                              const SizedBox(width: 8),
                                              Text(_isLoginMode ? 'Login' : 'Sign Up'),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Toggle login/signup
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isLoginMode ? "Don't have an account?" : 'Already have an account?',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    TextButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () {
                                              _recaptchaKey.currentState?.reset();
                                              setState(() {
                                                _isLoginMode = !_isLoginMode;
                                                _captchaVerified = false;
                                                _obscurePassword = true;
                                                _obscureConfirmPassword = true;
                                              });
                                            },
                                      child: Text(
                                        _isLoginMode ? 'Sign Up' : 'Login',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({required this.user, super.key});

  final User user;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
  final GoogleGeocodingService _googleGeocodingService =
      GoogleGeocodingService();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _xUrlController = TextEditingController();
  final TextEditingController _instagramUrlController = TextEditingController();
  final TextEditingController _facebookUrlController = TextEditingController();
  final List<String> _availableTags = [
    'Politics',
    'Food',
    'Cats',
    'Travel',
    'Technology',
    'Business',
    'Lifestyle',
    'Sports',
    'Health',
    'Entertainment',
    'Education',
    'DIY',
    'Fashion',
    'Photography',
    'Music',
  ];
  final List<String> _selectedTags = [];

  Uint8List? _profileImageBytes;
  GeoPoint? _currentLocation;
  String? _city;
  String? _county;
  String? _country;
  bool _isSubmitting = false;
  bool _isPickingImage = false;
  bool _isFetchingLocation = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _xUrlController.dispose();
    _instagramUrlController.dispose();
    _facebookUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    setState(() {
      _isPickingImage = true;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final Uint8List? bytes = result.files.single.bytes;
      if (bytes == null) {
        throw Exception('Unable to read selected image bytes.');
      }

      if (bytes.lengthInBytes > 500000) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an image under 500KB.')),
        );
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _profileImageBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _approveLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please enable location services first.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String? city;
      String? county;
      String? country;
      try {
        final GoogleGeocodingResult geocodingResult =
            await _googleGeocodingService.reverseGeocode(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        city = geocodingResult.city;
        county = geocodingResult.county;
        country = geocodingResult.country;
      } catch (_) {
        city = null;
        county = null;
        country = null;
      }

      await _firestore.collection('users').doc(widget.user.uid).set({
        'location': GeoPoint(position.latitude, position.longitude),
        'city': city,
        'county': county,
        'country': country,
        'cityCounty': [city, county]
            .whereType<String>()
            .where((String part) => part.isNotEmpty)
            .join(', '),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = GeoPoint(position.latitude, position.longitude);
        _city = city;
        _county = county;
        _country = country;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location approved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to approve location: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _completeProfile() async {
    final String displayName = _displayNameController.text.trim();
    final String bio = _bioController.text.trim();
    final String xUrl = _xUrlController.text.trim();
    final String instagramUrl = _instagramUrlController.text.trim();
    final String facebookUrl = _facebookUrlController.text.trim();

    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name.')),
      );
      return;
    }

    if (_selectedTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one main content tag.')),
      );
      return;
    }

    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please approve geolocation before continuing.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String? profileImageBase64 =
          _profileImageBytes == null ? null : base64Encode(_profileImageBytes!);

      await _firestore.collection('users').doc(widget.user.uid).set({
        'displayName': displayName,
        'profileDetails': bio.isEmpty ? null : bio,
        'xUrl': xUrl.isEmpty ? null : xUrl,
        'instagramUrl': instagramUrl.isEmpty ? null : instagramUrl,
        'facebookUrl': facebookUrl.isEmpty ? null : facebookUrl,
        'tags': _selectedTags,
        'location': _currentLocation,
        'city': _city,
        'county': _county,
        'country': _country,
        'cityCounty': [_city, _county]
            .whereType<String>()
            .where((String part) => part.isNotEmpty)
            .join(', '),
        'profileImageBase64': profileImageBase64,
        'profileSetupCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await widget.user.updateDisplayName(displayName);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ProfileDashboardScreen(
            user: widget.user,
            initialUserLocation: _currentLocation,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete profile: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildLogoTitle('Complete Your Profile'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundImage:
                    _profileImageBytes == null ? null : MemoryImage(_profileImageBytes!),
                child: _profileImageBytes == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isPickingImage || _isSubmitting)
                    ? null
                    : _pickProfileImage,
                icon: const Icon(Icons.upload),
                label: Text(
                  _isPickingImage ? 'Uploading...' : 'Upload Profile Picture',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio / Profile Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Socials (optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _xUrlController,
              decoration: const InputDecoration(
                labelText: 'X / Twitter URL',
                helperText: 'https://x.com/yourname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instagramUrlController,
              decoration: const InputDecoration(
                labelText: 'Instagram URL',
                helperText: 'https://instagram.com/yourname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _facebookUrlController,
              decoration: const InputDecoration(
                labelText: 'Facebook URL',
                helperText: 'https://facebook.com/yourname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Main Content Tags',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((String tag) {
                final bool isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Geolocation Approval',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow location to find blogs and bloggers around you!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isSubmitting || _isFetchingLocation)
                    ? null
                    : _approveLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  _isFetchingLocation ? 'Approving Location...' : 'Approve Geolocation',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentLocation == null
                  ? 'Location not approved yet.'
                  : 'Approved: ${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _completeProfile,
                child: Text(
                  _isSubmitting ? 'Saving Profile...' : 'Finish Setup',
                ),
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }
}

class ProfileDashboardScreen extends StatefulWidget {
  const ProfileDashboardScreen({
    required this.user,
    this.initialUserLocation,
    super.key,
  });

  final User user;
  final GeoPoint? initialUserLocation;

  @override
  State<ProfileDashboardScreen> createState() => _ProfileDashboardScreenState();
}

class _ProfileDashboardScreenState extends State<ProfileDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
  int _selectedIndex = 0;
  GeoPoint? _currentUserLocation;
  String _userRole = 'blogger';

  @override
  void initState() {
    super.initState();
    _currentUserLocation = widget.initialUserLocation;
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final doc = await _firestore.collection('users').doc(widget.user.uid).get();
    if (mounted) {
      setState(() {
        _userRole = doc.data()?['role'] as String? ?? 'blogger';
      });
    }
  }

  bool get _isModerator => _userRole == 'admin' || _userRole == 'moderator';

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildLogoOnlyTitle(),
        actions: <Widget>[
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                'Application by Reanielle Broas C00296913',
                style: TextStyle(
                  color: Color(0xFF8E79C9),
                  fontSize: 11,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFD5D0EF),
          image: DecorationImage(
            image: AssetImage('lib/images/lined full.png'),
            fit: BoxFit.cover,
            opacity: 0.35,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 600;
            if (isMobile) {
              return _buildPage(_selectedIndex);
            }
            final double hPad = constraints.maxWidth >= 1400
                ? constraints.maxWidth * 0.20
                : constraints.maxWidth * 0.10;
            return Padding(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 14),
              child: Material(
                elevation: 4,
                color: const Color(0xFFEAEAF4),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: _buildPage(_selectedIndex),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UploadBlogScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF7B68C8),
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Blog'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: _isModerator ? BottomNavigationBarType.fixed : BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'My Profile',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Bloggers',
          ),
          if (_isModerator)
            const BottomNavigationBarItem(
              icon: Icon(Icons.shield),
              label: 'Moderation',
            ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return HomeBlogSearchScreen(
          userLocation: _currentUserLocation,
          onLocationUpdated: (GeoPoint location) {
            setState(() {
              _currentUserLocation = location;
            });
          },
        );
      case 1:
        return _buildProfilePage();
      case 2:
        return BrowsableBloggersScreen(
          currentUserId: widget.user.uid,
          userLocation: _currentUserLocation,
          onLocationUpdated: (GeoPoint location) {
            setState(() {
              _currentUserLocation = location;
            });
          },
        );
      case 3:
        if (_isModerator) {
          return ModerationDashboardScreen(currentUserRole: _userRole);
        }
        return _buildProfilePage();
      default:
        return _buildProfilePage();
    }
  }

  Widget _buildProfilePage() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(widget.user.uid).snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final Map<String, dynamic>? data = snapshot.data?.data();
        final BloggerUser blogger = BloggerUser.fromJson(
          data ?? {},
          widget.user.uid,
        );
        Uint8List? profileImageBytes;
        try {
          final String? profileImageBase64 = blogger.profileImageBase64;
          if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
            profileImageBytes = base64Decode(profileImageBase64);
          }
        } catch (_) {
          profileImageBytes = null;
        }

        final String locationText = [
          blogger.cityCounty,
          [blogger.county, blogger.country]
              .whereType<String>()
              .where((String part) => part.isNotEmpty)
              .join(', '),
        ].where((String? part) => part != null && part.trim().isNotEmpty).cast<String>().firstWhere(
              (String value) => value.trim().isNotEmpty,
              orElse: () => 'Location not set',
            );

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isNarrow = constraints.maxWidth < 600;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: profileImageBytes == null
                                    ? null
                                    : MemoryImage(profileImageBytes),
                                child: profileImageBytes == null
                                    ? const Icon(Icons.person, size: 34)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      blogger.displayName.isEmpty
                                          ? 'Anonymous Blogger'
                                          : blogger.displayName,
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(blogger.email),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Domain: ${blogger.domainLink == null || blogger.domainLink!.isEmpty ? 'Not provided' : blogger.domainLink!}',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(locationText),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Socials',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (blogger.xUrl != null && blogger.xUrl!.isNotEmpty)
                                          Chip(label: Text('X')),
                                        if (blogger.instagramUrl != null &&
                                            blogger.instagramUrl!.isNotEmpty)
                                          Chip(label: Text('Instagram')),
                                        if (blogger.facebookUrl != null &&
                                            blogger.facebookUrl!.isNotEmpty)
                                          Chip(label: Text('Facebook')),
                                        if ((blogger.xUrl == null || blogger.xUrl!.isEmpty) &&
                                            (blogger.instagramUrl == null ||
                                                blogger.instagramUrl!.isEmpty) &&
                                            (blogger.facebookUrl == null ||
                                                blogger.facebookUrl!.isEmpty))
                                          const Text('No socials shared yet.'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bio',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (blogger.profileDetails ?? '').trim().isEmpty
                                    ? 'No bio added yet.'
                                    : blogger.profileDetails!,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Main Tags',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: blogger.tags
                                            .map<Widget>((String tag) => TagChip(tag: tag, small: true))
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => EditBloggerProfileScreen(
                                  userId: widget.user.uid,
                                  blogger: blogger,
                                ),
                              ),
                            );
                            if (!mounted) {
                              return;
                            }
                            setState(() {});
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profile'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'My Uploaded Blogs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMyBlogsSection(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyBlogsSection() {
    final Query<Map<String, dynamic>> myBlogsQuery = _firestore
        .collection('blogs')
        .where('uploadedBy', isEqualTo: widget.user.uid)
        .orderBy('uploadedAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: myBlogsQuery.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Text('Failed to load your blogs: ${snapshot.error}');
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Text('You have not uploaded any blogs yet.');
        }

        return ListView.builder(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> data = docs[index].data();
            final String blogId = docs[index].id;
            final String title = data['title'] as String? ?? '';
            final String description = data['description'] as String? ?? '';
            final String domainLink = data['domainLink'] as String? ?? '';
            final Timestamp? uploadedAt = data['uploadedAt'] as Timestamp?;
            final List<dynamic> tags = data['tags'] as List<dynamic>? ?? [];
            final String? blogImageBase64 = data['blogImageBase64'] as String?;

            Uint8List? blogImageBytes;
            if (blogImageBase64 != null && blogImageBase64.isNotEmpty) {
              try {
                blogImageBytes = base64Decode(blogImageBase64);
              } catch (_) {
                blogImageBytes = null;
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: blogImageBytes == null
                          ? Container(
                              width: 92,
                              height: 92,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_outlined),
                            )
                          : Image.memory(
                              blogImageBytes,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(description),
                          ],
                          if (domainLink.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              domainLink,
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                          if (uploadedAt != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Uploaded: ${uploadedAt.toDate().toLocal().toString().split('.').first}',
                            ),
                          ],
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags
                                  .map<Widget>(
                                    (dynamic tag) => Chip(label: Text('$tag')),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => UploadBlogScreen(
                                        blogId: blogId,
                                        initialBlogData: data,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit Blog'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final ScaffoldMessengerState messenger =
                                      ScaffoldMessenger.of(context);
                                  final bool? shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Delete Blog'),
                                        content: const Text(
                                          'Are you sure you want to delete this blog post?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (shouldDelete != true) {
                                    return;
                                  }

                                  try {
                                    await _firestore.collection('blogs').doc(blogId).delete();
                                    if (!mounted) {
                                      return;
                                    }
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Blog deleted.')),
                                    );
                                  } catch (error) {
                                    if (!mounted) {
                                      return;
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Failed to delete blog: $error')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete),
                                label: const Text('Delete Blog'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

}









