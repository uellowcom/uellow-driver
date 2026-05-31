import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String _status = 'active';
  Future<List<OrderSummary>>? _f;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _reload() {
    setState(() => _f = DriverApi.instance.orders(status: _status, search: _search));
  }

  Color _statusColor(String s) => switch (s) {
    'delivered' => UC.successDk,
    'failed'    => UC.dangerDk,
    'returned'  => UC.muted,
    'awaiting_pickup' => const Color(0xFF92400E),
    'picked' => UC.successDk,
    'out' => UC.successDk,
    _ => UC.muted,
  };

  Color _statusBg(String s) => switch (s) {
    'delivered' => UC.successBg,
    'failed'    => UC.dangerBg,
    'returned'  => UC.bg,
    'awaiting_pickup' => UC.warnBg,
    'picked' => UC.successBg,
    'out' => UC.successBg,
    _ => UC.bg,
  };

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'طلباتي' : 'My Orders'),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(96),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) { _search = v; _reload(); },
                decoration: InputDecoration(
                  hintText: ar ? 'بحث برقم الطلب أو اسم العميل…'
                              : 'Search by order # or customer…',
                  prefixIcon: const Icon(Icons.search, size: 18)))),
            SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _tab('active',   ar ? 'نشطة'   : 'Active'),
                _tab('done',     ar ? 'منجزة'  : 'Done'),
                _tab('failed',   ar ? 'فاشلة' : 'Failed'),
                _tab('returned', ar ? 'مرتجع' : 'Returned'),
              ])),
          ])),
      ),
      body: RefreshIndicator(onRefresh: () async { _reload(); await _f; },
        child: FutureBuilder<List<OrderSummary>>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
        final rows = snap.data ?? const <OrderSummary>[];
        if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(40),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: UC.muted),
            const SizedBox(height: 12),
            Text(ar ? 'لا توجد طلبات هنا' : 'No orders here', style: UT.body),
          ])));
        return ListView.separated(padding: const EdgeInsets.all(10),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _card(rows[i], ar));
      })),
    );
  }

  Widget _tab(String key, String label) {
    final on = _status == key;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(onTap: () { _status = key; _reload(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: on ? UC.yellow : Colors.white,
            border: Border.all(color: on ? UC.yellow : UC.border, width: 1.5),
            borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: TextStyle(
            color: on ? UC.brown : UC.text, fontWeight: FontWeight.w900,
            fontSize: 12.5)))));
  }

  Widget _card(OrderSummary o, bool ar) {
    final lang = ar ? 'ar' : 'en';
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(context, '/order', arguments: {'id': o.id}),
        child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: UC.border),
            borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(o.name, style: const TextStyle(fontFamily: 'monospace',
                fontSize: 12.5, fontWeight: FontWeight.w900, color: UC.ink)),
              const Spacer(),
              UPill(text: o.statusLabel.t(lang),
                bg: _statusBg(o.status), fg: _statusColor(o.status)),
            ]),
            const SizedBox(height: 4),
            Text(o.customer, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w800, color: UC.ink)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on, size: 12, color: UC.muted),
              const SizedBox(width: 3),
              Expanded(child: Text(o.addrShort, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: UC.muted))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Text(o.amount.format(lang), style: const TextStyle(fontSize: 14.5,
                fontWeight: FontWeight.w900, color: UC.brown)),
              UPill(text: o.paymentMethod.toUpperCase(),
                bg: o.paymentMethod == 'cod' ? UC.warnBg : UC.successBg,
                fg: o.paymentMethod == 'cod' ? const Color(0xFF92400E) : UC.successDk),
              if (o.itemCount > 0) UPill(text: ar ? '${o.itemCount} عناصر' : '${o.itemCount} items'),
            ]),
          ]))));
  }
}
