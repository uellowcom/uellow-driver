import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class FailScreen extends StatefulWidget {
  const FailScreen({super.key, required this.orderId});
  final int orderId;
  @override
  State<FailScreen> createState() => _FailScreenState();
}

class _FailScreenState extends State<FailScreen> {
  String _reason = 'unreachable';
  bool _returnToWh = true;
  final _details = TextEditingController();
  bool _busy = false;
  String? _err;
  @override
  void dispose() { _details.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final ar = DriverApi.instance.lang == 'ar';
    final reasonText = _reasons(ar).firstWhere((r) => r.$1 == _reason).$2;
    setState(() { _busy = true; _err = null; });
    try {
      await DriverApi.instance.orderFail(widget.orderId,
        reason: reasonText, details: _details.text.trim(),
        returnToUellow: _returnToWh);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم تسجيل الفشل' : 'Failure recorded')));
    } catch (e) {
      setState(() { _busy = false; _err = e.toString(); });
    }
  }

  List<(String, String)> _reasons(bool ar) => ar ? const [
    ('unreachable', 'العميل غير متاح'),
    ('wrong_addr',  'عنوان خاطئ أو ناقص'),
    ('refused',     'رفض العميل'),
    ('damaged',     'تالف عند الفحص'),
    ('other',       'سبب آخر'),
  ] : const [
    ('unreachable', 'Customer not reachable'),
    ('wrong_addr',  'Wrong / incomplete address'),
    ('refused',     'Customer refused'),
    ('damaged',     'Damaged on inspection'),
    ('other',       'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'تسجيل فشل التسليم' : 'Mark as failed')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Text(ar ? 'ما سبب الفشل؟' : 'Why did delivery fail?', style: UT.h2),
        const SizedBox(height: 10),
        for (final r in _reasons(ar))
          GestureDetector(onTap: () => setState(() => _reason = r.$1),
            child: Container(margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _reason == r.$1 ? UC.yellowFaint : Colors.white,
                border: Border.all(color: _reason == r.$1 ? UC.yellow : UC.border, width: 1.5),
                borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                Container(width: 18, height: 18,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _reason == r.$1 ? UC.yellow : Colors.transparent,
                    border: Border.all(color: _reason == r.$1 ? UC.yellow : UC.border, width: 2)),
                  child: _reason == r.$1
                    ? Container(margin: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.white,
                          shape: BoxShape.circle))
                    : null),
                const SizedBox(width: 10),
                Expanded(child: Text(r.$2, style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13))),
              ]))),
        const SizedBox(height: 14),
        TextField(controller: _details, minLines: 2, maxLines: 4,
          decoration: InputDecoration(
            hintText: ar ? 'تفاصيل إضافية للعمليات…' : 'Extra details for ops…')),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: UC.border),
            borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Switch(value: _returnToWh,
              onChanged: (v) => setState(() => _returnToWh = v),
              activeColor: UC.yellow),
            Expanded(child: Text(ar ? 'إرجاع الطرد لمخزن Uellow'
                                    : 'Return parcel to Uellow warehouse',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
          ])),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Text(_err!, style: const TextStyle(color: UC.dangerDk))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: UC.danger, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15)),
          icon: _busy
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.warning_amber, size: 18),
          label: Text(ar ? 'إرسال الفشل' : 'Submit failure',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)))),
      ]),
    );
  }
}
