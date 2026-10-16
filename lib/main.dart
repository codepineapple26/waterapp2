import 'package:flutter/material.dart';
import 'package:waterapp2/services/pocketbase_service.dart';
import 'package:waterapp2/create_order_screen.dart';
import 'package:waterapp2/view_orders_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = pb.authStore.isValid;

  void _handleLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Water Delivery App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _isLoggedIn
          ? const HomeScreen()
          : LoginScreen(onLoginSuccess: _handleLoginSuccess),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _ordersVersion = 0;

  bool _showOrderForm = false;
  String? _selectedPlaceId;
  Map<String, dynamic>? _reorderDraft;

  late final Future<List<dynamic>> _placesFuture;

  bool get _isDriver =>
      pb.authStore.model?.getStringValue('role') == 'driver';

  @override
  void initState() {
    super.initState();

    // Change 'delivery_places' if your PocketBase collection has another name.
    _placesFuture = pb.collection('delivery_places').getFullList(sort: 'name');
  }

  void _handleReorder(Map<String, dynamic> draft) {
    if (_isDriver) return;

    // A customer must still choose a delivery place before the form opens.
    setState(() {
      _reorderDraft = draft;
      _currentIndex = 0;
      _showOrderForm = false;
    });
  }

  void _openOrderForm(dynamic place) {
    setState(() {
      _selectedPlaceId = place.id;
      _showOrderForm = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isDriver) {
      return Scaffold(
        appBar: AppBar(title: const Text('Orders')),
        body: ViewOrdersListScreen(
          key: ValueKey('driver-orders-$_ordersVersion'),
          onReorder: _handleReorder,
        ),
      );
    }

    if (_showOrderForm && _selectedPlaceId != null) {
      return _buildOrderForm();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Dashboard' : 'My Orders'),
      ),
      body: _currentIndex == 0
          ? _buildDashboard()
          : ViewOrdersListScreen(
              key: ValueKey('orders-$_ordersVersion'),
              onReorder: _handleReorder,
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _showOrderForm = false;

            if (index == 1) {
              _ordersVersion++;
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'My Orders',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderForm() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showOrderForm = false),
        ),
      ),
      body: CreateOrderScreen(
        key: ValueKey('create-order-$_selectedPlaceId'),
        allowSubmit: true,
        initialValues: {
          ...?_reorderDraft,

          // These keys must match what CreateOrderScreen reads and saves.
          'delivery_place_id': _selectedPlaceId,
        },
      ),
    );
  }

  Widget _buildDashboard() {
    return FutureBuilder<List<dynamic>>(
      future: _placesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load delivery places: ${snapshot.error}'),
            ),
          );
        }

        final places = snapshot.data ?? [];

        if (places.isEmpty) {
          return const Center(
            child: Text('No delivery places are available.'),
          );
        }

        final selectedPlace = places.cast<dynamic>().where((place) {
          return place.id == _selectedPlaceId;
        }).firstOrNull;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Welcome',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Choose a delivery place to start an order.'),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedPlaceId,
              decoration: const InputDecoration(
                labelText: 'Delivery place',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: places.map<DropdownMenuItem<String>>((place) {
                // Change 'name' if your place-name field has another name.
                final placeName = place.getStringValue('name');
                return DropdownMenuItem<String>(
                  value: place.id as String,
                  child: Text(placeName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedPlaceId = value);
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: selectedPlace == null
                  ? null
                  : () => _openOrderForm(selectedPlace),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Continue to order'),
            ),
          ],
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  final VoidCallback onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authData = await pb.collection('users').authWithPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );

      if (authData.token.isNotEmpty && mounted) {
        widget.onLoginSuccess();
      }
    } catch (e, st) {
      debugPrint('Login error: $e\n$st');

      if (mounted) {
        setState(() {
          _errorMessage =
              'Invalid email/password or server connection dropped.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.water_drop, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Water Delivery Login',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Sign In'),
                    ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SignupScreen(
                        onLoginSuccess: widget.onLoginSuccess,
                      ),
                    ),
                  );
                },
                child: const Text('Create an account'),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.onLoginSuccess,
  });

  final VoidCallback onLoginSuccess;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields.');
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await PocketBaseService().signUp(
        email: email,
        password: password,
        name: name,
      );

      // Ensure the shared PocketBase client is authenticated after signup.
      if (!pb.authStore.isValid) {
        await pb.collection('users').authWithPassword(email, password);
      }

      if (!mounted) return;

      widget.onLoginSuccess();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      debugPrint('Signup error: $e\n$st');

      if (mounted) {
        setState(() => _errorMessage = 'Signup failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Create Account'),
                  ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
