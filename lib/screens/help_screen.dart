import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  Future<List<Map<String, dynamic>>>? _f;
  final _msg = TextEditingController();
  bool _sending = false;
  @override
  void initState() { super.initState(); _f = DriverApi.instance.faq(); }
  @override
  void dispose() { _msg.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await DriverApi.instance.chat(_msg.text.trim());
      _msg.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(DriverApi.instance.lang == 'ar' ? 'تم الإرسال للعمليات'
                                                      : 'Sent to operations')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _emergency() async {
    final ar = DriverApi.instance.lang == 'ar';
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(ar ? 'تأكيد الطوارئ' : 'Confirm emergency'),
      content: Text(ar ? 'سيتم تنبيه فريق العمليات فوراً مع موقعك ورقمك.'
                       : 'Operations will be alerted immediately with your location and phone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text(ar ? 'إلغاء' : 'Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: UC.danger, foregroundColor: Colors.white),
          child: Text(ar ? 'تأكيد' : 'Confirm')),
      ]));
    if (ok != true) return;
    try {
      await DriverApi.instance.emergency(kind: 'manual');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم تنبيه العمليات' : 'Operations alerted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'مساعدة' : 'Help')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
            border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Row(children: [
              Container(width: 42, height: 42, alignment: Alignment.center,
                decoration: const BoxDecoration(color: UC.brown, shape: BoxShape.circle),
                child: const Icon(Icons.chat, color: UC.yellowSoft)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ar ? 'فريق العمليات' : 'Operations team',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                Row(children: [
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: UC.success, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(ar ? 'متصل · يرد خلال ~2 د' : 'Online · replies in ~2 min',
                    style: const TextStyle(color: UC.successDk,
                      fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ])),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _msg, minLines: 2, maxLines: 4,
              decoration: InputDecoration(hintText: ar ? 'اكتب رسالتك…' : 'Type your message…')),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, size: 16),
              label: Text(ar ? 'إرسال' : 'Send'))),
          ])),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _emergency,
          style: ElevatedButton.styleFrom(
            backgroundColor: UC.danger, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13)),
          icon: const Icon(Icons.warning_amber, size: 18),
          label: Text(ar ? '🚨 طوارئ — حادث / سرقة' : '🚨 Emergency — accident / theft',
            style: const TextStyle(fontWeight: FontWeight.w900)))),
        const SizedBox(height: 18),
        Text(ar ? 'الأسئلة الشائعة' : 'Quick answers', style: UT.h2),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const USpinner();
          final rows = snap.data ?? const [];
          return Column(children: rows.map((r) {
            final q = ((r['q'] as Map?)?[ar ? 'ar' : 'en'] ?? '').toString();
            final a = ((r['a'] as Map?)?[ar ? 'ar' : 'en'] ?? '').toString();
            return Container(margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white,
                border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(11)),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const RoundedRectangleBorder(),
                title: Text(q, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                children: [Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(a, style: UT.body))]));
          }).toList());
        }),
      ]),
    );
  }
}
