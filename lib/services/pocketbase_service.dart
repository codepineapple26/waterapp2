import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

class PocketBaseService {
  PocketBaseService._();

  static final PocketBaseService _instance = PocketBaseService._();

  factory PocketBaseService() => _instance;

  // IMPORTANT:
  // On Android emulator, use 10.0.2.2 instead of localhost
  // On real device, use your computer's LAN IP (for example 192.168.1.10)
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
  }) async {
    await _client.collection('users').create(
      body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': name,
      },
    );

    await login(email, password);
  }

  Future<List<RecordModel>> getMyOrders() async {
    final userId = currentUser?.id;
    if (userId == null) {
      return const [];
    }

    // Fetch all orders for this user, sorted by created desc
    final records = await _client.collection('orders').getFullList(
      filter: 'user_id = "$userId"',
      sort: '-created',
    );

    return records;
  }

  Future<RecordModel> fetchOrderById(String id) async {
    final record = await _client.collection('orders').getOne(id);
    return record;
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
      },
    );

    return record;
  }

  Future<RecordModel> updateOrder(String id, {
    String? address,
    String? phone,
    int? quantity,
    String? notes,
  }) async {
    // Recalculate total if quantity provided
    final body = <String, dynamic>{};
    if (address != null) body['address'] = address;
    if (phone != null) body['phone'] = phone;
    if (quantity != null) {
      body['quantity'] = quantity;
      body['total'] = (quantity * 5.0);
    }
    if (notes != null) body['notes'] = notes;

    if (body.isEmpty) {
      throw ArgumentError('No fields provided to update');
    }

    final updated = await _client.collection('orders').update(id, body: body);
    return updated;
  }

  Future<RecordModel> updateOrderStatus(String id, String status) async {
    final updated = await _client.collection('orders').update(id, body: {
      'status': status,
    });
    return updated;
  }

  Future<void> deleteOrder(String id) async {
    await _client.collection('orders').delete(id);
  }

  Future<void> logout() async {
    _client.authStore.clear();
  }
}
