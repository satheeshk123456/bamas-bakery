import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../services/firestore_service.dart';
import '../widgets/menu_item_card.dart';

class CategoryScreen extends StatelessWidget {
  final CategoryModel category;
  const CategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: StreamBuilder<List<MenuItem>>(
        stream: firestore.menuItemsStream(categoryId: category.id),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No items in this category yet.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    );
  }
}
