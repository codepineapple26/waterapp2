import 'package:flutter/material.dart';
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

    final records = await _client.collection('orders').getFullList(
      filter: 'user_id = "$userId"',
      sort: '-created',
    );

    return records;
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

  Future<void> logout() async {
    _client.authStore.clear();
  }
}
