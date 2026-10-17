import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String pocketBaseUrl = 'http://10.253.154.218:8090';

late final PocketBase pb;

Future<void> initializePocketBase() async {
  final prefs = await SharedPreferences.getInstance();

  final authStore = AsyncAuthStore(
    save: (String data) async {
      await prefs.setString('pb_auth', data);
    },
    initial: prefs.getString('pb_auth'),
  );

  pb = PocketBase(pocketBaseUrl, authStore: authStore);
}

class PocketBaseService {
  PocketBaseService._();

  static final PocketBaseService _instance = PocketBaseService._();

  factory PocketBaseService() => _instance;

  static const String baseUrl = pocketBaseUrl;

  PocketBase get client => pb;
  bool get isLoggedIn => pb.authStore.isValid;
  RecordModel? get currentUser => pb.authStore.model;

  Future<void> login(String email, String password) async {
    await pb.collection('users').authWithPassword(email, password);
  }

  /// Gets the current bottle price from the pricing record in PocketBase.
  Future<double> getPricePerBottle() async {
    final record = await pb
        .collection('app_settings')
        .getFirstListItem('key = "pricing"');

    final value = record.data['price_per_bottle'];
    if (value is num) {
      return value.toDouble();
    }

    throw StateError(
      'The pricing record is missing a valid price_per_bottle value.',
    );
  }

  /// Creates a new user record in PocketBase and logs them in.
  Future<RecordModel> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'customer',
  }) async {
    try {
      final record = await pb.collection('users').create(
        body: {
          'email': email,
          'password': password,
          'passwordConfirm': password,
          'name': name,
          'role': role,
        },
      );

      await login(email, password);
      return record;
    } catch (e) {
      // ignore: avoid_print
      print('PocketBaseService.signUp error: $e');
      rethrow;
    }
  }

  /// Returns orders for the signed-in customer or driver.
  Future<List<RecordModel>> getMyOrders() async {
    final user = currentUser;
    if (user == null) return const [];

    final role = user.data['role']?.toString();
    final filter = role == 'driver'
        ? 'driver_id = "${user.id}"'
        : 'user_id = "${user.id}"';

    return pb.collection('orders').getFullList(
          filter: filter,
          sort: '-created',
        );
  }

  Future<List<RecordModel>> getAllOrders() async {
    return pb.collection('orders').getFullList(sort: '-created');
  }

  Future<RecordModel> fetchOrderById(String id) async {
    return pb.collection('orders').getOne(id);
  }

  Future<RecordModel> createDemoOrder({
    required String address,
    required String phone,
    required int quantity,
    String notes = '',
    Map<String, dynamic>? deliverySchedule,
  }) async {
    final user = currentUser;
    final userId = user?.id;
    final displayName = user?.data['name'] ?? 'Customer';

    if (userId == null) {
      throw StateError('User must be logged in to create an order.');
    }

    final pricePerBottle = await getPricePerBottle();
    final total = quantity * pricePerBottle;

    return pb.collection('orders').create(
      body: {
        'user_id': userId,
        'customer_name': displayName,
        'phone': phone,
        'address': address,
        'quantity': quantity,
        'notes': notes,
        'status': 'New',
        'total': total,
        if (deliverySchedule != null)
          'delivery_schedule': jsonEncode(deliverySchedule),
      },
    );
  }

  Future<RecordModel> updateOrder(
    String id, {
    String? address,
    String? phone,
    int? quantity,
    String? notes,
  }) async {
    final body = <String, dynamic>{};

    if (address != null) body['address'] = address;
    if (phone != null) body['phone'] = phone;

    if (quantity != null) {
      final pricePerBottle = await getPricePerBottle();
      body['quantity'] = quantity;
      body['total'] = quantity * pricePerBottle;
    }

    if (notes != null) body['notes'] = notes;

    if (body.isEmpty) {
      throw ArgumentError('No fields provided to update');
    }

    return pb.collection('orders').update(id, body: body);
  }

  Future<RecordModel> updateOrderStatus(String id, String status) async {
    return pb.collection('orders').update(
      id,
      body: {'status': status},
    );
  }

  Future<RecordModel> claimOrder(String id) async {
    final userId = currentUser?.id;
    if (userId == null) throw StateError('Not logged in');

    return pb.collection('orders').update(
      id,
      body: {
        'driver_id': userId,
        'status': 'Accepted',
      },
    );
  }

  Future<RecordModel> updateOrderFields(
    String orderId,
    Map<String, dynamic> body,
  ) {
    return pb.collection('orders').update(orderId, body: body);
  }

  Future<void> unclaimOrder(String id) async {
    await pb.collection('orders').update(
      id,
      body: {
        'driver_id': null,
        'status': 'New',
      },
    );
  }

  /// Confirms delivery for the signed-in customer.
  ///
  /// Assumes:
  /// - `customer_confirmation` is a boolean field.
  /// - `confirmed_at` is a PocketBase date field.
  /// - The delivered order status is `Delivered`.
  Future<RecordModel> confirmCustomerDelivery(String orderId) async {
    final user = currentUser;

    if (user == null) {
      throw StateError('You must be logged in to confirm delivery.');
    }

    if (user.data['role']?.toString() != 'customer') {
      throw StateError('Only the customer can confirm delivery.');
    }

    final order = await fetchOrderById(orderId);

    if (order.data['user_id']?.toString() != user.id) {
      throw StateError('You can only confirm delivery for your own order.');
    }

    final status = order.data['status']?.toString().toLowerCase();
    if (status != 'delivered') {
      throw StateError('The driver must mark the order delivered first.');
    }

    if (order.data['customer_confirmation'] == true) {
      throw StateError('Delivery has already been confirmed.');
    }

    return pb.collection('orders').update(
      orderId,
      body: {
        'customer_confirmation': true,
        'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deleteOrder(String id) async {
    await pb.collection('orders').delete(id);
  }

  Future<void> logout() async {
    pb.authStore.clear();
  }
}
