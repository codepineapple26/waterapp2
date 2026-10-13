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
  final Future<void> Function() onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<RecordModel>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = widget.service.getMyOrders();
    });
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'New':
        return 'New';
      case 'Processing':
        return 'Processing';
      case 'Out for delivery':
        return 'Out for delivery';
      case 'Delivered':
        return 'Delivered';
      case 'Cancelled':
        return 'Cancelled';
      default:
        return status ?? 'Unknown';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'New':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Out for delivery':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _createDemoOrder() async {
    try {
      await widget.service.createDemoOrder(
        address: '123 Market Street, Downtown',
        phone: '+1 555 123 4567',
        quantity: 2,
        notes: 'Deliver after 6 pm',
      );
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo order created successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to create demo order: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.service.currentUser?.data['name'] ?? 'Customer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await widget.onLogout();
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadOrders(),
        child: FutureBuilder<List<RecordModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48),
                      const SizedBox(height: 16),
                      Text('Unable to load your orders', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(snapshot.error.toString()),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadOrders,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final orders = snapshot.data ?? const [];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello $userName',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              const Text('Here is your delivery activity'),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: _createDemoOrder,
                          child: const Text('New order'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'My orders',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (orders.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No orders yet.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _createDemoOrder,
                            icon: const Icon(Icons.add),
                            label: const Text('Create demo order'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...orders.map((order) {
                    final status = _statusLabel(order.data['status']);
                    final quantity = order.data['quantity'] ?? 0;
                    final total = order.data['total'] ?? 0.0;
                    final createdAt = order.created;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => OrderDetailScreen(order: order),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Order #${order.id.substring(0, 6)}',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withAlpha(26),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.local_drink_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text('$quantity jugs'),
                                    const Spacer(),
                                    Text(
                                      ' A3${total.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text(createdAt.toString()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
