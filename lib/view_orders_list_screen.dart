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

  String _statusFilter = 'All';
  String _paymentFilter = 'All';
  DateTimeRange? _deliveryRange;

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

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatMoney(dynamic value) {
    final amount = value is num
        ? value
        : num.tryParse(value?.toString() ?? '');

    return amount == null ? '—' : '₹${amount.toStringAsFixed(2)}';
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

  String _formatDeliveryDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';

    try {
      final date = DateTime.parse(value.toString());
      return DateFormat('MMM d, y').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  DateTime? _dateOnly(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;

    final date = DateTime.tryParse(value.toString());
    if (date == null) return null;

    return DateTime(date.year, date.month, date.day);
  }

  String _paymentCategory(RecordModel order) {
    final paid = _number(order.data['amount_paid']);
    final total = _number(order.data['total']);

    if (paid <= 0) return 'Unpaid';
    if (total > 0 && paid >= total) return 'Fully paid';
    return 'Partially paid';
  }

  List<RecordModel> _filteredOrders(List<RecordModel> orders) {
    return orders.where((order) {
      final status = order.getStringValue('status').trim();
      final displayedStatus = status.isEmpty ? 'New' : status;

      if (_statusFilter != 'All' && displayedStatus != _statusFilter) {
        return false;
      }

      if (_paymentFilter != 'All' &&
          _paymentCategory(order) != _paymentFilter) {
        return false;
      }

      if (_deliveryRange != null) {
        // delivery_schedule is the field used when creating orders.
        // delivery_date is checked as a fallback for older records.
        final deliveryDate = _dateOnly(
          order.data['delivery_schedule'] ?? order.data['delivery_date'],
        );

        if (deliveryDate == null) return false;

        final start = DateTime(
          _deliveryRange!.start.year,
          _deliveryRange!.start.month,
          _deliveryRange!.start.day,
        );
        final end = DateTime(
          _deliveryRange!.end.year,
          _deliveryRange!.end.month,
          _deliveryRange!.end.day,
        );

        if (deliveryDate.isBefore(start) || deliveryDate.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _chooseDeliveryRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _deliveryRange,
      helpText: 'Filter by expected delivery date',
    );

    if (range != null && mounted) {
      setState(() => _deliveryRange = range);
    }
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = 'All';
      _paymentFilter = 'All';
      _deliveryRange = null;
    });
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

  Widget _filterControls(List<String> statusOptions) {
    final selectedStatus =
        statusOptions.contains(_statusFilter) ? _statusFilter : 'All';

    final rangeLabel = _deliveryRange == null
        ? 'Expected delivery date'
        : '${DateFormat('MMM d, y').format(_deliveryRange!.start)}'
            ' – ${DateFormat('MMM d, y').format(_deliveryRange!.end)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: statusOptions
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _statusFilter = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _paymentFilter,
                    decoration: const InputDecoration(
                      labelText: 'Payment',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
                      DropdownMenuItem(
                        value: 'Partially paid',
                        child: Text('Partially paid'),
                      ),
                      DropdownMenuItem(
                        value: 'Fully paid',
                        child: Text('Fully paid'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _paymentFilter = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _chooseDeliveryRange,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      rangeLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Orders')),
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

          final statusOptions = <String>{
            'All',
            'New',
            'Accepted',
            'Out for delivery',
            'Delivered',
            ...orders.map((order) {
              final status = order.getStringValue('status').trim();
              return status.isEmpty ? 'New' : status;
            }),
          }.toList();

          final filteredOrders = _filteredOrders(orders);

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _filterControls(statusOptions),
                if (orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(
                      child: Text(
                        'No orders yet.',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  )
                else if (filteredOrders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('No orders match these filters.'),
                    ),
                  )
                else
                  ...filteredOrders.map((order) {
                    final rawStatus =
                        order.getStringValue('status').trim();
                    final status = rawStatus.isEmpty ? 'New' : rawStatus;
                    final quantity = order.getIntValue('quantity');
                    final address = order.getStringValue('address');
                    final deliveryDate = order.data['delivery_schedule'] ??
                        order.data['delivery_date'];

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
                          'Status: $status\n'
                          'Expected delivery: '
                          '${_formatDeliveryDate(deliveryDate)}\n'
                          'Paid: ${_formatMoney(order.data['amount_paid'])}'
                          ' / ${_formatMoney(order.data['total'])}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        isThreeLine: true,
                        onTap: () => _openOrderDetails(order),
                      ),
                    );
                  }),
              ],
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

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // The app locks the field after a positive payment is recorded.
  // A backend reset to 0 unlocks it again after refreshing the order.
  bool get _amountPaidLocked => _number(_order.data['amount_paid']) > 0;

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

    _amountPaidController = TextEditingController(
      text: (_order.data['amount_paid'] ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

  Future<void> _saveDriverUpdates() async {
    final body = <String, dynamic>{
      'status': _status,
    };

    if (!_amountPaidLocked) {
      final amountPaid =
          double.tryParse(_amountPaidController.text.trim());

      if (amountPaid == null || amountPaid < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount paid')),
        );
        return;
      }

      body['amount_paid'] = amountPaid;
    }

    setState(() => _saving = true);

    try {
      final updatedOrder = await pb.collection('orders').update(
        _order.id,
        body: body,
      );

      if (!mounted) return;

      setState(() {
        _order = updatedOrder;
        _status = updatedOrder.getStringValue('status').trim();
        if (_status.isEmpty) _status = 'New';

        _amountPaidController.text =
            (updatedOrder.data['amount_paid'] ?? 0).toString();
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
      final refreshedOrder = await pb.collection('orders').getOne(_order.id);

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

  String _formatDeliveryDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';

    try {
      return DateFormat('MMM d, y').format(DateTime.parse(value.toString()));
    } catch (_) {
      return value.toString();
    }
  }

  String _formatMoney(dynamic value) {
    final amount = value is num
        ? value
        : num.tryParse(value?.toString() ?? '');

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
    final deliveryDate =
        data['delivery_schedule'] ?? data['delivery_date'];

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
          _detail('Expected delivery', _formatDeliveryDate(deliveryDate)),
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
              enabled: !_saving && !_amountPaidLocked,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _amountPaidLocked
                    ? 'Amount paid (already recorded)'
                    : 'Update amount paid',
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
                helperText: _amountPaidLocked
                    ? 'To enter a new amount, reset it to 0 in the backend.'
                    : null,
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
