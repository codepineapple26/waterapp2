import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({
    super.key,
    required this.pb,
  });

  final PocketBase pb;

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends State<CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _landmarkController = TextEditingController();

  static const Map<String, List<String>> _roadsByWard = {
    'Ward 1': ['1st Road', '2nd Road', '3rd Road'],
    'Ward 2': ['1st Road', '2nd Road', '3rd Road'],
  };

  String? _selectedWard;
  String? _selectedRoad;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _houseNumberController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _registerCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final driver = widget.pb.authStore.model;

    if (driver == null || driver.getStringValue('role') != 'driver') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in with a driver account.')),
      );
      return;
    }

    final ward = _selectedWard!;
    final road = _selectedRoad!;
    final houseNumber = _houseNumberController.text.trim();
    final landmark = _landmarkController.text.trim();

    final address = [
      ward,
      road,
      if (houseNumber.isNotEmpty) houseNumber,
      if (landmark.isNotEmpty) landmark,
    ].join(', ');

    setState(() => _isSaving = true);

    try {
      await widget.pb.collection('users').create(body: {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'emailVisibility': false,
        'password': _passwordController.text,
        'passwordConfirm': _confirmPasswordController.text,
        'phone': _phoneController.text.trim(),
        'role': 'customer',
        'ward': ward,
        'road': road,
        'house_number': houseNumber,
        'landmark': landmark,
        'address': address,
        'created_by': driver.id,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer registered successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roads = _selectedWard == null
        ? <String>[]
        : (_roadsByWard[_selectedWard] ?? <String>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('Register Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Customer name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                if (value == null || !value.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a phone number' : null,
            ),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Customer password'),
              validator: (value) => value == null || value.length < 8
                  ? 'Enter at least 8 characters'
                  : null,
            ),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirm password'),
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedWard,
              decoration: const InputDecoration(labelText: 'Ward'),
              items: _roadsByWard.keys
                  .map((ward) =>
                      DropdownMenuItem(value: ward, child: Text(ward)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWard = value;
                  _selectedRoad = null;
                });
              },
              validator: (value) => value == null ? 'Select a ward' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedRoad,
              decoration: const InputDecoration(labelText: 'Road'),
              items: roads
                  .map((road) =>
                      DropdownMenuItem(value: road, child: Text(road)))
                  .toList(),
              onChanged: _selectedWard == null
                  ? null
                  : (value) => setState(() => _selectedRoad = value),
              validator: (value) => value == null ? 'Select a road' : null,
            ),
            TextFormField(
              controller: _houseNumberController,
              decoration: const InputDecoration(labelText: 'House/building number'),
            ),
            TextFormField(
              controller: _landmarkController,
              decoration: const InputDecoration(labelText: 'Landmark'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _registerCustomer,
              child: Text(_isSaving ? 'Registering…' : 'Register Customer'),
            ),
          ],
        ),
      ),
    );
  }
}
