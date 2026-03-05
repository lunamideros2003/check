import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'checkout_page.dart';

class ConfirmPage extends StatefulWidget {
  final double total;
  final PaymentData data;
  const ConfirmPage({super.key, required this.total, required this.data});
  @override
  State<ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<ConfirmPage> {
  final _promoCtrl = TextEditingController();
  bool _processing = false;

  Future<void> _pay() async {
    setState(() {
      _processing = true;
    });
    final digits = widget.data.cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last4 =
        digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    final brand = _brandFromNumber(digits);
    int? cardId;
    if (widget.data.saveCard) {
      cardId = await DatabaseHelper.instance.saveCard(
        holder: widget.data.holder,
        brand: brand,
        last4: last4,
        expMonth: widget.data.expMonth,
        expYear: widget.data.expYear,
      );
    }
    await DatabaseHelper.instance.createOrderWithPayment(
      amount: widget.total,
      method: widget.data.method,
      cardId: cardId,
      promoCode: _promoCtrl.text.isEmpty ? null : _promoCtrl.text,
    );
    setState(() {
      _processing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Payment completed')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String _brandFromNumber(String digits) {
    if (digits.startsWith('4')) return 'Visa';
    if (digits.startsWith('5')) return 'Mastercard';
    if (digits.startsWith('3')) return 'Amex';
    return 'Card';
  }

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF6C63FF);
    final cardPreview = Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\$50 off',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('on your first order',
              style: TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(widget.data.holder, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop()),
        centerTitle: true,
        title: const Text('Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cardPreview,
            const SizedBox(height: 6),
            const Text('Promo code valid for orders over \$150.',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                    child: Text('Payment information',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600))),
                TextButton(onPressed: () {}, child: const Text('Edit')),
              ],
            ),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final digits =
                  widget.data.cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
              final brand = _brandFromNumber(digits);
              final ending =
                  digits.isNotEmpty ? digits.substring(digits.length - 2) : '';
              Widget badge;
              if (digits.startsWith('5')) {
                badge = Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                          color: Color(0xFFEB001B), shape: BoxShape.circle)),
                  Transform.translate(
                      offset: const Offset(-6, 0),
                      child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                              color: Color(0xFFF79E1B),
                              shape: BoxShape.circle))),
                ]);
              } else if (digits.startsWith('4')) {
                badge = const Text('VISA',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF1A1F71)));
              } else if (digits.startsWith('3')) {
                badge = const Text('AMEX',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.teal));
              } else {
                badge = const Icon(Icons.credit_card,
                    size: 18, color: Colors.orange);
              }
              return Row(
                children: [
                  badge,
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Card holder\n$brand ending **$ending',
                          style: const TextStyle(fontSize: 14))),
                ],
              );
            }),
            const SizedBox(height: 16),
            const Text('Use promo code'),
            const SizedBox(height: 8),
            TextField(
              controller: _promoCtrl,
              decoration: const InputDecoration(
                  hintText: 'PROMO20-08', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: _processing ? null : _pay,
                child: _processing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Pay'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
