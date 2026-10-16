import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pocketbase_service.dart';
import 'order_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.service,
    required this.onLogout,
  });

  final PocketBaseService service;
  final VoidCallback onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = false;
  bool _creating = false;
  List<RecordModel> _orders = [];
  String _search = '';
  String _statusFilter = 'All';

  static const List<String> statuses = [
    'All',
    'New',
    'Accepted',
    'In Transit',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final orders = await widget.service.getMyOrders();
      if (mounted) {
        setState(() => _orders = orders);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: ${err.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RecordModel> get _filteredOrders {
    final query = _search.trim().toLowerCase();
    return _orders.where((r) {
      final data = r.data ?? <String, dynamic>{};
      final status = (data['status'] ?? '').toString();
      final address = (data['address'] ?? '').toString().toLowerCase();
      final phone = (data['phone'] ?? '').toString().toLowerCase();
      final customerName = (data['customer_name'] ?? '').toString().toLowerCase();

      if (_statusFilter != 'All' && status != _statusFilter) return false;
      if (query.isEmpty) return true;

      return address.contains(query) ||
          phone.contains(query) ||
          customerName.contains(query) ||
          r.id.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _showCreateOrderDialog() async {
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Order'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter address' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter phone' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter quantity';
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Quantity must be > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _creating
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() => _creating = true);

                      try {
                        await widget.service.createDemoOrder(
                          address: addressController.text.trim(),
                          phone: phoneController.text.trim(),
                          quantity: int.parse(quantityController.text.trim()),
                          notes: notesController.text.trim(),
                        );

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order created')),
                          );
                          await _loadOrders();
                        }
                      } catch (err) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Failed to create order: ${err.toString()}'),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _creating = false);
                        }
                      }
                    },
              child: _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  String _formatCreated(RecordModel r) {
    final createdRaw = (r.created ?? r.data?['created'])?.toString();
    if (createdRaw == null) return '';
    try {
      final dt = DateTime.parse(createdRaw).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return createdRaw;
    }
  }

  Widget _buildOrderTile(RecordModel order) {
    final data = order.data ?? <String, dynamic>{};
    final status = data['status']?.toString() ?? 'Unknown';
    final qty = data['quantity']?.toString() ?? '-';
    final address = data['address']?.toString() ?? '-';
    final phone = data['phone']?.toString() ?? '-';
    final total = (data['total'] is num)
        ? (data['total'] as num).toDouble()
        : double.tryParse(data['total']?.toString() ?? '') ?? 0.0;
    final name = data['customer_name']?.toString() ??
        widget.service.currentUser?.data['name'] ??
        'You';
    final created = _formatCreated(order);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: status == 'New' ? Colors.green : Colors.blueGrey,
        child: Text(status.isNotEmpty ? status[0].toUpperCase() : '?'),
      ),
      title: Text('$name • Qty: $qty'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(address, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('Phone: $phone'),
          if (created.isNotEmpty)
            Text('Created: $created', style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('\$${total.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          Text(status, style: const TextStyle(fontSize: 12)),
        ],
      ),
      isThreeLine: true,
      onTap: () async {
        final changed = await Navigator.of(context).push<bool?>(
          MaterialPageRoute(
            builder: (context) =>
                OrderDetailScreen(service: widget.service, orderId: order.id),
          ),
        );
        if (changed == true) {
          await _loadOrders();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredOrders;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Test1'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
          actions: [
  TextButton.icon(
    onPressed: widget.onLogout,
    icon: const Icon(Icons.logout),
    label: const Text('Sign out'),
  ),
],

      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText:
                            'Search by address, phone, customer or order id',
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _statusFilter,
                    items: statuses
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _statusFilter = v);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: list.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 40),
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 84,
                                  color: Colors.blueGrey,
                                ),
                                SizedBox(height: 20),
                                Center(
                                  child: Text(
                                    'No orders yet',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                                  child: Text(
                                    'Tap the "New Order" button to place a delivery order.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: list.length,
                              itemBuilder: (context, index) =>
                                  _buildOrderTile(list[index]),
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateOrderDialog,
        label: const Text('New Order'),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}
