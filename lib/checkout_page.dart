import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database_helper.dart';
import 'confirm_page.dart';

class PaymentData {
  final String method;
  final String cardNumber;
  final int expMonth;
  final int expYear;
  final String cvv;
  final String holder;
  final bool saveCard;
  PaymentData({
    required this.method,
    required this.cardNumber,
    required this.expMonth,
    required this.expYear,
    required this.cvv,
    required this.holder,
    required this.saveCard,
  });
}

class Expiry {
  final int month;
  final int year;
  const Expiry(this.month, this.year);
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  bool _saveCard = true;
  String _method = 'Credit';
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _loadTotal();
  }

  Future<void> _loadTotal() async {
    final t = await DatabaseHelper.instance.getCartTotal();
    setState(() {
      _total = t;
    });
  }

  String _formatCard(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  void _onCardChanged(String value) {
    final formatted = _formatCard(value);
    if (formatted != value) {
      final pos = _cardCtrl.selection.baseOffset;
      _cardCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(
            offset: pos + (formatted.length - value.length)),
      );
    }
  }

  Widget _brandBadge(String digits) {
    if (digits.startsWith('5')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                      color: Color(0xFFF79E1B), shape: BoxShape.circle))),
        ],
      );
    }
    if (digits.startsWith('4')) {
      return const Text('VISA',
          style:
              TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1F71)));
    }
    if (digits.startsWith('3')) {
      return const Text('AMEX',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal));
    }
    return const Icon(Icons.credit_card, size: 18);
  }

  Expiry? _parseExpiryFlexible(String input) {
    final raw = input.trim();
    final parts =
        raw.split(RegExp(r'[/\-]')).where((e) => e.isNotEmpty).toList();
    int? mm;
    int? yy;
    if (parts.length == 2) {
      final a = parts[0];
      final b = parts[1];
      if (a.length == 4) {
        final year4 = int.tryParse(a);
        final month = int.tryParse(b);
        if (year4 != null && month != null) {
          mm = month;
          yy = year4 % 100;
        }
      } else if (b.length == 4) {
        final month = int.tryParse(a);
        final year4 = int.tryParse(b);
        if (month != null && year4 != null) {
          mm = month;
          yy = year4 % 100;
        }
      } else {
        final month = int.tryParse(a);
        final year2 = int.tryParse(b);
        if (month != null && year2 != null) {
          mm = month;
          yy = year2;
        }
      }
    } else {
      final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 4) {
        mm = int.tryParse(digits.substring(0, 2));
        yy = int.tryParse(digits.substring(2, 4));
      }
    }
    if (mm == null || yy == null) return null;
    if (mm < 1 || mm > 12) return null;
    final nowY = DateTime.now().year % 100;
    if (yy < nowY) return const Expiry(0, 0); // señal de año pasado
    return Expiry(mm, yy);
  }

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF6C63FF);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Payment data'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\$${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            const SizedBox(height: 12),
            const Text('Payment Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                    label: const Row(children: [
                      Icon(Icons.account_balance, size: 18),
                      SizedBox(width: 6),
                      Text('PayPal')
                    ]),
                    selected: _method == 'PayPal',
                    onSelected: (v) => setState(() => _method = 'PayPal'),
                    selectedColor: color.withOpacity(0.15)),
                ChoiceChip(
                    label: const Row(children: [
                      Icon(Icons.credit_card, size: 18),
                      SizedBox(width: 6),
                      Text('Credit')
                    ]),
                    selected: _method == 'Credit',
                    onSelected: (v) => setState(() => _method = 'Credit'),
                    selectedColor: color.withOpacity(0.15)),
                ChoiceChip(
                    label: const Row(children: [
                      Icon(Icons.account_balance_wallet, size: 18),
                      SizedBox(width: 6),
                      Text('Wallet')
                    ]),
                    selected: _method == 'Wallet',
                    onSelected: (v) => setState(() => _method = 'Wallet'),
                    selectedColor: color.withOpacity(0.15)),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _cardCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.credit_card),
                            labelText: 'Card number',
                            hintText: '1234 5678 9012 3456',
                            border: const OutlineInputBorder(),
                            suffixIcon: Padding(
                                padding: const EdgeInsets.all(10),
                                child: _brandBadge(_cardCtrl.text
                                    .replaceAll(RegExp(r'[^0-9]'), '')))),
                        onChanged: (v) {
                          _onCardChanged(v);
                          setState(() {});
                        },
                        validator: (v) {
                          final d = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                          if (d.length < 13) return 'Invalid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Valid until',
                            style: TextStyle(color: Colors.grey.shade700)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiryCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  hintText: 'MM/YY',
                                  border: OutlineInputBorder()),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9/\\-]'))
                              ],
                              validator: (v) {
                                final parsed = _parseExpiryFlexible(v ?? '');
                                if (parsed == null)
                                  return 'Valid format: MM/YY or YYYY/MM';
                                if (parsed.month == 0 && parsed.year == 0)
                                  return 'Expired date';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cvvCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'CVV',
                                  border: OutlineInputBorder()),
                              validator: (v) {
                                final c = v ?? '';
                                if (c.length < 3) return 'Invalid CVV';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _holderCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Card holder',
                            border: OutlineInputBorder()),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Save card data for future payments'),
                          const Spacer(),
                          Switch(
                            value: _saveCard,
                            onChanged: (v) => setState(() => _saveCard = v),
                            thumbColor:
                                MaterialStateProperty.resolveWith((_) => color),
                            trackColor: MaterialStateProperty.resolveWith(
                                (_) => color.withOpacity(0.6)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            if (_formKey.currentState?.validate() != true)
                              return;
                            final parsed =
                                _parseExpiryFlexible(_expiryCtrl.text.trim());
                            final expMonth = parsed?.month ?? 1;
                            final expYear =
                                parsed?.year ?? (DateTime.now().year % 100);
                            final data = PaymentData(
                              method: _method,
                              cardNumber: _cardCtrl.text,
                              expMonth: expMonth,
                              expYear: expYear,
                              cvv: _cvvCtrl.text,
                              holder: _holderCtrl.text,
                              saveCard: _saveCard,
                            );
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    ConfirmPage(total: _total, data: data)));
                          },
                          child: const Text('Proceed to confirm'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
