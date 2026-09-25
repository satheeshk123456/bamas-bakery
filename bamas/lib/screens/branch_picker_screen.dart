import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/branch.dart';
import '../services/branch_service.dart';

/// "Which shop are you ordering from?"
///
/// Shown once, after login, before the menu -- because the menu, the prices
/// and the payment QR all depend on the answer. The choice is remembered, so
/// this screen is not seen again unless the customer taps the branch name in
/// the home header to change it.
class BranchPickerScreen extends StatefulWidget {
  /// true when the customer opened this deliberately to switch branch, so
  /// there is something to go back to and a close button makes sense.
  final bool isChanging;

  const BranchPickerScreen({super.key, this.isChanging = false});

  @override
  State<BranchPickerScreen> createState() => _BranchPickerScreenState();
}

class _BranchPickerScreenState extends State<BranchPickerScreen> {
  late Future<List<Branch>> _future;

  @override
  void initState() {
    super.initState();
    _future = BranchService.instance.fetchBranches();
  }

  void _reload() => setState(() {
        _future = BranchService.instance.fetchBranches();
      });

  Future<void> _pick(Branch branch) async {
    await BranchService.instance.select(branch);
    if (!mounted) return;
    if (widget.isChanging) {
      Navigator.pop(context, true);
    }
    // When this is the first-run gate there is nothing to pop: AuthGate is
    // listening to BranchService.selected and swaps itself to the home
    // screen as soon as the value changes.
  }

  @override
  Widget build(BuildContext context) {
    final current = BranchService.instance.currentId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your branch'),
        automaticallyImplyLeading: widget.isChanging,
      ),
      body: FutureBuilder<List<Branch>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Message(
              icon: Icons.wifi_off,
              title: "Couldn't load our branches",
              body: 'Check your internet connection and try again.',
              onRetry: _reload,
            );
          }
          final branches = snap.data ?? const <Branch>[];
          if (branches.isEmpty) {
            return _Message(
              icon: Icons.store_mall_directory_outlined,
              title: 'No branches are set up yet',
              body: 'Please try again shortly, or call the shop to order.',
              onRetry: _reload,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: branches.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Prices, the menu and delivery are different at each branch, '
                    'so pick the one nearest you.',
                    style: TextStyle(fontSize: 13.5, color: AppBranding.textMuted),
                  ),
                );
              }
              final b = branches[i - 1];
              final isCurrent = b.id == current;
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isCurrent ? AppBranding.primary : Colors.grey.shade300,
                    width: isCurrent ? 1.6 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppBranding.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.storefront, color: AppBranding.primary),
                  ),
                  title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(b.address, style: const TextStyle(fontSize: 12.5)),
                        ),
                      const SizedBox(height: 4),
                      // A closed branch is still selectable -- the menu can
                      // be browsed either way, which is how the single-shop
                      // version behaved too.
                      Text(
                        b.isOpen ? 'Open now' : 'Closed right now',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: b.isOpen ? AppBranding.success : AppBranding.danger,
                        ),
                      ),
                    ],
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle, color: AppBranding.primary)
                      : const Icon(Icons.chevron_right),
                  onTap: () => _pick(b),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onRetry;

  const _Message({required this.icon, required this.title, required this.body, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Colors.grey),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center,
                style: const TextStyle(color: AppBranding.textMuted, fontSize: 13)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
