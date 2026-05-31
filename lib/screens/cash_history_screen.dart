import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class CashHistoryScreen extends StatefulWidget {
  const CashHistoryScreen({super.key});
  @override
  State<CashHistoryScreen> createState() => _CashHistoryScreenState();
}

class _CashHistoryScreenState extends State<CashHistoryScreen> {
  Future<List<CashHistoryItem>>? _f;
  @override
  void initState() { super.initState(); _f = DriverApi.instance.cashHistory(); }
  Future<void> _refresh() async {
    setState(() => _f = DriverApi.instance.cashHistory());
    await _f;
  }

  Color _stateBg(String s) => switch (s) {
    'settled'   => UC.successBg,
    'approved'  => UC.infoBg,
    'submitted' => UC.warnBg,
    _ => UC.bg,
  };
  Color _stateFg(String s) => switch (s) {
    'settled'   => UC.successDk,
    'approved'  => const Color(0xFF1E40AF),
    'submitted' => const Color(0xFF92400E),
    _ => UC.muted,
  };

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'سجل التسويات' : 'Settlement history')),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<List<CashHistoryItem>>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (snap.hasError) return Center(child: Text(snap.error.toString(), style: UT.body));
        final rows = snap.data ?? const <CashHistoryItem>[];
        if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(40),
          child: Center(child: Text(ar ? 'لا توجد تسويات بعد' : 'No settlements yet',
            style: UT.body)));
        return ListView.separated(itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: UC.bg),
          itemBuilder: (_, i) {
            final r = rows[i];
            return Container(color: Colors.white, padding: const EdgeInsets.all(13),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r.name} · ${r.orderCount} ${ar ? "طلبات" : "orders"}',
                    style: const TextStyle(fontFamily: 'monospace',
                      fontWeight: FontWeight.w900, fontSize: 12.5)),
                  Row(children: [
                    Text(r.when.split('T').first, style: UT.small),
                    const SizedBox(width: 6),
                    UPill(text: r.stateLabel.t(lang),
                      bg: _stateBg(r.state), fg: _stateFg(r.state)),
                  ]),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(r.total.format(lang), style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 13.5,
                    fontWeight: FontWeight.w900, color: UC.brown)),
                  Text(ar ? 'صافي ${r.net.format(lang)}'
                          : 'Net ${r.net.format(lang)}',
                    style: UT.small),
                ]),
              ]));
          });
      })),
    );
  }
}
