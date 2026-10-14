import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:waterapp2/services/pocketbase_service.dart';

class CreateOrderScreen extends StatefulWidget {
  final bool allowSubmit;
  const CreateOrderScreen({super.key, this.allowSubmit = true});

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
  }

  void _loadBackendUserData() {
    if (pb.authStore.isValid && pb.authStore.model != null) {
      final userModel = pb.authStore.model as RecordModel;

      final backendName = userModel.getStringValue('name');
      final backendPhone = userModel.getStringValue('phone');
      final backendAddress = userModel.getStringValue('address');

      setState(() {
        if (backendName.isNotEmpty) _nameController.text = backendName;
        if (backendPhone.isNotEmpty) _phoneController.text = backendPhone;
        if (backendAddress.isNotEmpty) _addressController.text = backendAddress;
      });
    }
  }

  Future<void> _submitOrder() async {
    if (!widget.allowSubmit) return;

    if (!pb.authStore.isValid || pb.authStore.model == null) {
      setState(() => _statusMessage = 'You must be signed in to place an order.');
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      setState(() => _statusMessage = 'Delivery address cannot be blank.');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _statusMessage = 'Contact phone number cannot be blank.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final quantity = int.tryParse(_quantityController.text) ?? 1;

      // Use the service layer so logic like total calculation and user checks live in one place.
      final record = await PocketBaseService().createDemoOrder(
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        quantity: quantity,
        notes: _notesController.text.trim(),
      );

      setState(() => _statusMessage = 'Order placed successfully! (id: ${record.id})');
      _quantityController.text = '1';
      _notesController.clear();
    } catch (error) {
      setState(() => _statusMessage = 'Submission failed: ${error.toString()}');
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place New Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              pb.authStore.clear();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
              decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
              readOnly: !widget.allowSubmit && !pb.authStore.isValid,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone Number',
                border: OutlineInputBorder(),
                helperText: 'Loaded from profile. Edit if different for this specific order.',
              ),
              keyboardType: TextInputType.phone,
              readOnly: !widget.allowSubmit && !pb.authStore.isValid,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                border: OutlineInputBorder(),
                helperText: 'Loaded from profile. Edit if different for this specific order.',
              ),
              maxLines: 2,
              readOnly: !widget.allowSubmit && !pb.authStore.isValid,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              readOnly: !widget.allowSubmit && !pb.authStore.isValid,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Special Delivery Instructions (Optional)', border: OutlineInputBorder()),
              maxLines: 2,
              readOnly: !widget.allowSubmit && !pb.authStore.isValid,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: widget.allowSubmit ? _submitOrder : null,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: Text(widget.allowSubmit ? 'Confirm & Submit Order' : 'Submission disabled'),
                  ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.contains('successfully') ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
