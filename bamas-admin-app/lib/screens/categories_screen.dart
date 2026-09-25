import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/category.dart';
import '../services/api_client.dart';
import '../services/menu_service.dart';
import 'category_add_screen.dart';

/// Categories: add, rename, hide, delete.
///
/// Before this screen a category could be created and then never removed,
/// so a typo or a discontinued range stayed on the customer's home page
/// for good.
///
/// Two different ways out, deliberately:
///   HIDE    the switch. Off = gone from the customer app immediately,
///           items and past orders untouched, reversible. This is the one
///           to reach for.
///   DELETE  the bin. Permanent, and the backend refuses while any item is
///           still filed under it -- otherwise those items would point at
///           a category that no longer exists.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Category>> _future;

  @override
  void initState() {
    super.initState();
    _future = menuService.listCategories(includeHidden: true);
  }

  void _reload() => setState(() {
        _future = menuService.listCategories(includeHidden: true);
      });

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(Category c, bool value) async {
    try {
      await menuService.updateCategory(c.id, {'isActive': value});
      _reload();
      _say(value
          ? '"${c.name}" is back on the customer app.'
          : '"${c.name}" is hidden from customers. Its items are still here.');
    } catch (e) {
      _say('Could not update: ${e is ApiException ? e.message : e}');
    }
  }

  Future<void> _rename(Category c) async {
    final controller = TextEditingController(text: c.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == c.name) return;
    try {
      await menuService.updateCategory(c.id, {'name': name});
      _reload();
    } catch (e) {
      _say('Could not rename: ${e is ApiException ? e.message : e}');
    }
  }

  Future<void> _delete(Category c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '"${c.name}" will be removed permanently.\n\n'
          'If you only want it off the customer app for now, use the switch '
          'instead — that can be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppBranding.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await menuService.deleteCategory(c.id);
      _reload();
      _say('"${c.name}" deleted.');
    } catch (e) {
      // The 409 here is the useful one: it names how many items are still
      // in the way, so it is shown in full rather than summarised.
      _say(e is ApiException ? e.message : 'Could not delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CategoryAddScreen()),
          );
          _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: FutureBuilder<List<Category>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load categories.\n${snap.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final categories = snap.data ?? const <Category>[];
          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No categories yet. Add one so menu items have somewhere '
                  'to go.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = categories[i];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                    title: Text(
                      c.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.isActive ? AppBranding.textDark : AppBranding.textMuted,
                      ),
                    ),
                    subtitle: Text(
                      c.isActive ? 'Showing on the customer app' : 'Hidden from customers',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.isActive ? AppBranding.success : AppBranding.danger,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Rename',
                          onPressed: () => _rename(c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppBranding.danger),
                          tooltip: 'Delete permanently',
                          onPressed: () => _delete(c),
                        ),
                        Switch(value: c.isActive, onChanged: (v) => _toggle(c, v)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
