import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:waterapp2/services/pocketbase_service.dart';

class ViewOrdersListScreen extends StatefulWidget {
  const ViewOrdersListScreen({super.key});

  @override
  State<ViewOrdersListScreen> createState() => _ViewOrdersListScreenState();
}

class _ViewOrdersListScreenState extends State<ViewOrdersListScreen> {
  late Future<List<RecordModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

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

  String _formatTotal(dynamic value) {
    final total = value is num
        ? value
        : num.tryParse(value?.toString() ?? '');

    return total == null ? '—' : '₹${total.toStringAsFixed(2)}';
  }

  void _openOrderDetails(RecordModel order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: order),
      ),
    );
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = _loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh orders',
            onPressed: _refreshOrders,
          ),
        ],
      ),
      body: FutureBuilder<List<RecordModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading orders: ${snapshot.error}'),
              ),
            );
          }

          final orders = snapshot.data ?? const <RecordModel>[];

          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
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
                  leading: const Icon(
                    Icons.water_drop,
                    color: Colors.blue,
                  ),
                  title: Text('Water quantity: $quantity'),
                  subtitle: Text(
                    'Address: $address\n'
                    'Status: ${status.isNotEmpty ? status : 'New'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTotal(total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => _openOrderDetails(order),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  final RecordModel order;

  String _value(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '—';
    }
    return value.toString();
  }

  String _formatTotal(dynamic value) {
    final total = value is num
        ? value
        : num.tryParse(value?.toString() ?? '');

    return total == null ? '—' : '₹${total.toStringAsFixed(2)}';
  }

  Widget _detail(String label, String value) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = order.data;
    final status = order.getStringValue('status').trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _detail('Order ID', order.id),
          _detail('Quantity', _value(data['quantity'])),
          _detail('Address', _value(data['address'])),
          _detail('Status', status.isNotEmpty ? status : 'New'),
          _detail('Total', _formatTotal(data['total'])),
        ],
      ),
    );
  }
}
