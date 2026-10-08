import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // FIREBASE INITIALIZATION
  // ==========================================================

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // ==========================================================
  // GLOBAL FLUTTER ERROR HANDLING
  // ==========================================================

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    debugPrint('Flutter error: ${details.exception}');
  };

  runApp(const UrbanFarmingAI());
}

// ============================================================
// APP
// ============================================================

class UrbanFarmingAI extends StatelessWidget {
  const UrbanFarmingAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Urban Farming AI',

      // ======================================================
      // THEME
      // ======================================================
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor: const Color(0xFFF7FAF7),

        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        cardTheme: CardThemeData(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(width: 1.5),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 2,
        ),

        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),

      // ======================================================
      // APP
      // ======================================================
      home: const AppShell(),
    );
  }
}
