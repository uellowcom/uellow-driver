import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Future<OrderDetail>? _f;
  bool _busy = false;
  @override
  void initState() { super.initState(); _f = DriverApi.instance.orderDetail(widget.orderId); }

  Future<void> _refresh() async {
    setState(() => _f = DriverApi.instance.orderDetail(widget.orderId));
    await _f;
  }

  Future<void> _doAction(Future<void> Function() fn, String okMsg) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'),
        mode: LaunchMode.externalApplication);
  }
  Future<void> _wa(String phone) async {
    if (phone.isEmpty) return;
    final p = phone.replaceAll(RegExp(r'[^0-9]'), '');
    await launchUrl(Uri.parse('https://wa.me/$p'),
        mode: LaunchMode.externalApplication);
  }
  Future<void> _sms(String phone) async {
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('sms:$phone'),
        mode: LaunchMode.externalApplication);
  }
  Future<void> _maps(double lat, double lng) async {
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.orderId}')),
      body: FutureBuilder<OrderDetail>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: USpinner());
        }
        if (snap.hasError) {
          return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
        }
        final o = snap.data!;
        return RefreshIndicator(onRefresh: _refresh,
          child: ListView(padding: EdgeInsets.zero, children: [
            // Status pill
            Container(padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              color: Colors.white, width: double.infinity,
              child: Row(children: [
                UPill(text: o.statusLabel.t(lang), bg: UC.successBg, fg: UC.successDk, live: true),
                const Spacer(),
                Text(o.name, style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.w900,
                  color: UC.muted, fontSize: 12)),
              ])),
            // Customer
            _section(title: ar ? 'العميل' : 'Customer', child: Column(children: [
              _row(Icons.person_outline, o.customer, o.customerPhone),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _call(o.customerPhone),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text(ar ? 'اتصال' : 'Call'))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _wa(o.customerPhone),
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('WhatsApp'))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _sms(o.customerPhone),
                  icon: const Icon(Icons.sms, size: 16),
                  label: Text(ar ? 'رسالة' : 'SMS'))),
              ]),
            ])),
            // Address
            _section(title: ar ? 'عنوان التسليم' : 'Deliver to', child: Column(children: [
              _row(Icons.location_on, '${o.addrCity}${o.addrCity.isNotEmpty ? ", " : ""}'
                  '${o.addrStreet}', o.addrStreet2.isEmpty ? o.addrCountry : o.addrStreet2),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => _maps(o.addrLat, o.addrLng),
                icon: const Icon(Icons.map_outlined, size: 16),
                label: Text(ar ? 'افتح في الخرائط' : 'Open in Maps'))),
            ])),
            // Items
            if (o.items.isNotEmpty) _section(
              title: ar ? 'العناصر (${o.items.length})' : 'Items (${o.items.length})',
              child: Column(children: [
                for (final it in o.items) Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: UC.bg))),
                  child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: '${DriverApi.instance.baseUrl}${it.imageUrl}',
                        width: 46, height: 46, fit: BoxFit.cover,
                        errorWidget: (_,__,___) => Container(width: 46, height: 46,
                          color: UC.bg, child: const Icon(Icons.image, color: UC.muted)))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.name.t(lang), maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                        Text(it.subtotal.format(lang), style: UT.small),
                      ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: UC.yellowFaint,
                        borderRadius: BorderRadius.circular(7)),
                      child: Text('×${it.qty.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                          color: UC.brown))),
                  ])),
              ])),
            // Payment
            _section(title: ar ? 'الدفع' : 'Payment', child: _row(
              o.paymentMethod == 'cod' ? Icons.payments_outlined : Icons.credit_card,
              o.paymentMethod == 'cod'
                ? (ar ? 'الدفع عند الاستلام' : 'Cash on Delivery')
                : (ar ? 'مدفوع مسبقاً' : 'Pre-paid'),
              ar ? 'الإجمالي: ${o.amount.format(lang)}'
                  : 'Total: ${o.amount.format(lang)}')),
            // Quick actions
            _section(title: ar ? 'إجراءات سريعة' : 'Quick actions', child: GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.4,
              children: [
                if (DriverApi.instance.driver?.canSendPaymentLink == true)
                  _quick(Icons.credit_card, ar ? 'إرسال رابط دفع' : 'Send payment link',
                    () => Navigator.pushNamed(context, '/paylink', arguments: {
                      'id': o.id, 'name': o.name, 'amount': o.amount.amount,
                      'phone': o.customerPhone,
                    })),
                _quick(Icons.navigation, ar ? 'انتقال' : 'Navigate',
                  () => _maps(o.addrLat, o.addrLng)),
                _quick(Icons.support_agent, ar ? 'اتصل بالعمليات' : 'Call ops',
                  () { /* TODO */ }),
                _quick(Icons.refresh, ar ? 'تحديث' : 'Refresh', _refresh),
              ])),
            // Timeline
            if (o.timeline.isNotEmpty) _section(
              title: ar ? 'حالة الطلب' : 'Status timeline',
              child: Column(children: [
                for (var i = 0; i < o.timeline.length; i++) Row(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 24, height: 24, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i < o.timeline.length - 1 || o.status != o.timeline[i].code
                        ? UC.success : UC.yellow,
                      shape: BoxShape.circle),
                    child: Icon(Icons.check, color: Colors.white, size: 14)),
                  const SizedBox(width: 10),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.timeline[i].label.t(lang),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      Text(o.timeline[i].when.split('T').first, style: UT.small),
                    ]))),
                ]),
              ])),
            const SizedBox(height: 120),
          ]));
      }),
      bottomNavigationBar: FutureBuilder<OrderDetail>(future: _f, builder: (_, snap) {
        if (snap.data == null) return const SizedBox.shrink();
        final o = snap.data!;
        return SafeArea(top: false, child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: UC.border)),
            boxShadow: [BoxShadow(color: Color(0x14000000),
              blurRadius: 8, offset: Offset(0, -2))]),
          child: _ctaFor(o, ar),
        ));
      }),
    );
  }

  Widget _ctaFor(OrderDetail o, bool ar) {
    if (_busy) return const Center(child: USpinner());
    switch (o.status) {
      // New assignment — the driver must ACCEPT or REJECT before anything else.
      case 'offered':
      case 'awaiting_pickup':
        return Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => _doAction(() async => DriverApi.instance.orderReject(o.id, 'Driver rejected'),
              ar ? 'تم الرفض' : 'Rejected'),
            child: Text(ar ? 'رفض' : 'Reject',
              style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: () => _doAction(() async => DriverApi.instance.orderAccept(o.id),
              ar ? 'تم القبول' : 'Accepted'),
            style: ElevatedButton.styleFrom(
              backgroundColor: UC.success, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: Text(ar ? 'قبول الطلب' : 'Accept',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))),
        ]);
      // Accepted (with the courier) — next action is to START the delivery,
      // which turns on live tracking for the customer.
      case 'accepted':
      case 'picked':
        return SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () => _doAction(() async => DriverApi.instance.orderStart(o.id),
            ar ? 'في الطريق' : 'Started'),
          style: ElevatedButton.styleFrom(
            backgroundColor: UC.brown, foregroundColor: UC.yellowSoft,
            padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text(ar ? 'ابدأ التوصيل' : 'Start delivery',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))));
      case 'out':
        return Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/fail', arguments: {'id': o.id}),
            child: Text(ar ? 'فشل' : 'Fail',
              style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/confirm',
              arguments: {'id': o.id, 'cash': o.paymentMethod == 'cod' ? o.amount.amount : 0}),
            style: ElevatedButton.styleFrom(
              backgroundColor: UC.success, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.check, size: 16),
            label: Text(ar ? 'تأكيد التسليم' : 'Confirm delivery',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))),
        ]);
      case 'delivered':
        return Container(
          padding: const EdgeInsets.all(12), alignment: Alignment.center,
          decoration: BoxDecoration(color: UC.successBg,
            borderRadius: BorderRadius.circular(12)),
          child: Text(ar ? '✓ تم التسليم' : '✓ Delivered',
            style: const TextStyle(color: UC.successDk, fontWeight: FontWeight.w900)));
      default:
        return Container(
          padding: const EdgeInsets.all(12), alignment: Alignment.center,
          decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(12)),
          child: Text(o.statusLabel.t(ar ? 'ar' : 'en'),
            style: const TextStyle(fontWeight: FontWeight.w900)));
    }
  }

  Widget _section({required String title, required Widget child}) {
    return Container(margin: const EdgeInsets.only(top: 8), color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 10.5,
          fontWeight: FontWeight.w800, color: UC.muted, letterSpacing: .4)),
        const SizedBox(height: 8),
        child,
      ]));
  }
  Widget _row(IconData ic, String a, String b) {
    return Row(children: [
      Container(width: 32, height: 32, alignment: Alignment.center,
        decoration: BoxDecoration(color: UC.yellowFaint,
          borderRadius: BorderRadius.circular(9)),
        child: Icon(ic, color: UC.brown, size: 16)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        Text(b, style: UT.small),
      ])),
    ]);
  }
  Widget _quick(IconData ic, String label, VoidCallback onTap) {
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(11),
      child: InkWell(borderRadius: BorderRadius.circular(11), onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: UC.border),
            borderRadius: BorderRadius.circular(11)),
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, color: UC.brown, size: 20),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                color: UC.brown), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]))));
  }
}
