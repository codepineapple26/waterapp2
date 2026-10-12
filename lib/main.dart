import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

// --- FIXED LOCAL NETWORK CONNECTION ---
const String pocketBaseUrl = 'http://10.253.154.218:8090'; 

const String ordersCollection = 'orders';
const double pricePerJug = 5.00;

final PocketBase pocketBase = PocketBase(pocketBaseUrl);

void main() {
  runApp(const WaterDeliveryApp());
}

class WaterDeliveryApp extends StatelessWidget {
  const WaterDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Delivery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const OrderPage(),
    );
  }
}

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = int.parse(_quantityController.text.trim());

    setState(() {
      _submitting = true;
    });

    try {
      final record = await pocketBase.collection(ordersCollection).create(
        body: {
          'customer_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'quantity': quantity,
          'notes': _notesController.text.trim(),
          'status': 'New',
          'total': quantity * pricePerJug,
        },
      );

      if (!mounted) return;

      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _quantityController.text = '1';
      _notesController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order placed! Order ID: ${record.id}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not place order: $error'),
          duration: const Duration(seconds: 6),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Delivery'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Order 5-gallon water jugs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\$${pricePerJug.toStringAsFixed(2)} per jug · Cash on delivery',
                      ),
                      const SizedBox(height: 18),

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer name',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter the customer name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery address',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter the delivery address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Number of jugs (1–50)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final quantity = int.tryParse(value ?? '');
                          if (quantity == null || quantity < 1 || quantity > 50) {
                            return 'Enter a quantity from 1 to 50';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery notes (optional)',
                          hintText: 'Gate code, preferred time, etc.',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 18),

                      FilledButton(
                        onPressed: _submitting ? null : _submitOrder,
                        child: Text(
                          _submitting ? 'Sending order…' : 'Place order',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
