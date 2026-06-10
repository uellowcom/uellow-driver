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
                _contactBtn(Icons.phone_rounded, ar ? 'اتصال' : 'Call',
                    UC.brown, () => _call(o.customerPhone)),
                const SizedBox(width: 8),
                _contactBtn(Icons.whatsapp, 'WhatsApp',
                    const Color(0xFF25D366), () => _wa(o.customerPhone)),
                const SizedBox(width: 8),
                _contactBtn(Icons.sms_rounded, ar ? 'رسالة' : 'SMS',
                    UC.info, () => _sms(o.customerPhone)),
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

  // ── professional contact button (icon over label — always single line) ──
  Widget _contactBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.28), width: 1.2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ]),
      )));
  }

  // ── CTA builders (consistent, single-line, tactile) ──
  Widget _ctaSolid(String label, IconData icon, Color bg, Color fg,
      VoidCallback onTap, {int flex = 1}) {
    return Expanded(flex: flex, child: SizedBox(height: 54, child: ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg, foregroundColor: fg, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      icon: Icon(icon, size: 19),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)))));
  }

  Widget _ctaTint(String label, IconData icon, Color color,
      VoidCallback onTap, {int flex = 1}) {
    return Expanded(flex: flex, child: SizedBox(height: 54, child: TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12), foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      icon: Icon(icon, size: 19),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))));
  }

  Widget _ctaFor(OrderDetail o, bool ar) {
    if (_busy) {
      return const SizedBox(height: 54, child: Center(child: USpinner()));
    }
    switch (o.status) {
      // New assignment — the driver must ACCEPT or REJECT before anything else.
      case 'offered':
      case 'awaiting_pickup':
        return Row(children: [
          _ctaTint(ar ? 'رفض' : 'Reject', Icons.close_rounded, UC.danger,
            () => _doAction(() async =>
                DriverApi.instance.orderReject(o.id, 'Driver rejected'),
              ar ? 'تم الرفض' : 'Rejected')),
          const SizedBox(width: 10),
          _ctaSolid(ar ? 'قبول الطلب' : 'Accept order', Icons.check_circle_rounded,
            UC.success, Colors.white,
            () => _doAction(() async => DriverApi.instance.orderAccept(o.id),
              ar ? 'تم القبول' : 'Accepted'), flex: 2),
        ]);
      // Accepted (with the courier) — next action is to START the delivery.
      case 'accepted':
      case 'picked':
        return Row(children: [
          _ctaSolid(ar ? 'ابدأ التوصيل' : 'Start delivery', Icons.navigation_rounded,
            UC.brown, UC.yellowSoft,
            () => _doAction(() async => DriverApi.instance.orderStart(o.id),
              ar ? 'في الطريق' : 'Started')),
        ]);
      case 'out':
        return Row(children: [
          _ctaTint(ar ? 'فشل' : 'Fail', Icons.report_gmailerrorred_rounded, UC.danger,
            () => Navigator.pushNamed(context, '/fail', arguments: {'id': o.id})),
          const SizedBox(width: 10),
          _ctaSolid(ar ? 'تأكيد التسليم' : 'Confirm delivery',
            Icons.check_circle_rounded, UC.success, Colors.white,
            () => Navigator.pushNamed(context, '/confirm', arguments: {
              'id': o.id, 'cash': o.paymentMethod == 'cod' ? o.amount.amount : 0}),
            flex: 2),
        ]);
      case 'delivered':
        return Container(
          height: 50, alignment: Alignment.center,
          decoration: BoxDecoration(color: UC.successBg,
            borderRadius: BorderRadius.circular(15)),
          child: Text(ar ? '✓ تم التسليم' : '✓ Delivered',
            style: const TextStyle(color: UC.successDk,
              fontWeight: FontWeight.w900, fontSize: 14.5)));
      default:
        return Container(
          height: 50, alignment: Alignment.center,
          decoration: BoxDecoration(color: UC.bg,
            borderRadius: BorderRadius.circular(15)),
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
