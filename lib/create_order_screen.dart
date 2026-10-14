import 'package:flutter/material.dart';
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

  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadBackendUserData();
    _applyInitialValues(widget.initialValues);
  }

  @override
  void didUpdateWidget(covariant CreateOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // The screen may remain mounted in an IndexedStack. Apply a new draft
    // when a customer selects "Reorder this order".
    if (oldWidget.initialValues != widget.initialValues) {
      _applyInitialValues(widget.initialValues);
    }
  }

  void _loadBackendUserData() {
    final service = PocketBaseService();

    if (service.isLoggedIn && service.currentUser != null) {
      final userModel = service.currentUser!;

      final backendName = userModel.getStringValue('name');
      final backendPhone = userModel.getStringValue('phone');
      final backendAddress = userModel.getStringValue('address');

      if (backendName.isNotEmpty) _nameController.text = backendName;
      if (backendPhone.isNotEmpty) _phoneController.text = backendPhone;
      if (backendAddress.isNotEmpty) _addressController.text = backendAddress;
    }
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

  Future<void> _submitOrder() async {
    if (!widget.allowSubmit) return;

    final service = PocketBaseService();

    if (!service.isLoggedIn || service.currentUser == null) {
      setState(() => _statusMessage = 'You must be signed in to place an order.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in required')),
      );
      return;
    }

    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();

    if (address.isEmpty) {
      setState(() => _statusMessage = 'Delivery address cannot be blank.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _statusMessage = 'Contact phone number cannot be blank.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final quantity = int.tryParse(_quantityController.text) ?? 1;

      await service.createDemoOrder(
        address: address,
        phone: phone,
        quantity: quantity,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      const msg = 'Order placed successfully!';
      setState(() => _statusMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(msg)),
      );

      _quantityController.text = '1';
      _notesController.clear();
    } catch (error, st) {
      if (!mounted) return;

      final msg = 'Submission failed: ${error.toString()}';
      setState(() => _statusMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

      // ignore: avoid_print
      print('Order submit error: $error\n$st');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAndSubmit() async {
    if (!widget.allowSubmit) return;

    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final total = quantity * 5.0;

    final service = PocketBaseService();
    if (!service.isLoggedIn || service.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in required')),
      );
      return;
    }

    if (address.isEmpty || phone.isEmpty) {
      final msg = address.isEmpty
          ? 'Address cannot be blank.'
          : 'Phone cannot be blank.';
      setState(() => _statusMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${_nameController.text.trim()}'),
            Text('Phone: $phone'),
            Text('Address: $address'),
            Text('Quantity: $quantity'),
            Text('Total: ₹${total.toStringAsFixed(2)}'),
            if (_notesController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Notes:'),
              Text(_notesController.text.trim()),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Place Order'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) await _submitOrder();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place New Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              PocketBaseService().logout();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.allowSubmit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Viewing mode: order submission is disabled. Log in to create orders.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
              ),
              readOnly: !widget.allowSubmit && !PocketBaseService().isLoggedIn,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone Number',
                border: OutlineInputBorder(),
                helperText:
                    'Loaded from profile. Edit if different for this specific order.',
              ),
              keyboardType: TextInputType.phone,
              readOnly: !widget.allowSubmit && !PocketBaseService().isLoggedIn,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                border: OutlineInputBorder(),
                helperText:
                    'Loaded from profile. Edit if different for this specific order.',
              ),
              maxLines: 2,
              readOnly: !widget.allowSubmit && !PocketBaseService().isLoggedIn,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              readOnly: !widget.allowSubmit && !PocketBaseService().isLoggedIn,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Special Delivery Instructions (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              readOnly: !widget.allowSubmit && !PocketBaseService().isLoggedIn,
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
              Center(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.contains('successfully')
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
