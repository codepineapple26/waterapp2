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
  Map<String, dynamic>? _reorderDraft;

  late Future<List<dynamic>> _ordersFuture;

  bool get _isDriver =>
      pb.authStore.model?.getStringValue('role') == 'driver';

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<dynamic>> _loadOrders() {
    final userId = pb.authStore.model?.id;

    if (userId == null || userId.isEmpty) {
      return Future.error(StateError('No authenticated user.'));
    }

    final filter = _isDriver
        ? 'driver_id = "$userId"'
        : 'user_id = "$userId"';

    return pb.collection('orders').getFullList(
          filter: filter,
          sort: '-created',
        );
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = _loadOrders();
      _ordersVersion++;
    });
  }

  void _openOrderForm({Map<String, dynamic>? draft}) {
    setState(() {
      _reorderDraft = draft;
      _showOrderForm = true;
    });
  }

  void _handleReorder(Map<String, dynamic> draft) {
    if (_isDriver) return;
    _openOrderForm(draft: draft);
  }

  String _orderStatus(dynamic order) {
    final data = order.data as Map<String, dynamic>;
    return (data['status'] ?? data['order_status'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
  }

  double _numberFromOrder(dynamic order, List<String> fieldNames) {
    final data = order.data as Map<String, dynamic>;

    for (final field in fieldNames) {
      final value = data[field];

      if (value is num) {
        return value.toDouble();
      }

      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }

    return 0;
  }

  double _amountPaid(dynamic order) {
    final data = order.data as Map<String, dynamic>;

    // Use an explicit paid amount when the collection has one.
    for (final field in ['amount_paid', 'paid_amount']) {
      final value = data[field];

      if (value is num) {
        return value.toDouble();
      }

      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }

    // Otherwise count the order total only when marked as paid.
    final paymentStatus =
        (data['payment_status'] ?? '').toString().toLowerCase().trim();

    if (paymentStatus == 'paid') {
      return _numberFromOrder(
        order,
        ['total_amount', 'total_price', 'amount', 'price'],
      );
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isDriver) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          actions: [
            IconButton(
              tooltip: 'Refresh orders',
              onPressed: _refreshOrders,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ViewOrdersListScreen(
          key: ValueKey('driver-orders-$_ordersVersion'),
          onReorder: _handleReorder,
        ),
      );
    }

    if (_showOrderForm) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Place Order'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _showOrderForm = false;
                _reorderDraft = null;
                _ordersFuture = _loadOrders();
              });
            },
          ),
        ),
        body: CreateOrderScreen(
          key: ValueKey('create-order-$_ordersVersion'),
          allowSubmit: true,
          initialValues: _reorderDraft ?? const {},
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Dashboard' : 'My Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
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

            if (index == 1) {
              _ordersFuture = _loadOrders();
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

  Widget _buildDashboard() {
    return FutureBuilder<List<dynamic>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load your dashboard: ${snapshot.error}'),
            ),
          );
        }

        final orders = snapshot.data ?? [];

        final deliveredCount = orders
            .where((order) => _orderStatus(order) == 'delivered')
            .length;

        // All non-delivered, non-cancelled orders are counted as pending.
        final pendingCount = orders.where((order) {
          final status = _orderStatus(order);
          return status != 'delivered' &&
              status != 'cancelled' &&
              status != 'canceled';
        }).length;

        final totalPaid = orders.fold<double>(
          0,
          (sum, order) => sum + _amountPaid(order),
        );

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Welcome',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _MetricCard(
                  title: 'Total orders',
                  value: '${orders.length}',
                  icon: Icons.receipt_long_outlined,
                ),
                _MetricCard(
                  title: 'Delivered',
                  value: '$deliveredCount',
                  icon: Icons.check_circle_outline,
                ),
                _MetricCard(
                  title: 'Pending',
                  value: '$pendingCount',
                  icon: Icons.pending_outlined,
                ),
                _MetricCard(
                  title: 'Total amount paid',
                  value: totalPaid.toStringAsFixed(2),
                  icon: Icons.payments_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 1;
                        _ordersVersion++;
                      });
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('My Orders'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openOrderForm(),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Place Order'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
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
              const Icon(
                Icons.water_drop,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Water Delivery Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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

      // Authenticate with the shared PocketBase client after signup.
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
