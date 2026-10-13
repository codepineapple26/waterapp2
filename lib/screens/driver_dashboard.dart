import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';
import 'order_detail_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key, required this.service, required this.onLogout});
  final PocketBaseService service;
  final VoidCallback onLogout;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _loading = false;
  List<RecordModel> _orders = [];
  String _filter = 'All'; // All, Unassigned, My Claims
  static const List<String> filters = ['All', 'Unassigned', 'My Claims'];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final list = await widget.service.getAllOrders(); // server must allow driver listing
      if (mounted) setState(() => _orders = list);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load orders: ${err.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RecordModel> get _filtered {
    final me = widget.service.currentUser?.id;
    return _orders.where((r) {
      final data = r.data ?? <String,dynamic>{};
      final driverId = data['driver_id']?.toString();
      if (_filter == 'Unassigned') return driverId == null || driverId.isEmpty;
      if (_filter == 'My Claims') return driverId == me;
      return true;
    }).toList();
  }

  Widget _buildTile(RecordModel r) {
    final d = r.data ?? <String,dynamic>{};
    final addr = d['address']?.toString() ?? '-';
    final qty = d['quantity']?.toString() ?? '-';
    final status = d['status']?.toString() ?? '-';
    final cust = d['customer_name']?.toString() ?? '-';
    final driverId = d['driver_id']?.toString();
    final me = widget.service.currentUser?.id;
    final claimedByMe = driverId != null && driverId == me;

    return ListTile(
      title: Text('$cust • Qty: $qty'),
      subtitle: Text(addr),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(status), if (claimedByMe) const Icon(Icons.check_circle, color: Colors.green)]),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool?>(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(service: widget.service, orderId: r.id)),
        );
        if (changed == true) await _loadOrders();
      },
      onLongPress: () async {
        // quick claim/unclaim action
        if (driverId == null || driverId.isEmpty) {
          // claim
          try {
            await widget.service.claimOrder(r.id);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order claimed')));
            await _loadOrders();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim failed: ${e.toString()}')));
          }
        } else if (driverId == me) {
          // unclaim
          try {
            await widget.service.unclaimOrder(r.id);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order unclaimed')));
            await _loadOrders();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unclaim failed: ${e.toString()}')));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order already claimed by another driver')));
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
          IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(8), child: Row(children: [
              const Text('Filter:'),
              const SizedBox(width: 12),
              DropdownButton<String>(value: _filter, items: filters.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (v) => v == null ? null : setState(() => _filter = v)),
            ])),
            Expanded(
              child: _loading ? const Center(child: CircularProgressIndicator()) : ListView.separated(
                itemCount: list.length,
                itemBuilder: (_, i) => _buildTile(list[i]),
                separatorBuilder: (_, __) => const Divider(height: 1),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadOrders,
        icon: const Icon(Icons.sync),
        label: const Text('Refresh'),
      ),
    );
  }
}
