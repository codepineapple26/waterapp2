import 'package:pocketbase/pocketbase.dart';

class PocketBaseService {
  PocketBaseService._();
  static final PocketBaseService _instance = PocketBaseService._();
  factory PocketBaseService() => _instance;

  // change to your PB host as needed
  static const String baseUrl = 'http://10.253.154.218:8090';
  final PocketBase _client = PocketBase(baseUrl);

  PocketBase get client => _client;
  bool get isLoggedIn => _client.authStore.isValid;
  RecordModel? get currentUser => _client.authStore.model;

  Future<void> login(String email, String password) async {
    await _client.collection('users').authWithPassword(email, password);
  }

  Future<void> signUp({required String email, required String password, required String name, String role = 'customer'}) async {
    // store role on user record (admin/web should manage assigning 'driver' later)
    await _client.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
      'name': name,
      'role': role,
    });
    await login(email, password);
  }

  Future<void> logout() async => _client.authStore.clear();

  // Customer: get only my orders
  Future<List<RecordModel>> getMyOrders() async {
    final userId = currentUser?.id;
    if (userId == null) return const [];
    final records = await _client.collection('orders').getFullList(
      filter: 'user_id = "$userId"',
      sort: '-created',
    );
    return records;
  }

  // Driver/admin: get all orders (requires server list rule allowing driver/admin)
  Future<List<RecordModel>> getAllOrders() async {
    final records = await _client.collection('orders').getFullList(sort: '-created');
    return records;
  }

  Future<RecordModel> fetchOrderById(String id) => _client.collection('orders').getOne(id);

  Future<RecordModel> createOrder({
    required String address,
    required String phone,
    required int quantity,
    String notes = '',
  }) async {
    final userId = currentUser?.id;
    final name = currentUser?.data['name'] ?? 'Customer';
    if (userId == null) throw StateError('User not logged in');
    final total = quantity * 5.0;
    return _client.collection('orders').create(body: {
      'user_id': userId,
      'customer_name': name,
      'phone': phone,
      'address': address,
      'quantity': quantity,
      'notes': notes,
      'status': 'New',
      'total': total,
      // driver_id is null at creation
    });
  }

  Future<RecordModel> updateOrder(String id, {String? address, String? phone, int? quantity, String? notes}) async {
    final body = <String, dynamic>{};
    if (address != null) body['address'] = address;
    if (phone != null) body['phone'] = phone;
    if (quantity != null) {
      body['quantity'] = quantity;
      body['total'] = quantity * 5.0;
    }
    if (notes != null) body['notes'] = notes;
    if (body.isEmpty) throw ArgumentError('No fields to update');
    return _client.collection('orders').update(id, body: body);
  }

  Future<RecordModel> updateOrderStatus(String id, String status) async {
    return _client.collection('orders').update(id, body: {'status': status});
  }

  Future<RecordModel> claimOrder(String id) async {
    // set driver_id to current user and set status Accepted
    final userId = currentUser?.id;
    if (userId == null) throw StateError('Not logged in');
    return _client.collection('orders').update(id, body: {'driver_id': userId, 'status': 'Accepted'});
  }

  Future<RecordModel> assignDriver(String id, String driverId) async {
    // admin/web will normally assign; driver app may call this if allowed by rules
    return _client.collection('orders').update(id, body: {'driver_id': driverId});
  }

  Future<void> unclaimOrder(String id) async {
    await _client.collection('orders').update(id, body: {'driver_id': null, 'status': 'New'});
  }

  Future<void> deleteOrder(String id) async => _client.collection('orders').delete(id);
}
