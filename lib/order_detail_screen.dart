import 'package:flutter/material.dart';
import 'package:waterapp2/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final ValueChanged<Map<String, dynamic>>? onReorder;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.onReorder,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<RecordModel> _orderFuture;

  bool _isUpdatingStatus = false;

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

  void _reorder(RecordModel order) {
    widget.onReorder?.call({
      'customer_name': order.getStringValue('customer_name'),
      'phone': order.getStringValue('phone'),
      'address': order.getStringValue('address'),
      'quantity': order.getIntValue('quantity'),
      'notes': order.data['notes'] ?? '',
    });

    Navigator.of(context).pop();
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
    if (value == null || value.toString().isEmpty) return '—';
    return value.toString();
  }

  String _formatCreated(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final localDate = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
    final minute = localDate.minute.toString().padLeft(2, '0');
    final amPm = localDate.hour >= 12 ? 'PM' : 'AM';

    return '${months[localDate.month - 1]} ${localDate.day}, '
        '${localDate.year} • $hour:$minute $amPm';
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
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load order: ${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Order not found.'));
          }

          final order = snapshot.data!;

          // Keep the PocketBase ID for updates; do not display it in the UI.
          final id = order.id;
          final customerName = order.getStringValue('customer_name');
          final phone = order.getStringValue('phone');
          final address = order.getStringValue('address');
          final quantity = order.getIntValue('quantity').toString();
          final notes = _formatDynamic(order.data['notes']);
          final status = order.getStringValue('status').trim();
          final total = _formatDynamic(order.data['total']);
          final driverId = _formatDynamic(order.data['driver_id']);
          final created = _formatCreated(order.getStringValue('created'));
          final updated = _formatDynamic(
            order.data['updated'] ?? order.getStringValue('updated'),
          );

          final statusOptions = List<String>.from(_statuses);
          if (status.isNotEmpty && !statusOptions.contains(status)) {
            statusOptions.insert(0, status);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (widget.onReorder != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _reorder(order),
                      icon: const Icon(Icons.replay),
                      label: const Text('Reorder this order'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
