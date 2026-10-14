import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
// Verified absolute package imports targeting your exact project workspace
import 'package:waterapp2/services/pocketbase_service.dart'; 
import 'package:waterapp2/create_order_screen.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Water Delivery App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Persistent login token validation check mapping
      home: pb.authStore.isValid ? const HomeScreen() : const LoginScreen(),
    );
  }
}

// --- RESTORED FEATURE: The Master App Dashboard ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // The multi-view layout panel restoring your "Place Order" and "View Orders" features side-by-side
  final List<Widget> _screens = [
    const CreateOrderScreen(), // View Index 0: Places editable orders
    const ViewOrdersListScreen(), // View Index 1: Tracks past delivery history cards
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Fully enabled interactive navigation bar footer item
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index; // Switches views flawlessly without disabling button nodes
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_shopping_cart),
            label: 'Place Order',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'View Orders',
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
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

      if (authData.token.isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid email/password or server connection dropped.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          padding: const EdgeInsets.all(24.0),
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
                decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: const Text('Sign In'),
                    ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// --- FULLY FUNCTIONAL PANEL: Active Order History View ---
class ViewOrdersListScreen extends StatelessWidget {
  const ViewOrdersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              pb.authStore.clear(); // Wipes cached token out of local storage
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: FutureBuilder(
        // Queries your PocketBase 'orders' collection specifically for this user's cards
        future: pb.collection('orders').getFullList(
          filter: 'user_id = "${pb.authStore.model?.id}"',
          sort: '-created',
        ),
        builder: (context, AsyncSnapshot<List<RecordModel>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error rendering data: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No past delivery operations logged yet.'));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final status = order.getStringValue('status').toLowerCase();
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.water_damage, color: Colors.blue),
                  title: Text('Water Jar Quantity: ${order.getIntValue('quantity')}'),
                  subtitle: Text('Delivery Target: ${order.getStringValue('address')}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: status == 'assigned' ? Colors.green.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: status == 'assigned' ? Colors.green.shade800 : Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
