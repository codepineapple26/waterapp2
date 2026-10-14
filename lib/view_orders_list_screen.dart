import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:waterapp2/services/pocketbase_service.dart';

class ViewOrdersListScreen extends StatefulWidget {
  const ViewOrdersListScreen({super.key});

  @override
  State<ViewOrdersListScreen> createState() => _ViewOrdersListScreenState();
}

class _ViewOrdersListScreenState extends State<ViewOrdersListScreen> {
  Future<List<RecordModel>> _loadOrders() async {
    final userId = pb.authStore.model?.id;
    if (userId == null || userId.isEmpty) {
      return const [];
    }

    return pb.collection('orders').getFullList(
      filter: 'user_id = "$userId"',
      sort: '-created',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: FutureBuilder<List<RecordModel>>(
        future: _loadOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading orders: ${snapshot.error}'),
              ),
            );
          }

          final orders = snapshot.data ?? const <RecordModel>[];

          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No orders yet.',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final status = order.getStringValue('status').trim();
              final quantity = order.getIntValue('quantity');
              final address = order.getStringValue('address');
              final total = order.data['total'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.water_drop, color: Colors.blue),
                  title: Text('Water quantity: $quantity'),
                  subtitle: Text(
                    'Address: $address\nStatus: ${status.isNotEmpty ? status : 'New'}',
                  ),
                  trailing: Text(
                    total == null ? '—' : '₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
