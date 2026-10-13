import 'package:pocketbase/pocketbase.dart';

class PocketBaseService {
  PocketBaseService._();
  static final PocketBaseService _instance = PocketBaseService._();
  factory PocketBaseService() => _instance;

  static const String baseUrl = 'http://10.253.154.218:8090';

  final PocketBase _client = PocketBase(baseUrl);

  PocketBase get client => _client;

  bool get isLoggedIn => _client.authStore.isValid;
  RecordModel? get currentUser => _client.authStore.model;

  Future<void> login(String email, String password) async {
    await _client.collection('users').authWithPassword(email, password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'customer',
  }) async {
    await _client.collection('users').create(
      body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': name,
        'role': role,
      },
    );

    await login(email, password);
  }

  Future<List<RecordModel>> getMyOrders() async {
    final userId = currentUser?.id;
    if (userId == null) return const [];

    final records = await _client.collection('orders').getFullList(
      filter: 'user_id = "$userId"',
      sort: '-created',
    );

    return records;
  }

  Future<List<RecordModel>> getAllOrders() async {
    final records = await _client.collection('orders').getFullList(
      sort: '-created',
    );
    return records;
  }

  Future<RecordModel> fetchOrderById(String id) async {
    return _client.collection('orders').getOne(id);
  }

  Future<RecordModel> createDemoOrder({
    required String address,
    required String phone,
    required int quantity,
    String notes = '',
  }) async {
    final userId = currentUser?.id;
    final displayName = currentUser?.data['name'] ?? 'Customer';

    if (userId == null) {
      throw StateError('User must be logged in to create an order.');
    }

    final total = quantity * 5.0;

    final record = await _client.collection('orders').create(
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

    return _client.collection('orders').update(id, body: body);
  }

  Future<RecordModel> updateOrderStatus(String id, String status) async {
    return _client.collection('orders').update(id, body: {'status': status});
  }

  Future<RecordModel> claimOrder(String id) async {
    final userId = currentUser?.id;
    if (userId == null) throw StateError('Not logged in');

    return _client.collection('orders').update(id, body: {
      'driver_id': userId,
      'status': 'Accepted',
    });
  }

  Future<void> unclaimOrder(String id) async {
    await _client.collection('orders').update(id, body: {
      'driver_id': null,
      'status': 'New',
    });
  }

  Future<void> deleteOrder(String id) async {
    await _client.collection('orders').delete(id);
  }

  Future<void> logout() async {
    _client.authStore.clear();
  }
}
