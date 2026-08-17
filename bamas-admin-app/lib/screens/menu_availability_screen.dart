import 'dart:io';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/menu_item.dart';
import '../services/menu_service.dart';
import 'menu_edit_screen.dart';

/// Menu tab: toggle items sold-out, and edit each item's photo, price
/// ("rate"), and offer — everything a shop owner controls manually from
/// this admin app, which then shows up on the customer-facing `bamas` app.
class MenuAvailabilityScreen extends StatefulWidget {
  const MenuAvailabilityScreen({super.key});

  @override
  State<MenuAvailabilityScreen> createState() => _MenuAvailabilityScreenState();
}

class _MenuAvailabilityScreenState extends State<MenuAvailabilityScreen> {
  late Future<List<MenuItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = menuService.listItems();
  }

  Future<void> _refresh() async {
    setState(() => _future = menuService.listItems());
    await _future;
  }

  Widget _thumbnail(MenuItem item) {
    Widget child;
    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      child = const Icon(Icons.fastfood_outlined, color: AppBranding.textMuted);
    } else if (item.imageUrl!.startsWith('http')) {
      child = Image.network(
        item.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppBranding.textMuted),
      );
    } else {
      child = Image.file(File(item.imageUrl!), fit: BoxFit.cover);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(height: 52, width: 52, child: Container(color: Colors.grey.shade200, child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: FutureBuilder<List<MenuItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load menu.\n${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = items[i];
              final priceText = item.hasDiscount
                  ? '₹${item.effectivePrice.toStringAsFixed(0)} (was ₹${item.price.toStringAsFixed(0)})'
                  : '₹${item.price.toStringAsFixed(0)}';
              final subtitleParts = [
                priceText,
                if (item.offerLabel != null) item.offerLabel!,
                if (!item.isAvailable) 'SOLD OUT',
              ];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                leading: _thumbnail(item),
                title: Text(item.name),
                subtitle: Text(subtitleParts.join(' • ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit photo, rate & offer',
                      onPressed: () async {
                        final updated = await Navigator.of(context)
                            .push<MenuItem>(MaterialPageRoute(builder: (_) => MenuEditScreen(item: item)));
                        if (updated != null) {
                          setState(() => items[i] = updated);
                        }
                      },
                    ),
                    Switch(
                      value: item.isAvailable,
                      activeThumbColor: AppBranding.success,
                      onChanged: (value) async {
                        setState(() {
                          items[i] = item.copyWith(isAvailable: value);
                        });
                        try {
                          await menuService.setAvailability(item.id, value);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
