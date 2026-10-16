import 'package:pocketbase/pocketbase.dart';

const String pocketBaseUrl = 'http://10.253.154.218:8090';

final PocketBase pb = PocketBase(pocketBaseUrl);

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

  /// Creates a new user record in PocketBase and logs them in.
  /// Returns the created RecordModel on success. Throws on error.
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

  Future<List<RecordModel>> getMyOrders() async {
    final userId = currentUser?.id;
    if (userId == null) {
      return const [];
    }

    return pb.collection('orders').getFullList(
          filter: 'user_id = "$userId"',
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
    final userId = currentUser?.id;
    final displayName = currentUser?.data['name'] ?? 'Customer';

    if (userId == null) {
      throw StateError('User must be logged in to create an order.');
    }

    final total = quantity * 5.0;

    final record = await pb.collection('orders').create(
      body: {
        'user_id': userId,
        'customer_name': displayName,
        'phone': phone,
        'address': address,
        'quantity': quantity,
        'notes': notes,
        'status': 'New',
        'total': total,
        'driver_id': null,
        if (deliverySchedule != null)
          'delivery_schedule': deliverySchedule,
      },
    );

    return record;
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
      body['quantity'] = quantity;
      body['total'] = quantity * 5.0;
    }
    if (notes != null) body['notes'] = notes;

    if (body.isEmpty) {
      throw ArgumentError('No fields provided to update');
    }

    return pb.collection('orders').update(id, body: body);
  }

  Future<RecordModel> updateOrderStatus(String id, String status) async {
    return pb.collection('orders').update(id, body: {'status': status});
  }

  Future<RecordModel> claimOrder(String id) async {
    final userId = currentUser?.id;
    if (userId == null) throw StateError('Not logged in');

    return pb.collection('orders').update(id, body: {
      'driver_id': userId,
      'status': 'Accepted',
    });
  }

  Future<void> unclaimOrder(String id) async {
    await pb.collection('orders').update(id, body: {
      'driver_id': null,
      'status': 'New',
    });
  }

  Future<void> deleteOrder(String id) async {
    await pb.collection('orders').delete(id);
  }

  Future<void> logout() async {
    pb.authStore.clear();
  }
}
