import 'package:flutter/material.dart';
import 'package:waterapp2/services/pocketbase_service.dart';
import 'widgets/delivery_schedule_picker.dart';

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

  DeliverySchedule? _deliverySchedule;

  bool _isLoading = false;
  bool _isPriceLoading = true;
  double? _pricePerBottle;
  String? _priceError;
  String _statusMessage = '';

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadBackendUserData();
    _applyInitialValues(widget.initialValues);
    _loadPricePerBottle();
  }

  @override
  void didUpdateWidget(covariant CreateOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialValues != widget.initialValues) {
      _applyInitialValues(widget.initialValues);
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
      final price = await PocketBaseService().getPricePerBottle();

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

  void _showMessage(String message) {
    setState(() => _statusMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
            'Could not load bottle price${_priceError == null ? '.' : ': $_priceError'}',
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
          Text(
            'Price per bottle: ₹${_pricePerBottle!.toStringAsFixed(2)}',
          ),
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

    final service = PocketBaseService();

    if (!service.isLoggedIn || service.currentUser == null) {
      _showMessage('Sign in required to place an order.');
      return;
    }

    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final schedule = _deliverySchedule;
    final quantity = _quantity;

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
    if (schedule == null) {
      _showMessage('Please choose a delivery date and time.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await service.createDemoOrder(
        address: address,
        phone: phone,
        quantity: quantity,
        notes: _notesController.text.trim(),
        deliverySchedule: schedule.toJson(),
      );

      if (!mounted) return;

      const message = 'Order placed successfully!';
      setState(() {
        _statusMessage = message;
        _quantityController.text = '1';
        _notesController.clear();
        _deliverySchedule = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(message)),
      );
    } catch (error, st) {
      if (!mounted) return;

      final message = 'Submission failed: $error';
      setState(() => _statusMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
    final quantity = _quantity;
    final schedule = _deliverySchedule;

    final service = PocketBaseService();
    if (!service.isLoggedIn || service.currentUser == null) {
      _showMessage('Sign in required');
      return;
    }

    if (address.isEmpty || phone.isEmpty) {
      _showMessage(
        address.isEmpty ? 'Address cannot be blank.' : 'Phone cannot be blank.',
      );
      return;
    }

    if (quantity < 1) {
      _showMessage('Quantity must be at least 1.');
      return;
    }

    if (schedule == null) {
      _showMessage('Please choose a delivery date and time.');
      return;
    }

    // Fetch a fresh price for the confirmation dialog.
    double pricePerBottle;
    try {
      pricePerBottle = await service.getPricePerBottle();

      if (!mounted) return;
      setState(() {
        _pricePerBottle = pricePerBottle;
        _priceError = null;
        _isPriceLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not load bottle price: $error');
      return;
    }

    final total = quantity * pricePerBottle;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${_nameController.text.trim()}'),
            Text('Phone: $phone'),
            Text('Address: $address'),
            Text('Quantity: $quantity'),
            Text(
              'Price per bottle: ₹${pricePerBottle.toStringAsFixed(2)}',
            ),
            Text('Total: ₹${total.toStringAsFixed(2)}'),
            Text(
              'Delivery date: '
              '${MaterialLocalizations.of(dialogContext).formatMediumDate(schedule.date)}',
            ),
            Text('Delivery window: ${schedule.slot.label}'),
            if (_notesController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Notes:'),
              Text(_notesController.text.trim()),
            ],
          ],
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
                  'Viewing mode: order submission is disabled. '
                  'Log in to create orders.',
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

            // Customer selects the requested delivery date and time.
            DeliverySchedulePicker(
              onChanged: (schedule) {
                setState(() => _deliverySchedule = schedule);
              },
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
              readOnly: !widget.allowSubmit && !PocketBaseService().isLoggedIn,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: widget.allowSubmit ? _confirmAndSubmit : null,
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
