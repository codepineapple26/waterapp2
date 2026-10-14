import 'package:flutter/material.dart';
import 'package:waterapp2/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<RecordModel> _orderFuture;

  bool _isUpdatingStatus = false;

  // Change these to the status values used by your app.
  final List<String> _statuses = [
    'New',
    'Accepted',
    'Out for delivery',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _orderFuture = PocketBaseService().fetchOrderById(widget.orderId);
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    setState(() => _isUpdatingStatus = true);

    try {
      await pb.collection('orders').update(
        orderId,
        body: {'status': newStatus},
      );

      if (!mounted) return;

      setState(() {
        _orderFuture = PocketBaseService().fetchOrderById(widget.orderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Widget _buildRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDynamic(dynamic value) {
    if (value == null) return '—';
    return value.toString();
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load order: ${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Order not found.'));
          }

          final order = snapshot.data!;

          final id = order.id;
          final customerName = order.getStringValue('customer_name');
          final phone = order.getStringValue('phone');
          final address = order.getStringValue('address');
          final quantity = order.getIntValue('quantity').toString();
          final notes = _formatDynamic(order.data['notes']);
          final status = order.getStringValue('status').trim();
          final total = _formatDynamic(order.data['total']);
          final driverId = _formatDynamic(order.data['driver_id']);
          final created = _formatDynamic(
            order.data['created'] ??
                order.data['created_at'] ??
                order.getStringValue('created'),
          );
          final updated = _formatDynamic(
            order.data['updated'] ?? order.getStringValue('updated'),
          );

          // Include an existing status even if it isn't in _statuses.
          final statusOptions = List<String>.from(_statuses);
          if (status.isNotEmpty && !statusOptions.contains(status)) {
            statusOptions.insert(0, status);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ID: $id',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildRow('Customer', customerName),
                _buildRow('Phone', phone),
                _buildRow('Address', address),
                _buildRow('Quantity', quantity),
                _buildRow('Notes', notes),
                DropdownButtonFormField<String>(
                  value: status.isEmpty ? null : status,
                  decoration: const InputDecoration(
                    labelText: 'Order status',
                  ),
                  items: statusOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: _isUpdatingStatus
                      ? null
                      : (value) {
                          if (value != null && value != status) {
                            _updateStatus(id, value);
                          }
                        },
                ),
                if (_isUpdatingStatus) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                _buildRow('Total', total),
                _buildRow('Driver', driverId),
                const SizedBox(height: 12),
                _buildRow('Created', created),
                _buildRow('Updated', updated),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _orderFuture =
                          PocketBaseService().fetchOrderById(widget.orderId);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refreshing...')),
                    );
                  },
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
