import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Gateway address, e.g.: flutter run --dart-define=API_BASE=http://10.0.2.2:8080
const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8080');

void main() => runApp(const ShopApp());

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ShopMini',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const LoginPage(),
      );
}

/// Tiny API helper. The token lives in memory only (use flutter_secure_storage in a real app).
class Api {
  static String? token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<http.Response> post(String path, Map<String, dynamic> body) => http
      .post(Uri.parse('$apiBase$path'), headers: _headers, body: jsonEncode(body))
      .timeout(const Duration(seconds: 10));

  static Future<http.Response> get(String path) =>
      http.get(Uri.parse('$apiBase$path'), headers: _headers).timeout(const Duration(seconds: 10));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  String? message;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit(bool register) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final creds = {'email': email.text.trim(), 'password': password.text};
      if (register) {
        final r = await Api.post('/api/auth/register', creds);
        if (r.statusCode != 201) {
          setState(() => message = 'Register failed (${r.statusCode})');
          return;
        }
      }
      final r = await Api.post('/api/auth/login', creds);
      if (r.statusCode != 200) {
        setState(() => message = 'Login failed (${r.statusCode})');
        return;
      }
      Api.token = jsonDecode(r.body)['token'] as String;
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const ProductsPage()));
    } catch (_) {
      if (mounted) setState(() => message = 'Cannot reach the server');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ShopMini')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress),
            TextField(
                controller: password,
                decoration: const InputDecoration(labelText: 'Password (min 8 characters)'),
                obscureText: true),
            const SizedBox(height: 16),
            if (message != null) Text(message!, style: const TextStyle(color: Colors.red)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(
                  onPressed: busy ? null : () => submit(false), child: const Text('Login')),
              OutlinedButton(
                  onPressed: busy ? null : () => submit(true),
                  child: const Text('Register + login')),
            ]),
          ]),
        ),
      );
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late final Future<List<dynamic>> products = load();
  final Map<int, int> cart = {};
  String? message;

  Future<List<dynamic>> load() async {
    final r = await Api.get('/api/catalogue/products');
    if (r.statusCode != 200) throw Exception('status ${r.statusCode}');
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<void> checkout() async {
    final items =
        cart.entries.map((e) => {'productId': e.key, 'quantity': e.value}).toList();
    try {
      final r = await Api.post('/api/checkout/orders', {'items': items});
      if (!mounted) return;
      if (r.statusCode == 201) {
        final id = jsonDecode(r.body)['orderId'];
        setState(() {
          cart.clear();
          message = 'Order #$id placed';
        });
      } else {
        setState(() => message = 'Order failed (${r.statusCode})');
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Cannot reach the server');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Products')),
        body: Column(children: [
          if (message != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(message!)),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: products,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) return const Center(child: Text('Could not load products'));
                final list = snap.data!;
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i] as Map<String, dynamic>;
                    final id = p['id'] as int;
                    return ListTile(
                      title: Text('${p['name']}'),
                      subtitle: Text('Rs ${p['price']}  (in cart: ${cart[id] ?? 0})'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        onPressed: () => setState(() => cart[id] = (cart[id] ?? 0) + 1),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
              onPressed: cart.isEmpty ? null : checkout, child: const Text('Checkout')),
        ),
      );
}
