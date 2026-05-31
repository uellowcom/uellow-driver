import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});
  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  Future<CashReady>? _f;
  final Set<int> _selected = {};
  final _ref = TextEditingController();
  bool _busy = false;
  @override
  void initState() { super.initState(); _f = DriverApi.instance.cashReady(); }
  @override
  void dispose() { _ref.dispose(); super.dispose(); }

  Future<void> _refresh() async {
    setState(() {
      _f = DriverApi.instance.cashReady();
      _selected.clear();
    });
    await _f;
  }

  double _totalSelected(CashReady r) {
    double total = 0;
    for (final it in r.items) {
      if (_selected.contains(it.orderId)) total += it.amount.amount;
    }
    return total;
  }

  Future<void> _submit() async {
    final ar = DriverApi.instance.lang == 'ar';
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'اختر طلباً واحداً على الأقل' : 'Select at least one order')));
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await DriverApi.instance.cashSubmit(_selected.toList(), _ref.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar
          ? 'تم إرسال التسوية ${res['reference'] ?? ''}'
          : 'Remittance ${res['reference'] ?? ''} submitted')));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'تسوية النقد' : 'Cash to settle'),
        actions: [
          IconButton(icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/cash-history')),
        ]),
      body: FutureBuilder<CashReady>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (snap.hasError) return Center(child: Text(snap.error.toString(), style: UT.body));
        final r = snap.data!;
        if (r.items.isEmpty) {
          return Padding(padding: const EdgeInsets.all(40),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.payments_outlined, size: 48, color: UC.muted),
              const SizedBox(height: 12),
              Text(ar ? 'لا يوجد نقد للتسوية الآن' : 'Nothing to settle right now',
                style: UT.body, textAlign: TextAlign.center),
            ])));
        }
        return ListView(padding: EdgeInsets.zero, children: [
          Container(margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [UC.brown, UC.brownSoft]),
              borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ar ? 'إجمالي المحدد' : 'Total selected',
                style: const TextStyle(color: Color(0xFFFFE066), fontSize: 11,
                  fontWeight: FontWeight.w800, letterSpacing: .4)),
              const SizedBox(height: 4),
              Text('${_totalSelected(r).toStringAsFixed(3)} KD',
                style: const TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(ar ? 'من إجمالي ${r.total.format(lang)} متاح'
                      : 'of ${r.total.format(lang)} available',
                style: const TextStyle(color: Color(0xCCFFE066), fontSize: 11)),
            ])),
          for (final it in r.items) Container(
            color: Colors.white,
            child: InkWell(
              onTap: () => setState(() {
                if (_selected.contains(it.orderId)) _selected.remove(it.orderId);
                else _selected.add(it.orderId);
              }),
              child: Container(padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: UC.bg))),
                child: Row(children: [
                  Container(width: 22, height: 22, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selected.contains(it.orderId) ? UC.success : Colors.transparent,
                      border: Border.all(color: _selected.contains(it.orderId)
                        ? UC.success : UC.border, width: 2),
                      borderRadius: BorderRadius.circular(6)),
                    child: _selected.contains(it.orderId)
                      ? const Icon(Icons.check, size: 14, color: Colors.white) : null),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${it.orderName} · ${it.customer}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    Text('${it.when.split("T").first} · ${it.addrShort}',
                      style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  Text(it.amount.format(lang),
                    style: const TextStyle(fontFamily: 'monospace',
                      fontSize: 13, fontWeight: FontWeight.w900, color: UC.brown)),
                ])))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(controller: _ref,
              decoration: InputDecoration(
                labelText: ar ? 'مرجع التسوية (اختياري)' : 'Reference (optional)',
                hintText: 'SLP-2026-…'))),
          const SizedBox(height: 80),
        ]);
      }),
      bottomNavigationBar: SafeArea(top: false, child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(color: Colors.white,
          border: Border(top: BorderSide(color: UC.border))),
        child: Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () async {
              final r = await _f;
              if (r == null) return;
              setState(() {
                if (_selected.length == r.items.length) _selected.clear();
                else _selected..clear()..addAll(r.items.map((i) => i.orderId));
              });
            },
            child: Text(DriverApi.instance.lang == 'ar' ? 'تحديد الكل' : 'Select all'))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13)),
            icon: _busy
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
              : const Icon(Icons.send, size: 16),
            label: Text(DriverApi.instance.lang == 'ar' ? 'إرسال التسوية' : 'Submit',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))),
        ]))),
    );
  }
}
