import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pocketbase_service.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.service,
    required this.orderId,
  });

  final PocketBaseService service;
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  RecordModel? _order;

  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'New';

  static const List<String> statuses = [
    'New',
    'Accepted',
    'In Transit',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _loading = true);
    try {
      final r = await widget.service.fetchOrderById(widget.orderId);
      _order = r;
      final data = r.data ?? <String, dynamic>{};
      _addressController.text = data['address']?.toString() ?? '';
      _phoneController.text = data['phone']?.toString() ?? '';
      _quantityController.text = (data['quantity']?.toString() ?? '1');
      _notesController.text = data['notes']?.toString() ?? '';
      _status = data['status']?.toString() ?? 'New';
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load order: ${err.toString()}')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await widget.service.updateOrder(
        widget.orderId,
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        notes: _notesController.text.trim(),
      );

      if ((_order?.data?['status']?.toString() ?? '') != _status) {
        await widget.service.updateOrderStatus(widget.orderId, _status);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${err.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete order?'),
        content: const Text(
            'This will permanently delete the order. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _deleting = true);

    try {
      await widget.service.deleteOrder(widget.orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order deleted')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${err.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final total = (order?.data?['total'] is num)
        ? (order!.data!['total'] as num).toDouble()
        : double.tryParse(order?.data?['total']?.toString() ?? '') ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(order != null ? 'Order ${order.id}' : 'Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleting ? null : _deleteOrder,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ID: ${order!.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Created: ${_formatCreated(order)}'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Enter address'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Enter phone'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(labelText: 'Quantity'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter quantity';
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null || n <= 0) {
                            return 'Quantity must be > 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notes'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Status:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _status,
                            items: statuses
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _status = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total: \$${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('Save changes'),
                              onPressed: _saving ? null : _saveChanges,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
