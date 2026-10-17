import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:waterapp2/services/pocketbase_service.dart';

class ViewOrdersListScreen extends StatefulWidget {
  const ViewOrdersListScreen({
    super.key,
    this.onReorder,
    this.isActive = true,
  });

  final ValueChanged<Map<String, dynamic>>? onReorder;

  // HomeScreen must update this when the selected tab changes.
  final bool isActive;

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

  @override
  void didUpdateWidget(covariant ViewOrdersListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) {
      _refreshOrders();
    }
  }

  Future<List<RecordModel>> _loadOrders() async {
    final userId = pb.authStore.model?.id;

    if (userId == null || userId.isEmpty) {
      return const [];
    }

    return pb.collection('orders').getFullList(
          filter: 'user_id = "$userId" || driver_id = "$userId"',
          sort: '-created',
        );
  }

  Future<void> _refreshOrders() async {
    final future = _loadOrders();

    if (mounted) {
      setState(() => _ordersFuture = future);
    }

    try {
      await future;
    } catch (_) {
      // The FutureBuilder displays the error.
    }
  }

  String _formatTotal(dynamic value) {
    final total = value is num ? value : num.tryParse(value?.toString() ?? '');
    return total == null ? '—' : '₹${total.toStringAsFixed(2)}';
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';

    try {
      return DateFormat('MMM d, y • h:mm a')
          .format(DateTime.parse(value.toString()).toLocal());
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _openOrderDetails(RecordModel order) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: order),
      ),
    );

    if (!mounted) return;

    await _refreshOrders();

    if (result?['action'] == 'reorder') {
      final draft = result?['draft'];

      if (draft is Map) {
        widget.onReorder?.call(Map<String, dynamic>.from(draft));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<List<RecordModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refreshOrders,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 160),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading orders: ${snapshot.error}'),
                    ),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data ?? const <RecordModel>[];

          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshOrders,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No orders yet.',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
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
                      'Status: ${status.isNotEmpty ? status : 'New'}\n'
                      '${_formatDate(order.data['created'])}',
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
            ),
          );
        },
      ),
    );
  }
}

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  final RecordModel order;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final List<String> _statuses = [
    'New',
    'Accepted',
    'Out for delivery',
    'Delivered',
  ];

  late RecordModel _order;
  late String _status;
  late TextEditingController _amountPaidController;
  bool _saving = false;

  bool get _isDriver =>
      pb.authStore.model?.getStringValue('role') == 'driver';

  @override
  void initState() {
    super.initState();

    _order = widget.order;
    _status = _order.getStringValue('status').trim();

    if (_status.isEmpty) {
      _status = 'New';
    }
    if (!_statuses.contains(_status)) {
      _statuses.insert(0, _status);
    }

    final amountPaid = _order.data['amount_paid'];
    _amountPaidController = TextEditingController(
      text: amountPaid == null ? '0' : amountPaid.toString(),
    );
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

  Future<void> _saveDriverUpdates() async {
    final amountPaid = double.tryParse(_amountPaidController.text.trim());

    if (amountPaid == null || amountPaid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount paid')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final updatedOrder = await pb.collection('orders').update(
        _order.id,
        body: {
          'status': _status,
          'amount_paid': amountPaid,
        },
      );

      if (!mounted) return;

      setState(() {
        _order = updatedOrder;
        _status = updatedOrder.getStringValue('status').trim();
        _amountPaidController.text =
            (updatedOrder.data['amount_paid'] ?? amountPaid).toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update order: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refreshOrder() async {
    try {
      final refreshedOrder =
          await pb.collection('orders').getOne(_order.id);

      if (!mounted) return;

      setState(() {
        _order = refreshedOrder;
        _status = refreshedOrder.getStringValue('status').trim();
        if (_status.isEmpty) _status = 'New';
        _amountPaidController.text =
            (refreshedOrder.data['amount_paid'] ?? 0).toString();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh order: $e')),
      );
    }
  }

  void _reorder() {
    final data = _order.data;

    Navigator.pop<Map<String, dynamic>>(context, {
      'action': 'reorder',
      'draft': {
        'customer_name': data['customer_name'],
        'phone': data['phone'],
        'address': data['address'],
        'quantity': data['quantity'],
        'notes': data['notes'],
      },
    });
  }

  String _value(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '—';
    return value.toString();
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';

    try {
      return DateFormat('MMM d, y • h:mm a')
          .format(DateTime.parse(value.toString()).toLocal());
    } catch (_) {
      return value.toString();
    }
  }

  String _formatMoney(dynamic value) {
    final amount = value is num ? value : num.tryParse(value?.toString() ?? '');
    return amount == null ? '—' : '₹${amount.toStringAsFixed(2)}';
  }

  Widget _detail(String label, String value) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _order.data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh order',
            onPressed: _saving ? null : _refreshOrder,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _detail('Customer', _value(data['customer_name'])),
          _detail('Phone', _value(data['phone'])),
          _detail('Quantity', _value(data['quantity'])),
          _detail('Address', _value(data['address'])),
          _detail('Notes', _value(data['notes'])),
          _detail('Status', _status),
          _detail('Order placed', _formatDate(data['created'])),
          _detail('Total', _formatMoney(data['total'])),
          _detail('Amount paid', _formatMoney(data['amount_paid'])),
          _detail('Delivery date', _formatDate(data['delivery_date'])),

          if (_isDriver) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _statuses.contains(_status) ? _status : null,
              decoration: const InputDecoration(
                labelText: 'Update status',
              ),
              items: _statuses
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountPaidController,
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Update amount paid',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveDriverUpdates,
                child: Text(_saving ? 'Saving…' : 'Save updates'),
              ),
            ),
            if (_saving) const LinearProgressIndicator(),
          ],

          if (!_isDriver) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _reorder,
                icon: const Icon(Icons.replay),
                label: const Text('Reorder this order'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
