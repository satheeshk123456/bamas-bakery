import 'package:flutter/material.dart';
import '../models/branch.dart';
import '../services/auth_service.dart';
import '../services/branch_service.dart';
import 'branch_picker_screen.dart';
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
        if (snap.data == null) return const LoginScreen();

        // Signed in, but which shop? The menu, the prices and the payment
        // QR all depend on the branch, so it has to be settled before the
        // home screen -- and once chosen it is remembered on the device,
        // so this is a one-time question, not a per-launch one.
        return ValueListenableBuilder<Branch?>(
          valueListenable: BranchService.instance.selected,
          builder: (context, branch, _) {
            if (branch == null) return const BranchPickerScreen();
            return const HomeScreen();
          },
        );
      },
    );
  }
}
