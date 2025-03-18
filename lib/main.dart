import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'services/auth_service.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => _authService),
        StreamProvider<bool>(
          create: (_) => _authService.authStateChanges.map((user) => user != null),
          initialData: false,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MediTrack',
        theme: AppTheme.theme,
        initialRoute: '/',
        routes: {
          '/': (context) => AuthWrapper(),
          '/login': (context) => LoginScreen(),
          '/signup': (context) => SignupScreen(),
          '/dashboard': (context) => DashboardScreen(),
          '/inventory': (context) => InventoryScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<bool>();
    return isAuthenticated ? DashboardScreen() : LoginScreen();
  }
}
