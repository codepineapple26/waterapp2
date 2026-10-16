import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pocketbase_service.dart';
import 'order_detail_screen.dart';
import 'create_order_screen.dart';


class DriverDashboard extends StatefulWidget {
  const DriverDashboard({
    super.key,
    required this.service,
    required this.onLogout,
  });

  final PocketBaseService service;
  final VoidCallback onLogout;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _loading = false;
  List<RecordModel> _orders = [];
  String _filter = 'All';

  static const List<String> filters = ['All', 'Unassigned', 'My Claims'];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }
  
Future<void> _openCreateOrder() async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => const CreateOrderScreen(),
    ),
  );

  if (mounted) await _loadOrders();
}
  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final list = await widget.service.getAllOrders();
      if (mounted) setState(() => _orders = list);
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

  List<RecordModel> get _filtered {
    final me = widget.service.currentUser?.id;
    return _orders.where((r) {
      final data = r.data ?? <String, dynamic>{};
      final driverId = data['driver_id']?.toString();

      if (_filter == 'Unassigned') {
        return driverId == null || driverId.isEmpty;
      }

      if (_filter == 'My Claims') {
        return driverId == me;
      }

      return true;
    }).toList();
  }

  Widget _buildTile(RecordModel r) {
    final data = r.data ?? <String, dynamic>{};
    final address = data['address']?.toString() ?? '-';
    final qty = data['quantity']?.toString() ?? '-';
    final status = data['status']?.toString() ?? '-';
    final customerName = data['customer_name']?.toString() ?? '-';
    final driverId = data['driver_id']?.toString();
    final me = widget.service.currentUser?.id;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: status == 'Accepted' || status == 'In Transit'
            ? Colors.orange
            : Colors.blueGrey,
        child: Text(status.isNotEmpty ? status[0].toUpperCase() : '?'),
      ),
      title: Text('$customerName • Qty: $qty'),
      subtitle: Text(address),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(status),
          if (driverId == me) const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool?>(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(
              service: widget.service,
              orderId: r.id,
            ),
          ),
        );
        if (changed == true) {
          await _loadOrders();
        }
      },
      onLongPress: () async {
        if (driverId == null || driverId.isEmpty) {
          try {
            await widget.service.claimOrder(r.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order claimed')),
              );
              await _loadOrders();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Claim failed: ${e.toString()}')),
              );
            }
          }
        } else if (driverId == me) {
          try {
            await widget.service.unclaimOrder(r.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order unclaimed')),
              );
              await _loadOrders();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unclaim failed: ${e.toString()}')),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order already assigned to another driver')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
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
          IconButton(
            tooltip: 'Create Order',
              icon: const Icon(Icons.add_shopping_cart),
             onPressed: _openCreateOrder,
        ),

        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Text('Filter:'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filter,
                    items: filters
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _filter = v);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: list.length,
                      itemBuilder: (_, index) => _buildTile(list[index]),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
  onPressed: () async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const CreateOrderScreen(),
      ),
    );

    if (mounted) await _loadOrders();
  },
  label: const Text('Create Order'),
  icon: const Icon(Icons.add),
),

    );
  }
}
