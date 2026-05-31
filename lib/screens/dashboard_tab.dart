import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Future<Dashboard>? _f;
  @override
  void initState() { super.initState(); _f = DriverApi.instance.dashboard(); }
  Future<void> _refresh() async {
    setState(() => _f = DriverApi.instance.dashboard());
    await _f;
  }

  Future<void> _setStatus(String s) async {
    try {
      await DriverApi.instance.setStatus(s);
      _refresh();
    } catch (_) {}
  }

  void _pickStatus() {
    final ar = DriverApi.instance.lang == 'ar';
    showModalBottomSheet(context: context, builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final s in const [
          ('available', '🟢', 'Available', 'متاح'),
          ('busy',      '🟡', 'Busy',      'مشغول'),
          ('offline',   '⚫', 'Offline',   'غير متصل'),
        ])
          ListTile(
            leading: Text(s.$2, style: const TextStyle(fontSize: 20)),
            title: Text(ar ? s.$4 : s.$3, style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: () { Navigator.pop(sheet); _setStatus(s.$1); }),
      ])));
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'أهلاً، ${DriverApi.instance.driver?.name ?? ""}'
                       : 'Hi, ${DriverApi.instance.driver?.name ?? ""}'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.pushNamed(context, '/notifications')),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<Dashboard>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: USpinner());
        }
        if (snap.hasError) {
          return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
        }
        final d = snap.data!;
        return ListView(padding: EdgeInsets.zero, children: [
          // Hero card
          Container(margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [UC.brown, UC.brownSoft]),
              borderRadius: BorderRadius.circular(18)),
            child: Stack(children: [
              Positioned(top: -30, right: -30, child: Container(
                width: 120, height: 120,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(colors: [Color(0x33F5C320), Colors.transparent]),
                  shape: BoxShape.circle))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(ar ? 'اليوم' : 'Today',
                    style: const TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  GestureDetector(onTap: _pickStatus,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x4010B981),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x6610B981))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: d.status == 'available' ? UC.success
                                  : (d.status == 'busy' ? UC.warn : UC.muted),
                            shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(_statusLabel(d.status, ar),
                          style: const TextStyle(color: Color(0xFFA7F3D0),
                            fontSize: 11, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFFA7F3D0)),
                      ]))),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  _kpi('${d.done}', ar ? 'منجزة' : 'Done'),
                  _kpi('${d.pending}', ar ? 'قيد التنفيذ' : 'Pending'),
                  _kpi('${d.successRate}%', ar ? 'معدل النجاح' : 'Rate'),
                ]),
                const SizedBox(height: 14),
                Material(color: Colors.transparent, child: InkWell(
                  onTap: () => Navigator.pushNamed(context, '/cash'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [UC.yellow, UC.yellowSoft]),
                      borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Container(width: 42, height: 42, alignment: Alignment.center,
                        decoration: const BoxDecoration(color: UC.brown,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.payments,
                            color: UC.yellowSoft, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ar ? 'نقد للتسوية' : 'Cash to settle',
                          style: const TextStyle(color: UC.brownSoft, fontSize: 10.5,
                              fontWeight: FontWeight.w800, letterSpacing: .4)),
                        const SizedBox(height: 2),
                        Text(d.cashHeld.format(DriverApi.instance.lang),
                          style: const TextStyle(color: UC.brown, fontSize: 18,
                            fontWeight: FontWeight.w900)),
                      ])),
                      const Icon(Icons.chevron_right, color: UC.brown),
                    ])))),
              ]),
            ])),
          // Next 3
          if (d.next.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
            child: Row(children: [
              Text(ar ? 'القادمة' : 'Next deliveries', style: UT.h3),
            ])),
          for (final o in d.next) _nextRow(o, ar),
          const SizedBox(height: 14),
          if (d.hasActiveTrip) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () { (context.findAncestorStateOfType<State>())?.setState(() {}); },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(ar ? 'الرحلة جارية الآن' : 'Trip in progress',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UC.brown, foregroundColor: UC.yellowSoft,
                padding: const EdgeInsets.symmetric(vertical: 14))))),
        ]);
      })),
    );
  }

  Widget _kpi(String v, String l) => Expanded(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(11)),
    child: Column(children: [
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 20,
        fontWeight: FontWeight.w900, height: 1.1)),
      const SizedBox(height: 2),
      Text(l, style: const TextStyle(color: Color(0xFFFFE066), fontSize: 9.5,
        fontWeight: FontWeight.w800, letterSpacing: .3)),
    ])));

  Widget _nextRow(OrderSummary o, bool ar) {
    return Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(color: Colors.white, borderRadius: BorderRadius.circular(12),
        child: InkWell(borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pushNamed(context, '/order', arguments: {'id': o.id}),
          child: Container(padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 36, height: 36, alignment: Alignment.center,
                decoration: BoxDecoration(color: UC.yellowFaint,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(o.name.replaceFirst(RegExp(r'^S0*'), '#'),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                    color: UC.brown))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.customer, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w800, color: UC.ink)),
                Text(o.addrShort, style: UT.small, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 8),
              Text(o.amount.format(DriverApi.instance.lang),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900,
                  color: UC.brown)),
            ])))));
  }

  String _statusLabel(String s, bool ar) {
    final m = const {
      'available': ('Available', 'متاح'),
      'busy':      ('Busy', 'مشغول'),
      'offline':   ('Offline', 'غير متصل'),
    };
    final v = m[s];
    if (v == null) return s;
    return ar ? v.$2 : v.$1;
  }
}
