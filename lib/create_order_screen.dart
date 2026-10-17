import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:waterapp2/services/pocketbase_service.dart';

class CreateOrderScreen extends StatefulWidget {
  final bool allowSubmit;
  final Map<String, dynamic>? initialValues;

  const CreateOrderScreen({
    super.key,
    this.allowSubmit = true,
    this.initialValues,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  DateTime? _deliveryDate;
  List<RecordModel> _customers = [];
  RecordModel? _selectedCustomer;

  bool _isLoading = false;
  bool _isLoadingCustomers = false;
  bool _isPriceLoading = true;
  double? _pricePerBottle;
  String? _priceError;
  String? _customerLoadError;
  String _statusMessage = '';

  PocketBaseService get _service => PocketBaseService();

  bool get _isDriver =>
      _service.currentUser?.data['role']?.toString() == 'driver';

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadBackendUserData();
    _applyInitialValues(widget.initialValues);
    _loadPricePerBottle();

    if (_isDriver) {
      _loadCustomers();
    }
  }

  @override
  void didUpdateWidget(covariant CreateOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValues != widget.initialValues) {
      _applyInitialValues(widget.initialValues);
    }
  }

  Future<void> _loadCustomers() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCustomers = true;
      _customerLoadError = null;
      _selectedCustomer = null;
    });

    try {
      final records = await _service.client.collection('users').getFullList(
            filter: 'role = "customer"',
          );

      if (!mounted) return;

      setState(() {
        _customers = records;
        _isLoadingCustomers = false;
      });
    } catch (error) {
      debugPrint('Failed to load customers: $error');

      if (!mounted) return;

      setState(() {
        _customers = [];
        _isLoadingCustomers = false;
        _customerLoadError = error.toString();
      });
    }
  }

  Future<void> _loadPricePerBottle({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isPriceLoading = true;
        _priceError = null;
      });
    }

    try {
      final price = await _service.getPricePerBottle();
      if (!mounted) return;

      setState(() {
        _pricePerBottle = price;
        _priceError = null;
        _isPriceLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _priceError = error.toString();
        _isPriceLoading = false;
      });
    }
  }

  void _loadBackendUserData() {
    final user = _service.currentUser;
    if (user == null) return;

    // A driver's profile is not the customer for this order.
    if (_isDriver) {
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      return;
    }

    _nameController.text = user.data['name']?.toString() ?? '';
    _phoneController.text = user.data['phone']?.toString() ?? '';
    _addressController.text = user.data['address']?.toString() ?? '';
  }

  void _applyInitialValues(Map<String, dynamic>? values) {
    if (values == null) return;

    if (values.containsKey('customer_name')) {
      _nameController.text = values['customer_name']?.toString() ?? '';
    }
    if (values.containsKey('phone')) {
      _phoneController.text = values['phone']?.toString() ?? '';
    }
    if (values.containsKey('address')) {
      _addressController.text = values['address']?.toString() ?? '';
    }
    if (values.containsKey('quantity')) {
      _quantityController.text = values['quantity']?.toString() ?? '1';
    }
    if (values.containsKey('notes')) {
      _notesController.text = values['notes']?.toString() ?? '';
    }
  }

  void _selectCustomer(RecordModel? customer) {
    setState(() {
      _selectedCustomer = customer;
      _nameController.text = customer?.data['name']?.toString() ?? '';
      _phoneController.text = customer?.data['phone']?.toString() ?? '';
      _addressController.text = customer?.data['address']?.toString() ?? '';
    });
  }

  Future<void> _pickDeliveryDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 1),
    );

    if (pickedDate != null) {
      setState(() => _deliveryDate = pickedDate);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    setState(() => _statusMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildCustomerPicker() {
    if (!_isDriver) return const SizedBox.shrink();

    if (_isLoadingCustomers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_customerLoadError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not load customers: $_customerLoadError',
              style: const TextStyle(color: Colors.red),
            ),
            TextButton(
              onPressed: _loadCustomers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_customers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            const Expanded(child: Text('No customers were found.')),
            TextButton(
              onPressed: _loadCustomers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<RecordModel>(
        value: _selectedCustomer,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Select customer',
          border: OutlineInputBorder(),
        ),
        hint: const Text('Choose a customer'),
        items: _customers.map((customer) {
          final name = customer.data['name']?.toString() ?? 'Unnamed customer';
          final email = customer.data['email']?.toString() ?? '';

          return DropdownMenuItem<RecordModel>(
            value: customer,
            child: Text(email.isEmpty ? name : '$name ($email)'),
          );
        }).toList(),
        onChanged: widget.allowSubmit ? _selectCustomer : null,
        validator: (customer) =>
            customer == null ? 'Select a customer' : null,
      ),
    );
  }

  Widget _buildPriceSummary() {
    if (_isPriceLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pricePerBottle == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load bottle price'
            '${_priceError == null ? '.' : ': $_priceError'}',
            style: const TextStyle(color: Colors.red),
          ),
          TextButton(
            onPressed: () => _loadPricePerBottle(showLoading: true),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final total = _quantity > 0 ? _quantity * _pricePerBottle! : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Price per bottle: ₹${_pricePerBottle!.toStringAsFixed(2)}'),
          const SizedBox(height: 4),
          Text(
            'Total: ₹${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
  

     if (!widget.allowSubmit) return;

final user = _service.currentUser;
if (!_service.isLoggedIn || user == null) {
  _showMessage('Sign in required to place an order.');
  return;
}

if (_isDriver && _selectedCustomer == null) {
  _showMessage('Please select a customer.');
  return;
}

final address = _addressController.text.trim();
final phone = _phoneController.text.trim();
final quantity = _quantity;
final deliveryDate = _deliveryDate;

if (address.isEmpty) {
  _showMessage('Delivery address cannot be blank.');
  return;
}
if (phone.isEmpty) {
  _showMessage('Contact phone number cannot be blank.');
  return;
}
if (quantity < 1) {
  _showMessage('Quantity must be at least 1.');
  return;
}
if (deliveryDate == null) {
  _showMessage('Please choose an expected delivery date.');
  return;
}

setState(() {
  _isLoading = true;
  _statusMessage = '';
});
try {
  final customer = _isDriver ? _selectedCustomer! : user;
  final customerName = _nameController.text.trim().isNotEmpty
      ? _nameController.text.trim()
      : customer.data['name']?.toString() ?? 'Customer';

  final price = await _service.getPricePerBottle();
  final total = quantity * price;

  final body = <String, dynamic>{
    'user_id': customer.id,
    'customer_name': customerName,
    'phone': phone,
    'address': address,
    'quantity': quantity,
    'notes': _notesController.text.trim(),
    'status': 'New',
    'total': total,
    'amount_paid': 0,
    if (_isDriver) 'driver_id': user.id,
    'delivery_schedule': deliveryDate.toIso8601String().split('T').first,
  };

  await _service.client.collection('orders').create(body: body);

  if (!mounted) return;

  setState(() {
    _statusMessage = 'Order placed successfully!';
    _quantityController.text = '1';
    _notesController.clear();
    _deliveryDate = null;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Order placed successfully!')),
  );
} catch (error, stackTrace) {
  if (!mounted) return;

  _showMessage('Submission failed: $error');
  // ignore: avoid_print
  print('Order submit error: $error\n$stackTrace');
} finally {
  if (mounted) {
    setState(() => _isLoading = false);
  }
}


  Future<void> _confirmAndSubmit() async {
    if (!widget.allowSubmit) return;

    if (_isDriver && _selectedCustomer == null) {
      _showMessage('Please select a customer.');
      return;
    }
    if (_addressController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      _showMessage('Address and phone cannot be blank.');
      return;
    }
    if (_quantity < 1) {
      _showMessage('Quantity must be at least 1.');
      return;
    }
    if (_deliveryDate == null) {
      _showMessage('Please choose a delivery date.');
      return;
    }

    final price = _pricePerBottle ?? await _service.getPricePerBottle();
    final total = _quantity * price;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Text(
          'Customer: ${_nameController.text.trim()}\n'
          'Phone: ${_phoneController.text.trim()}\n'
          'Address: ${_addressController.text.trim()}\n'
          'Quantity: $_quantity\n'
          'Price per bottle: ₹${price.toStringAsFixed(2)}\n'
          'Total: ₹${total.toStringAsFixed(2)}\n'
          'Delivery date: '
          '${MaterialLocalizations.of(dialogContext).formatMediumDate(_deliveryDate!)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Place Order'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _submitOrder();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.allowSubmit)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Viewing mode: order submission is disabled.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            _buildCustomerPicker(),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
              ),
              readOnly: _isDriver,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.allowSubmit ? _pickDeliveryDate : null,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _deliveryDate == null
                    ? 'Expected delivery date'
                    : 'Expected delivery date: '
                        '${MaterialLocalizations.of(context).formatMediumDate(_deliveryDate!)}',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _buildPriceSummary(),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Special Delivery Instructions (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed:
                        widget.allowSubmit ? _confirmAndSubmit : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(
                      widget.allowSubmit
                          ? 'Confirm & Submit Order'
                          : 'Submission disabled',
                    ),
                  ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(child: Text(_statusMessage)),
            ],
          ],
        ),
      ),
    );
  }
}
