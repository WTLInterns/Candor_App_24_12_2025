import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/session_provider.dart';
import 'services/session_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FieldForceProApp());
}

class FieldForceProApp extends StatelessWidget {
  const FieldForceProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionProvider(SessionService())..load(),
      child: Consumer<SessionProvider>(
        builder: (_, session, __) {
          final baseColorScheme = const ColorScheme.light(
            primary: Color(0xFF0052CC), // Royal Blue
            secondary: Color(0xFF0A1F44), // Deep Navy
            background: Color(0xFFF5F7FA), // Light background
            surface: Colors.white,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onBackground: Color(0xFF0D1B2A),
            onSurface: Color(0xFF0D1B2A),
            error: Color(0xFFEF4444),
            onError: Colors.white,
          );

          final theme = ThemeData(
            brightness: Brightness.light,
            colorScheme: baseColorScheme,
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            canvasColor: const Color(0xFFF5F7FA),
            fontFamily: 'Poppins',
            textTheme: const TextTheme(
              headlineSmall: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D1B2A),
              ),
              titleMedium: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0D1B2A),
              ),
              bodyMedium: TextStyle(
                fontSize: 16,
                color: Color(0xFF4A5568),
              ),
              bodySmall: TextStyle(
                fontSize: 14,
                color: Color(0xFF4A5568),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0D1B2A),
              elevation: 0.5,
              centerTitle: false,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF0052CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFF0052CC),
              foregroundColor: Colors.white,
              elevation: 6,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF0052CC), width: 1.4),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color(0xFFE5EDFF),
              selectedColor: const Color(0xFF0052CC),
              labelStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0D1B2A),
              ),
              secondaryLabelStyle: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: StadiumBorder(
                side: BorderSide(
                  color: Colors.blue.shade100,
                ),
              ),
            ),
          );

          return MaterialApp(
            title: 'FieldForcePro Tracker',
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: session.isLoggedIn
                ? const DashboardScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
