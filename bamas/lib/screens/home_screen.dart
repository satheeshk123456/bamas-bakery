import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/category.dart';
import '../models/review.dart';
import '../models/shop_settings.dart';
import '../services/cart_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/category_card.dart';
import '../widgets/hero_banner.dart';
import 'cart_screen.dart';
import 'category_screen.dart';
import 'enquiry_screen.dart';
import 'menu_screen.dart';
import 'order_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  final _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(firestore: _firestore),
      const MenuScreen(embedded: true),
      const EnquiryScreen(embedded: true),
      const CartScreen(embedded: true),
    ];

    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_navIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        selectedFontSize: 11.5,
        unselectedFontSize: 11.5,
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_outlined),
              activeIcon: Icon(Icons.restaurant_menu),
              label: 'Menu'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.help_outline),
              activeIcon: Icon(Icons.help),
              label: 'Enquiry'),
          BottomNavigationBarItem(
            icon: Consumer<CartProvider>(
              builder: (_, cart, __) => Badge(
                label: Text('${cart.itemCount}'),
                isLabelVisible: cart.itemCount > 0,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
            activeIcon: const Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final FirestoreService firestore;
  const _HomeTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopSettings>(
      stream: firestore.shopSettingsStream(),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data;
        final isOpen = settings?.isOpen ?? true;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(isOpen: isOpen)),
            if (!isOpen) const SliverToBoxAdapter(child: _ClosedBanner()),

            // Hero banner — needs reviews for the live rating badge.
            SliverToBoxAdapter(
              child: StreamBuilder<List<Review>>(
                stream: firestore.reviewsStream(),
                builder: (context, reviewSnap) => HeroBanner(
                  settings: settings,
                  reviews: reviewSnap.data ?? const [],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: _MyOrdersCard()),

            // "Chef's Specials" now shows the categories — tap one (e.g.
            // Burgers) to open that category's own page with its items.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                child: Text("Chef's Specials",
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<List<CategoryModel>>(
                stream: firestore.categoriesStream(),
                builder: (context, snap) {
                  final categories = snap.data ?? [];
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (categories.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                          'No categories yet — add some from the admin panel.'),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, i) {
                      final c = categories[i];
                      return CategoryCard(
                        category: c,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CategoryScreen(category: c),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        );
      },
    );
  }
}

/// The white rounded logo bar, matching the reference design.
class _Header extends StatelessWidget {
  final bool isOpen;
  const _Header({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(44),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Image.asset(
                AppBranding.logoAsset,
                height: 56,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => Text(
                  AppBranding.shopName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: (isOpen ? AppBranding.success : AppBranding.danger)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  color: isOpen ? AppBranding.success : AppBranding.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "My Orders" lives here now that the bottom bar is full.
class _MyOrdersCard extends StatelessWidget {
  const _MyOrdersCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppBranding.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('My Orders',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppBranding.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppBranding.danger, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "We're currently closed. You can browse the menu but ordering is paused.",
              style: TextStyle(color: AppBranding.danger, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
