import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pocketbase_service.dart';

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
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
                              content: Text('Failed to create order: ${err.toString()}'),
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

  Widget _buildOrderTile(RecordModel order) {
    final data = order.data ?? <String, dynamic>{};
    final status = data['status']?.toString() ?? 'Unknown';
    final quantity = data['quantity']?.toString() ?? '-';
    final address = data['address']?.toString() ?? '-';
    final phone = data['phone']?.toString() ?? '-';
    final total = data['total']?.toString() ?? '-';
    final customerName =
        data['customer_name']?.toString() ?? widget.service.currentUser?.data['name'] ?? 'You';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: status == 'New' ? Colors.green : Colors.blueGrey,
        child: Text(status.isNotEmpty ? status[0].toUpperCase() : '?'),
      ),
      title: Text('Qty: $quantity • $customerName'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(address),
          const SizedBox(height: 2),
          Text('Phone: $phone'),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('\$$total'),
          const SizedBox(height: 6),
          Text(status, style: const TextStyle(fontSize: 12)),
        ],
      ),
      isThreeLine: true,
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Order ${order.id}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: $customerName'),
                  const SizedBox(height: 6),
                  Text('Status: $status'),
                  const SizedBox(height: 6),
                  Text('Quantity: $quantity'),
                  const SizedBox(height: 6),
                  Text('Address: $address'),
                  const SizedBox(height: 6),
                  Text('Phone: $phone'),
                  const SizedBox(height: 6),
                  Text('Total: \$$total'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadOrders,
                child: _orders.isEmpty
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
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Tap the + button to create a new order.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) =>
                            _buildOrderTile(_orders[index]),
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                      ),
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
