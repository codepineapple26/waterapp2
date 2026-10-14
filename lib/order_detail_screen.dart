import 'package:flutter/material.dart';
import 'package:waterapp2/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<RecordModel> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = PocketBaseService().fetchOrderById(widget.orderId);
  }

  Widget _buildRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDynamic(dynamic v) {
    if (v == null) return '—';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: FutureBuilder<RecordModel>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Failed to load order: ${snapshot.error}'),
            ));
          }

          final order = snapshot.data!;

          final id = order.id;
          final customerName = order.getStringValue('customer_name');
          final phone = order.getStringValue('phone');
          final address = order.getStringValue('address');
          final quantity = order.getIntValue('quantity').toString();
          final notes = _formatDynamic(order.data['notes']);
          final status = order.getStringValue('status');
          final total = _formatDynamic(order.data['total']);
          final driverId = _formatDynamic(order.data['driver_id']);
          final created = _formatDynamic(order.data['created'] ?? order.data['created_at'] ?? order.getStringValue('created'));
          final updated = _formatDynamic(order.data['updated'] ?? order.getStringValue('updated'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ID: $id', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildRow('Customer', customerName),
                _buildRow('Phone', phone),
                _buildRow('Address', address),
                _buildRow('Quantity', quantity),
                _buildRow('Notes', notes),
                _buildRow('Status', status),
                _buildRow('Total', total),
                _buildRow('Driver', driverId),
                const SizedBox(height: 12),
                _buildRow('Created', created),
                _buildRow('Updated', updated),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    // refresh
                    setState(() {
                      _orderFuture = PocketBaseService().fetchOrderById(widget.orderId);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshing...')));
                  },
                  child: const Text('Refresh'),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
