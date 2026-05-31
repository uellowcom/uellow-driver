import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class PaylinkScreen extends StatefulWidget {
  const PaylinkScreen({super.key, required this.orderId, required this.orderName,
      required this.defaultAmount, required this.customerPhone});
  final int orderId;
  final String orderName;
  final double defaultAmount;
  final String customerPhone;
  @override
  State<PaylinkScreen> createState() => _PaylinkScreenState();
}

class _PaylinkScreenState extends State<PaylinkScreen> {
  String _provider = 'upayments';
  late final TextEditingController _amount;
  PayLink? _link;
  PayStatus? _status;
  bool _busy = false;
  String? _err;
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.defaultAmount.toStringAsFixed(3));
  }
  @override
  void dispose() { _amount.dispose(); _poll?.cancel(); super.dispose(); }

  Future<void> _gen() async {
    final ar = DriverApi.instance.lang == 'ar';
    setState(() { _busy = true; _err = null; });
    try {
      _link = await DriverApi.instance.paylinkGenerate(widget.orderId,
        provider: _provider,
        amount: double.tryParse(_amount.text.trim()));
      _startPoll();
      setState(() => _busy = false);
    } catch (e) {
      setState(() { _busy = false;
        _err = e is DriverApiException && e.code == 'FORBIDDEN'
          ? (ar ? 'غير مصرح لك بإرسال روابط دفع' : 'Not authorized to send payment links')
          : e.toString(); });
    }
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) async {
      try {
        final st = await DriverApi.instance.paylinkStatus(widget.orderId);
        if (mounted) setState(() => _status = st);
        if (st.isPaid) _poll?.cancel();
      } catch (_) {}
    });
  }

  Future<void> _share(String channel) async {
    if (_link == null) return;
    final ar = DriverApi.instance.lang == 'ar';
    final phone = widget.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = ar
      ? 'مرحباً، رابط دفع طلبك ${widget.orderName}: ${_link!.link}'
      : 'Hello, here is the payment link for your order ${widget.orderName}: ${_link!.link}';
    Uri? uri;
    if (channel == 'whatsapp') {
      uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
    } else if (channel == 'sms') {
      uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(msg)}');
    } else if (channel == 'clipboard') {
      await Clipboard.setData(ClipboardData(text: _link!.link));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم النسخ' : 'Copied to clipboard')));
    } else if (channel == 'share') {
      await Share.share(msg);
    } else if (channel == 'qr') {
      _showQr();
    }
    try { await DriverApi.instance.paylinkShare(widget.orderId, channel); } catch (_) {}
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showQr() {
    if (_link == null) return;
    final ar = DriverApi.instance.lang == 'ar';
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ar ? 'أعرض الكود للعميل' : 'Show this to the customer',
            style: UT.h2),
          const SizedBox(height: 12),
          QrImageView(data: _link!.link, version: QrVersions.auto, size: 220,
            backgroundColor: Colors.white),
          const SizedBox(height: 10),
          Text(widget.orderName, style: const TextStyle(fontFamily: 'monospace',
            fontWeight: FontWeight.w900, color: UC.muted, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.pop(context),
            child: Text(ar ? 'إغلاق' : 'Close')),
        ]))));
  }

  Future<void> _cancelLink() async {
    final ar = DriverApi.instance.lang == 'ar';
    try {
      await DriverApi.instance.paylinkCancel(widget.orderId);
      if (!mounted) return;
      setState(() { _link = null; _status = null; });
      _poll?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إلغاء الرابط' : 'Link cancelled')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'إرسال رابط دفع' : 'Send payment link')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        // Order context card
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
            border: Border.all(color: UC.border),
            borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(width: 42, height: 42, alignment: Alignment.center,
              decoration: BoxDecoration(color: UC.yellowFaint,
                borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.receipt_long_outlined, color: UC.brown)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.orderName, style: const TextStyle(fontFamily: 'monospace',
                fontWeight: FontWeight.w900)),
              Text(widget.customerPhone, style: UT.small),
            ])),
            Text(widget.defaultAmount.toStringAsFixed(3),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 17,
                fontWeight: FontWeight.w900, color: UC.brown)),
          ])),
        const SizedBox(height: 14),
        _lbl(ar ? 'المبلغ المطلوب' : 'Amount to collect'),
        TextField(controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'KD')),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => _amount.text = widget.defaultAmount.toStringAsFixed(3),
            child: Text(ar ? 'كامل' : 'Full'))),
          const SizedBox(width: 6),
          Expanded(child: OutlinedButton(
            onPressed: () => _amount.text = (widget.defaultAmount/2).toStringAsFixed(3),
            child: Text(ar ? '50%' : '50%'))),
        ]),
        const SizedBox(height: 14),
        _lbl(ar ? 'بوابة الدفع' : 'Payment gateway'),
        Row(children: [
          Expanded(child: _provBtn('upayments', 'UPayments',
            ar ? 'KNET · فيزا · ماستر' : 'KNET · Visa · MC', recommended: true)),
          const SizedBox(width: 8),
          Expanded(child: _provBtn('odoo', 'Odoo Pay',
            ar ? 'بوابة احتياطية' : 'Fallback')),
        ]),
        const SizedBox(height: 14),
        if (_link == null)
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _busy ? null : _gen,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: _busy
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
              : const Icon(Icons.bolt, size: 18),
            label: Text(ar ? 'أنشئ الرابط' : 'Generate link',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)))),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: UC.dangerBg,
              borderRadius: BorderRadius.circular(8)),
            child: Text(_err!, style: const TextStyle(
              color: UC.dangerDk, fontWeight: FontWeight.w700)))),
        if (_link != null) ...[
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [UC.brown, UC.brownSoft]),
              borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_link!.provider.toUpperCase()} · ${_link!.amount.format(lang)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFFFE066),
                  fontWeight: FontWeight.w800, letterSpacing: .4)),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(_link!.link, style: const TextStyle(
                  fontFamily: 'monospace', color: Colors.white, fontSize: 11.5,
                  height: 1.4))),
            ])),
          const SizedBox(height: 10),
          _lbl(ar ? 'أرسل للعميل عبر' : 'Send to customer via'),
          GridView.count(shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.6,
            children: [
              _share_btn(Icons.chat, 'WhatsApp', () => _share('whatsapp'),
                bg: const Color(0xFF25D366), fg: Colors.white),
              _share_btn(Icons.sms, ar ? 'رسالة' : 'SMS', () => _share('sms')),
              _share_btn(Icons.copy, ar ? 'انسخ' : 'Copy', () => _share('clipboard')),
              _share_btn(Icons.qr_code_2, ar ? 'رمز QR' : 'QR code', () => _share('qr')),
              _share_btn(Icons.ios_share, ar ? 'مشاركة' : 'Share', () => _share('share')),
            ]),
          const SizedBox(height: 10),
          if (_status != null) Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _status!.isPaid ? UC.successBg : UC.warnBg,
              borderRadius: BorderRadius.circular(11)),
            child: Row(children: [
              Icon(_status!.isPaid ? Icons.check_circle : Icons.hourglass_bottom,
                color: _status!.isPaid ? UC.successDk : const Color(0xFF92400E)),
              const SizedBox(width: 8),
              Expanded(child: Text(_status!.isPaid
                ? (ar ? 'تم الدفع — ${_status!.paidAmount.format(lang)}'
                      : 'PAID — ${_status!.paidAmount.format(lang)}')
                : (ar ? 'بانتظار الدفع… (تحديث كل 8 ثوانٍ)'
                      : 'Waiting for payment… (auto-refresh)'),
                style: TextStyle(fontWeight: FontWeight.w900,
                  color: _status!.isPaid ? UC.successDk : const Color(0xFF92400E)))),
            ])),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _cancelLink,
              icon: const Icon(Icons.close, size: 16),
              label: Text(ar ? 'إلغاء الرابط' : 'Cancel link',
                style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w800)))),
            const SizedBox(width: 6),
            Expanded(child: ElevatedButton.icon(
              onPressed: _busy ? null : _gen,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(ar ? 'أعد التوليد' : 'Re-generate'))),
          ]),
        ],
      ]),
    );
  }

  Widget _provBtn(String key, String name, String sub, {bool recommended = false}) {
    final on = _provider == key;
    return GestureDetector(onTap: () => setState(() => _provider = key),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? UC.yellowFaint : Colors.white,
          border: Border.all(color: on ? UC.yellow : UC.border, width: on ? 2 : 1),
          borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            if (recommended) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: UC.brown,
                    borderRadius: BorderRadius.circular(3)),
                child: const Text('★', style: TextStyle(color: UC.yellowSoft, fontSize: 8))),
            ],
          ]),
          const SizedBox(height: 3),
          Text(sub, style: UT.small),
        ])));
  }

  Widget _share_btn(IconData ic, String label, VoidCallback onTap,
      {Color bg = Colors.white, Color fg = UC.brown}) {
    return Material(color: bg, borderRadius: BorderRadius.circular(11),
      child: InkWell(borderRadius: BorderRadius.circular(11), onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: bg == Colors.white ? UC.border : bg),
            borderRadius: BorderRadius.circular(11)),
          padding: const EdgeInsets.all(10),
          alignment: Alignment.center,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, color: fg, size: 18),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: fg,
              fontWeight: FontWeight.w900, fontSize: 11.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ]))));
  }

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10.5,
      fontWeight: FontWeight.w800, color: UC.muted, letterSpacing: .4)));
}
