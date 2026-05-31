import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class CashTab extends StatelessWidget {
  const CashTab({super.key});
  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'النقد' : 'Cash')),
      body: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        _bigBtn(context, Icons.payments, ar ? 'تسوية النقد المحصّل' : 'Settle collected cash',
          ar ? 'اختر طلبات COD وأرسلها للشركة' : 'Pick COD orders & submit to your carrier',
          '/cash'),
        const SizedBox(height: 10),
        _bigBtn(context, Icons.history, ar ? 'سجل التسويات' : 'Settlement history',
          ar ? 'كل ما أرسلته للشركة الناقلة' : 'Everything previously submitted',
          '/cash-history'),
      ])),
    );
  }
  Widget _bigBtn(BuildContext c, IconData ic, String title, String sub, String route) {
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(c, route),
        child: Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: UC.border),
            borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(width: 48, height: 48, alignment: Alignment.center,
              decoration: BoxDecoration(color: UC.yellowFaint,
                borderRadius: BorderRadius.circular(13)),
              child: Icon(ic, color: UC.brown, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13.5,
                fontWeight: FontWeight.w900, color: UC.ink)),
              Text(sub, style: UT.small),
            ])),
            const Icon(Icons.chevron_right, color: UC.muted),
          ]))));
  }
}
