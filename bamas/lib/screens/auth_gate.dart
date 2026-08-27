import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// The splash screen hands off here. Login is required app-wide, so this
/// is where that's enforced: signed out -> LoginScreen, signed in ->
/// HomeScreen. It listens to AuthService.authStateChanges(), so logging
/// in, registering, or logging out anywhere in the app is picked up here
/// automatically — no screen ever has to navigate to Home/Login manually.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data != null ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
