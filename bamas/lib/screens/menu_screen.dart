import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../services/firestore_service.dart';
import '../widgets/menu_item_card.dart';
import '../widgets/mini_cart_bar.dart';
import 'cart_screen.dart';

/// Full menu with category filter chips across the top.
class MenuScreen extends StatefulWidget {
  final bool embedded;

  /// Called when the mini cart bar is tapped. When this screen is one of
  /// the home tabs, pass a callback that switches to the Cart tab; when
  /// pushed standalone, leave this null and it opens the Cart screen
  /// directly.
  final VoidCallback? onViewCart;

  const MenuScreen({super.key, this.embedded = false, this.onViewCart});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _firestore = FirestoreService();
  String? _selectedCategoryId; // null == "All"
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search the menu…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: StreamBuilder<List<CategoryModel>>(
            stream: _firestore.categoriesStream(),
            builder: (context, snap) {
              final categories = snap.data ?? [];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _selectedCategoryId == null,
                    onTap: () => setState(() => _selectedCategoryId = null),
                  ),
                  ...categories.map(
                    (c) => _FilterChip(
                      label: c.name,
                      selected: _selectedCategoryId == c.id,
                      onTap: () => setState(() => _selectedCategoryId = c.id),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MenuItem>>(
            stream: _firestore.menuItemsStream(categoryId: _selectedCategoryId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!
                  .where((i) =>
                      _search.isEmpty ||
                      i.name.toLowerCase().contains(_search) ||
                      i.description.toLowerCase().contains(_search))
                  .toList();

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.no_food_outlined,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text(_search.isEmpty
                          ? 'Nothing in this category yet.'
                          : 'No items match "$_search".'),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => MenuItemCard(item: items[i]),
              );
            },
          ),
        ),
      ],
    );

    final viewCart = widget.onViewCart ??
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Our Menu',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          Expanded(child: body),
          MiniCartBar(onViewCart: viewCart),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Our Menu')),
      body: Column(
        children: [
          Expanded(child: body),
          MiniCartBar(onViewCart: viewCart),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppBranding.primary : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppBranding.primary : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppBranding.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
