import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pocketbase_service.dart';
import 'create_order_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.service,
  });

  final PocketBaseService service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedPlace;
  late Future<dynamic> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = widget.service.getMyOrders();
  }

  Future<void> _refreshOrders() async {
    final future = widget.service.getMyOrders();
    setState(() => _ordersFuture = future);
    await future;
  }

  dynamic _field(dynamic order, List<String> names) {
    Map<String, dynamic>? data;

    if (order is RecordModel) {
      data = order.data;
    } else if (order is Map<String, dynamic>) {
      data = order;
    }

    if (data == null) return null;

    for (final name in names) {
      if (data.containsKey(name)) return data[name];
    }

    return null;
  }

  String _status(dynamic order) {
    return (_field(order, ['status', 'order_status']) ?? 'pending')
        .toString()
        .toLowerCase()
        .trim();
  }

  double _orderTotal(dynamic order) {
    final value = _field(
      order,
      ['total_price', 'total_amount', 'amount'],
    );

    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isPlacingOrder = selectedPlace != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPlacingOrder ? 'Place Order' : 'Dashboard'),
        leading: isPlacingOrder
            ? IconButton(
                tooltip: 'Back to dashboard',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => selectedPlace = null),
              )
            : null,
        actions: [
          if (!isPlacingOrder)
            IconButton(
              tooltip: 'Refresh orders',
              onPressed: _refreshOrders,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: isPlacingOrder
          ? const CreateOrderScreen()
          : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    return FutureBuilder<dynamic>(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load your orders.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refreshOrders,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        final result = snapshot.data;
        final orders = result is Iterable ? result.toList() : <dynamic>[];

        final deliveredCount = orders
            .where((order) => _status(order) == 'delivered')
            .length;

        final pendingCount = orders.where((order) {
          final status = _status(order);
          return status != 'delivered' &&
              status != 'cancelled' &&
              status != 'canceled';
        }).length;

        final totalValue = orders.fold<double>(
          0,
          (sum, order) => sum + _orderTotal(order),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Your order summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 4 : 2;

                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _SummaryCard(
                      title: 'Orders placed',
                      value: '${orders.length}',
                      icon: Icons.receipt_long,
                      color: Colors.blue,
                    ),
                    _SummaryCard(
                      title: 'Delivered',
                      value: '$deliveredCount',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    _SummaryCard(
                      title: 'Pending',
                      value: '$pendingCount',
                      icon: Icons.pending_actions,
                      color: Colors.orange,
                    ),
                    _SummaryCard(
                      title: 'Total order value',
                      value: totalValue.toStringAsFixed(2),
                      icon: Icons.payments_outlined,
                      color: Colors.purple,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            Text(
              'Select a place to place an order',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: selectedPlace,
              decoration: const InputDecoration(
                labelText: 'Place',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Place 1',
                  child: Text('Place 1'),
                ),
                DropdownMenuItem(
                  value: 'Place 2',
                  child: Text('Place 2'),
                ),
              ],
              onChanged: (place) {
                setState(() => selectedPlace = place);
              },
            ),

            const SizedBox(height: 24),
            Text(
              'Recent orders',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            if (orders.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('You have not placed any orders yet.'),
                ),
              )
            else
              ...orders.take(5).map((order) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.water_drop_outlined),
                    title: Text('Status: ${_status(order)}'),
                    subtitle: const Text('Order'),
                    trailing: Text(_orderTotal(order).toStringAsFixed(2)),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
