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

    if (mounted) {
      await _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);

    try {
      final list = await widget.service.getAllOrders();
      if (mounted) {
        setState(() => _orders = list);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: $err')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<RecordModel> get _filtered {
    final me = widget.service.currentUser?.id;

    return _orders.where((record) {
      final data = record.data;
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

  String _formatConfirmedAt(dynamic value) {
    if (value == null) return '';

    final dateTime = DateTime.tryParse(value.toString())?.toLocal();
    if (dateTime == null) return '';

    final date = [
      dateTime.year.toString().padLeft(4, '0'),
      dateTime.month.toString().padLeft(2, '0'),
      dateTime.day.toString().padLeft(2, '0'),
    ].join('-');

    final time = [
      dateTime.hour.toString().padLeft(2, '0'),
      dateTime.minute.toString().padLeft(2, '0'),
    ].join(':');

    return '$date $time';
  }

  Widget _buildTile(RecordModel record) {
    final data = record.data;
    final address = data['address']?.toString() ?? '-';
    final quantity = data['quantity']?.toString() ?? '-';
    final status = data['status']?.toString() ?? '-';
    final customerName = data['customer_name']?.toString() ?? '-';
    final driverId = data['driver_id']?.toString();
    final currentDriverId = widget.service.currentUser?.id;

    final isDelivered = status.toLowerCase() == 'delivered';
    final customerConfirmed = data['customer_confirmation'] == true;
    final confirmedAt = _formatConfirmedAt(data['confirmed_at']);

    String? confirmationLabel;
    if (isDelivered) {
      if (customerConfirmed && confirmedAt.isNotEmpty) {
        confirmationLabel = 'Customer confirmed: $confirmedAt';
      } else if (customerConfirmed) {
        confirmationLabel = 'Customer confirmed delivery';
      } else {
        confirmationLabel = 'Awaiting customer confirmation';
      }
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            status == 'Accepted' || status == 'In Transit'
                ? Colors.orange
                : Colors.blueGrey,
        child: Text(status.isNotEmpty ? status[0].toUpperCase() : '?'),
      ),
      title: Text('$customerName • Qty: $quantity'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(address),
          if (confirmationLabel != null) Text(confirmationLabel),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(status),
          if (driverId == currentDriverId)
            const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool?>(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(
              service: widget.service,
              orderId: record.id,
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
            await widget.service.claimOrder(record.id);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order claimed')),
              );
              await _loadOrders();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Claim failed: $e')),
              );
            }
          }
        } else if (driverId == currentDriverId) {
          try {
            await widget.service.unclaimOrder(record.id);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order unclaimed')),
              );
              await _loadOrders();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unclaim failed: $e')),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order already assigned to another driver'),
            ),
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
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: _openCreateOrder,
            tooltip: 'Create Order',
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
                        .map(
                          (filter) => DropdownMenuItem(
                            value: filter,
                            child: Text(filter),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _filter = value);
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
        onPressed: _openCreateOrder,
        label: const Text('Create Order'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
