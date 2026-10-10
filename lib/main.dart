import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'services/app_language_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  runApp(const UrbanFarmingAIApp());
}

class UrbanFarmingAIApp extends StatelessWidget {
  const UrbanFarmingAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Farming AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF388E3C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6FAF5),
      ),
      home: const AppStartupGate(),
    );
  }
}

/// Loads the saved app language before showing the authentication screen
/// or the main application.
class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  late final Future<void> _languageLoadFuture;

  @override
  void initState() {
    super.initState();
    _languageLoadFuture = AppLanguageService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _languageLoadFuture,
      builder: (context, languageSnapshot) {
        if (languageSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF6FAF5),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF388E3C)),
            ),
          );
        }

        // If loading the saved language fails, allow the app to open.
        // The language service's default language can still be used.
        return const AuthenticationGate();
      },
    );
  }
}

class AuthenticationGate extends StatefulWidget {
  const AuthenticationGate({super.key});

  @override
  State<AuthenticationGate> createState() => _AuthenticationGateState();
}

class _AuthenticationGateState extends State<AuthenticationGate> {
  int _retryKey = 0;

  void _retryAuthenticationCheck() {
    setState(() {
      _retryKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      key: ValueKey(_retryKey),
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF6FAF5),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF388E3C)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6FAF5),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to check your login status.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check your internet connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retryAuthenticationCheck,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginEntryPage();
        }

        return const AppShell();
      },
    );
  }
}

/// Displays login or registration. Firebase authentication state
/// automatically switches to AppShell after successful sign-in.
class LoginEntryPage extends StatefulWidget {
  const LoginEntryPage({super.key});

  @override
  State<LoginEntryPage> createState() => _LoginEntryPageState();
}

class _LoginEntryPageState extends State<LoginEntryPage> {
  bool _showRegister = false;

  String _t(String key, String fallback) {
    final translated = AppLanguageService.instance.translate(key);
    return translated == key ? fallback : translated;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: _showRegister ? const RegisterPage() : const LoginPage(),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: SafeArea(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _showRegister = !_showRegister;
                      });
                    },
                    child: Text(
                      _showRegister
                          ? _t('Back to Login', 'Back to Login')
                          : _t('Create Account', 'Create Account'),
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
