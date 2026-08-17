import '../models/menu_item.dart';
import '../models/order.dart';

/// Fake data so the admin app is fully clickable before the FastAPI
/// backend is running (kDemoMode = true in app_config.dart).
List<Order> demoOrders() => [
      Order(
        id: 'demo1',
        items: [
          OrderItemLine(name: 'Classic Beef Burger', price: 120, quantity: 2),
          OrderItemLine(name: 'Peri Peri Fries', price: 80, quantity: 1),
        ],
        totalAmount: 320,
        customerName: 'Ravi Kumar',
        customerPhone: '+919876543210',
        address: '12 MG Road, Bengaluru',
        status: 'pending',
        createdAt: DateTime.now().toIso8601String(),
      ),
      Order(
        id: 'demo2',
        items: [OrderItemLine(name: 'Spicy Chicken Burger', price: 130, quantity: 1)],
        totalAmount: 130,
        customerName: 'Anita Sharma',
        customerPhone: '+919812345678',
        address: '4th Cross, Indiranagar',
        status: 'accepted',
        paymentMethod: 'gpay',
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)).toIso8601String(),
      ),
      Order(
        id: 'demo3',
        items: [OrderItemLine(name: 'Cold Coke', price: 40, quantity: 3)],
        totalAmount: 120,
        customerName: 'Farhan Ali',
        customerPhone: '+919900112233',
        address: 'Whitefield Main Road',
        status: 'completed',
        paymentMethod: 'cod',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      ),
    ];

List<MenuItem> demoMenuItems() => [
      MenuItem(
        id: 'm1',
        name: 'Classic Beef Burger',
        description: 'Grilled patty, cheddar, lettuce.',
        price: 120,
        isAvailable: true,
        categoryId: 'burgers',
        imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
        discountPercent: 15,
        offerLabel: 'Combo Deal',
      ),
      MenuItem(
        id: 'm2',
        name: 'Spicy Chicken Burger',
        description: 'Crispy chicken, spicy mayo.',
        price: 130,
        isAvailable: true,
        categoryId: 'burgers',
        imageUrl: 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=400',
      ),
      MenuItem(
        id: 'm3',
        name: 'Peri Peri Fries',
        description: 'Crispy fries, peri peri seasoning.',
        price: 80,
        isAvailable: false,
        categoryId: 'fries',
        imageUrl: 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?w=400',
      ),
      MenuItem(
        id: 'm4',
        name: 'Cold Coke',
        description: 'Chilled 300ml bottle.',
        price: 40,
        isAvailable: true,
        categoryId: 'drinks',
        discountAmount: 5,
        offerLabel: 'Weekend Special',
      ),
    ];
