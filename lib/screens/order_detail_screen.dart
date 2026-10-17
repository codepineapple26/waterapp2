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
  final _amountPaidController = TextEditingController();

  String _status = 'New';
  String? _deliveryDate;

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
      _quantityController.text = data['quantity']?.toString() ?? '1';
      _notesController.text = data['notes']?.toString() ?? '';
      _amountPaidController.text = data['amount_paid']?.toString() ?? '0';
      _status = data['status']?.toString() ?? 'New';
      _deliveryDate = data['delivery_date']?.toString();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load order: $err')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Not delivered yet';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatCreated(RecordModel r) {
    final createdRaw = (r.created ?? r.data?['created'])?.toString();
    if (createdRaw == null) return '';
    return _formatDate(createdRaw);
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final amountPaid = double.tryParse(_amountPaidController.text.trim());
    if (amountPaid == null || amountPaid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount paid.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.service.updateOrder(
        widget.orderId,
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        notes: _notesController.text.trim(),
      );

      final body = <String, dynamic>{
        'amount_paid': amountPaid,
      };

      if (_status.toLowerCase() == 'delivered' &&
          (_deliveryDate == null || _deliveryDate!.isEmpty)) {
        body['delivery_date'] = DateTime.now().toUtc().toIso8601String();
      }

      await widget.service.updateOrderFields(widget.orderId, body);

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
          SnackBar(content: Text('Failed to update: $err')),
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
          'This will permanently delete the order. Are you sure?',
        ),
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
          SnackBar(content: Text('Failed to delete: $err')),
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
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final totalValue = order?.data?['total'];
    final total = totalValue is num
        ? totalValue.toDouble()
        : double.tryParse(totalValue?.toString() ?? '') ?? 0.0;

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
                      const SizedBox(height: 8),
                      Text('Delivery date: ${_formatDate(_deliveryDate)}'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter address' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter phone' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(labelText: 'Quantity'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          return n == null || n <= 0
                              ? 'Quantity must be greater than 0'
                              : null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notes'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountPaidController,
                        decoration: const InputDecoration(
                          labelText: 'Amount paid',
                          prefixText: '\$',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final value = double.tryParse(v?.trim() ?? '');
                          return value == null || value < 0
                              ? 'Enter a valid amount'
                              : null;
                        },
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
                            value: statuses.contains(_status) ? _status : 'New',
                            items: statuses
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _status = v);
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
                                        strokeWidth: 2,
                                      ),
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
