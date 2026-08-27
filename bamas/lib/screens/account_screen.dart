import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'order_history_screen.dart';

/// Profile info for the signed-in account (name/phone/email, fetched
/// from the backend's GET /account/me — bamas-admin-backend, not a
/// direct Firestore read), the account's order history embedded below
/// it, and a log-out button.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<AppUser?> _future;

  @override
  void initState() {
    super.initState();
    _future = AuthService.instance.fetchProfile();
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    // Pop back to the root route so the AuthGate's freshly-rebuilt
    // LoginScreen (swapped in the moment we signed out) becomes visible,
    // instead of leaving this screen sitting on top of it.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: FutureBuilder<AppUser?>(
        future: _future,
        builder: (context, snap) {
          final profile = snap.data;
          final loading = snap.connectionState == ConnectionState.waiting;
          final initial =
              (profile?.name.isNotEmpty ?? false) ? profile!.name[0].toUpperCase() : '?';
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppBranding.primary.withValues(alpha: 0.12),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppBranding.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loading
                                ? 'Loading…'
                                : ((profile?.name.isNotEmpty ?? false) ? profile!.name : '—'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          if ((profile?.phone ?? '').isNotEmpty)
                            Text(profile!.phone, style: const TextStyle(color: AppBranding.textMuted)),
                          if ((profile?.email ?? '').isNotEmpty)
                            Text(profile!.email, style: const TextStyle(color: AppBranding.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Expanded(child: OrderHistoryScreen(embedded: true)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
