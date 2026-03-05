import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'checkout_page.dart';

class ProductSelectionPage extends StatefulWidget {
  const ProductSelectionPage({super.key});
  @override
  State<ProductSelectionPage> createState() => _ProductSelectionPageState();
}

class _ProductSelectionPageState extends State<ProductSelectionPage> {
  List<Map<String, dynamic>> _products = [];
  final Map<int, int> _qty = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await DatabaseHelper.instance
          .getProducts()
          .timeout(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = [];
        _loading = false;
      });
    }
  }

  double get _total {
    double t = 0;
    for (final p in _products) {
      final id = p['id'] as int;
      final price = (p['price'] as num).toDouble();
      final q = _qty[id] ?? 0;
      t += price * q;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF6C63FF);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Choose products'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final p = _products[i];
                        final id = p['id'] as int;
                        final name = p['name'] as String;
                        final price = (p['price'] as num).toDouble();
                        final q = _qty[id] ?? 0;
                        IconData icon;
                        if (name.toLowerCase().contains('sneakers')) {
                          icon = Icons.hiking;
                        } else if (name.toLowerCase().contains('jacket')) {
                          icon = Icons.checkroom;
                        } else {
                          icon = Icons.shopping_bag;
                        }
                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Icon(icon, color: color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                      Text('\$${price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              color: Colors.blue)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                        onPressed: () => setState(() =>
                                            _qty[id] = (q > 0 ? q - 1 : 0)),
                                        icon: const Icon(
                                            Icons.remove_circle_outline)),
                                    Text(q.toString(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    IconButton(
                                        onPressed: () =>
                                            setState(() => _qty[id] = q + 1),
                                        icon: const Icon(
                                            Icons.add_circle_outline)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Total: \$${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                      const Spacer(),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          onPressed: _total <= 0
                              ? null
                              : () async {
                                  final items = <Map<String, int>>[];
                                  _qty.forEach((pid, q) {
                                    if (q > 0)
                                      items.add({'product_id': pid, 'qty': q});
                                  });
                                  await DatabaseHelper.instance
                                      .setCartItems(items);
                                  if (mounted) {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const CheckoutPage()));
                                  }
                                },
                          child: const Text('Proceed to checkout'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
