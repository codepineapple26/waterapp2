import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bulk_order_summary.dart';


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

  // ---------------------------------------------------------------------------
  // Partial delivery methods
  // ---------------------------------------------------------------------------

  /// Returns all delivery records for an order.
  Future<List<RecordModel>> getOrderDeliveries(String orderId) async {
    return pb.collection('order_deliveries').getFullList(
          filter: 'order = "$orderId"',
          sort: 'created',
        );
  }

  /// Returns bottles that have not yet been delivered or reserved by a request.
  ///
  /// Requested and out-for-delivery records count as reserved, so a customer
  /// cannot request the same remaining bottles twice.
  Future<int> getAvailableDeliveryQuantity(String orderId) async {
    final order = await fetchOrderById(orderId);
    final deliveries = await getOrderDeliveries(orderId);

    final reservedQuantity = deliveries.fold<int>(0, (sum, delivery) {
      final status =
          delivery.data['status']?.toString().toLowerCase() ?? '';

      if (status == 'cancelled') return sum;

      return sum + delivery.getIntValue('quantity');
    });

    final totalQuantity = order.getIntValue('quantity');
    final available = totalQuantity - reservedQuantity;

    return available > 0 ? available : 0;
  }

  /// Creates a delivery request for the signed-in customer.
  ///
  /// The order's amount_paid and total are not changed.
  Future<RecordModel> requestDelivery({
    required String orderId,
    required int quantity,
    DateTime? requestedFor,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw StateError('You must be logged in to request a delivery.');
    }

    if (user.data['role']?.toString() != 'customer') {
      throw StateError('Only customers can request deliveries.');
    }

    if (quantity <= 0) {
      throw ArgumentError('Delivery quantity must be greater than zero.');
    }

    final order = await fetchOrderById(orderId);

    if (order.data['user_id']?.toString() != user.id) {
      throw StateError('You can only request deliveries for your own order.');
    }

    final available = await getAvailableDeliveryQuantity(orderId);

    if (quantity > available) {
      throw StateError(
        'You requested $quantity bottles, but only $available are available.',
      );
    }

    return pb.collection('order_deliveries').create(
      body: {
        'order': orderId,
        'quantity': quantity,
        'status': 'requested',
        'customer_confirmation': false,
        if (requestedFor != null)
          'requested_for': requestedFor.toUtc().toIso8601String(),
      },
    );
  }

  /// Loads a delivery and verifies that the signed-in driver is assigned
  /// to its parent order.
  Future<RecordModel> _getDeliveryForAssignedDriver(
    String deliveryId,
  ) async {
    final user = currentUser;

    if (user == null) {
      throw StateError('You must be logged in.');
    }

    if (user.data['role']?.toString() != 'driver') {
      throw StateError('Only drivers can update deliveries.');
    }

    final delivery =
        await pb.collection('order_deliveries').getOne(deliveryId);
    final orderId = delivery.data['order']?.toString();

    if (orderId == null || orderId.isEmpty) {
      throw StateError('This delivery is not linked to an order.');
    }

    final order = await fetchOrderById(orderId);

    if (order.data['driver_id']?.toString() != user.id) {
      throw StateError('This order is not assigned to you.');
    }

    final assignedDeliveryDriver = delivery.data['driver']?.toString();
    if (assignedDeliveryDriver != null &&
        assignedDeliveryDriver.isNotEmpty &&
        assignedDeliveryDriver != user.id) {
      throw StateError('This delivery is assigned to another driver.');
    }

    return delivery;
  }

  /// Starts a requested delivery for the assigned driver.
  Future<RecordModel> startDelivery(String deliveryId) async {
    final user = currentUser;
    if (user == null) throw StateError('You must be logged in.');

    final delivery = await _getDeliveryForAssignedDriver(deliveryId);
    final status =
        delivery.data['status']?.toString().toLowerCase() ?? '';

    if (status != 'requested') {
      throw StateError('Only requested deliveries can be started.');
    }

    return pb.collection('order_deliveries').update(
      deliveryId,
      body: {
        'status': 'out_for_delivery',
        'driver': user.id,
      },
    );
  }

  /// Marks one partial delivery delivered.
  ///
  /// The parent order is marked Delivered only when its full quantity has
  /// been delivered.
  Future<RecordModel> markDeliveryDelivered(String deliveryId) async {
    final delivery = await _getDeliveryForAssignedDriver(deliveryId);
    final status =
        delivery.data['status']?.toString().toLowerCase() ?? '';

    if (status != 'out_for_delivery') {
      throw StateError(
        'Only a delivery that is out for delivery can be marked delivered.',
      );
    }

    final updatedDelivery =
        await pb.collection('order_deliveries').update(
      deliveryId,
      body: {
        'status': 'delivered',
        'delivered_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    final orderId = delivery.data['order'].toString();
    final order = await fetchOrderById(orderId);
    final deliveries = await getOrderDeliveries(orderId);

    final deliveredQuantity = deliveries.fold<int>(0, (sum, item) {
      final itemStatus =
          item.data['status']?.toString().toLowerCase() ?? '';

      if (itemStatus != 'delivered') return sum;

      return sum + item.getIntValue('quantity');
    });

    final totalQuantity = order.getIntValue('quantity');

    if (deliveredQuantity >= totalQuantity) {
      await pb.collection('orders').update(
        orderId,
        body: {'status': 'Delivered'},
      );
    } else {
      final anotherDeliveryIsInTransit = deliveries.any((item) {
        return item.data['status']?.toString().toLowerCase() ==
            'out_for_delivery';
      });

      await pb.collection('orders').update(
        orderId,
        body: {
          'status':
              anotherDeliveryIsInTransit ? 'Out for delivery' : 'Accepted',
        },
      );
    }

    return updatedDelivery;
  }

  /// Confirms a delivered delivery record for its owning customer.
  ///
  /// Pass an `order_deliveries` record ID—not the parent order ID.
  Future<RecordModel> confirmCustomerDelivery(String deliveryId) async {
    final user = currentUser;

    if (user == null) {
      throw StateError('You must be logged in to confirm delivery.');
    }

    if (user.data['role']?.toString() != 'customer') {
      throw StateError('Only the customer can confirm delivery.');
    }

    final delivery =
        await pb.collection('order_deliveries').getOne(deliveryId);
    final orderId = delivery.data['order']?.toString();

    if (orderId == null || orderId.isEmpty) {
      throw StateError('This delivery is not linked to an order.');
    }

    final order = await fetchOrderById(orderId);

    if (order.data['user_id']?.toString() != user.id) {
      throw StateError(
        'You can only confirm deliveries for your own order.',
      );
    }

    final status =
        delivery.data['status']?.toString().toLowerCase();

    if (status != 'delivered') {
      throw StateError('The driver must mark this delivery delivered first.');
    }

    if (delivery.data['customer_confirmation'] == true) {
      throw StateError('This delivery has already been confirmed.');
    }

    return pb.collection('order_deliveries').update(
      deliveryId,
      body: {
        'customer_confirmation': true,
        'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
  Future<RecordModel> registerCustomerFromDriver({
  required PocketBase pb,
  required String name,
  required String email,
  required String password,
  required String phone,
  required String ward,
  required String road,
  required String houseNumber,
  String landmark = '',
}) async {
  final driver = pb.authStore.record;

  if (driver == null || driver.data['role'] != 'driver') {
    throw Exception('Only a logged-in driver can register a customer.');
  }

  final address = [
    ward,
    road,
    if (houseNumber.trim().isNotEmpty) houseNumber.trim(),
    if (landmark.trim().isNotEmpty) landmark.trim(),
  ].join(', ');

  return pb.collection('users').create(body: {
    'name': name.trim(),
    'email': email.trim(),
    'password': password,
    'passwordConfirm': password,
    'phone': phone.trim(),
    'role': 'customer',
    'ward': ward,
    'road': road,
    'house_number': houseNumber.trim(),
    'landmark': landmark.trim(),
    'address': address, // Keeps the existing text address field populated.
    'created_by': driver.id,
  });
}
  Future<BulkOrderSummary> getBulkOrderSummary(String orderId) async {
  final order = await pb.collection('orders').getOne(orderId);

  final deliveries = await pb.collection('order_deliveries').getFullList(
    filter: 'order = "$orderId" && status = "delivered"',
  );

  final entries = await pb.collection('order_ledger').getFullList(
    filter: 'order = "$orderId"',
  );

  final orderedQuantity =
      (order.data['quantity'] as num?)?.toInt() ?? 0;

  final deliveredQuantity = deliveries.fold<int>(
    0,
    (sum, delivery) =>
        sum + ((delivery.data['quantity'] as num?)?.toInt() ?? 0),
  );

  final totalCharged = entries
      .where((entry) => entry.data['entry_type'] == 'charge')
      .fold<double>(
        0,
        (sum, entry) =>
            sum + ((entry.data['amount'] as num?)?.toDouble() ?? 0),
      );

  final laterPayments = entries
      .where((entry) => entry.data['entry_type'] == 'payment')
      .fold<double>(
        0,
        (sum, entry) =>
            sum + ((entry.data['amount'] as num?)?.toDouble() ?? 0),
      );

  // Keep the existing order.amount_paid as the initial payment.
  // Do not also add that same initial payment as a ledger payment.
  final initialPayment =
      (order.data['amount_paid'] as num?)?.toDouble() ?? 0;

  final totalPaid = initialPayment + laterPayments;

  return BulkOrderSummary(
    orderedQuantity: orderedQuantity,
    deliveredQuantity: deliveredQuantity,
    remainingQuantity:
        (orderedQuantity - deliveredQuantity).clamp(0, orderedQuantity),
    totalCharged: totalCharged,
    totalPaid: totalPaid,
    amountDue: (totalCharged - totalPaid).clamp(0, double.infinity),
  );
}

Future<RecordModel> recordDriverPayment({
  required String orderId,
  required double amount,
  String note = '',
}) async {
  if (amount <= 0) {
    throw ArgumentError('Payment amount must be greater than zero.');
  }

  final driver = pb.authStore.model;

  if (driver == null || driver.getStringValue('role') != 'driver') {
    throw StateError('Only a logged-in driver can record a payment.');
  }

  return pb.collection('order_ledger').create(body: {
    'order': orderId,
    'entry_type': 'payment',
    'amount': amount,
    'note': note,
    'collected_by': driver.id,
  });
}


  Future<void> deleteOrder(String id) async {
    await pb.collection('orders').delete(id);
  }

  Future<void> logout() async {
    pb.authStore.clear();
  }
}
