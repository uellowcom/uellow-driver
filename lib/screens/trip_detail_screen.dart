import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final int tripId;
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Future<TripDetail>? _f;
  @override
  void initState() { super.initState(); _f = DriverApi.instance.tripDetail(widget.tripId); }

  Future<void> _navTo(double lat, double lng) async {
    await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text('Trip #${widget.tripId}')),
      body: FutureBuilder<TripDetail>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (snap.hasError) return Center(child: Text(snap.error.toString(), style: UT.body));
        final t = snap.data!;
        final nextStop = t.stops.firstWhere((s) => s.status != 'delivered',
          orElse: () => t.stops.isEmpty
            ? const TripStop(lineId: 0, orderId: 0, sequence: 0, orderName: '',
                customer: '', addrShort: '', status: '', statusLabel: BL('',''),
                amount: Money(amount:0,currency:'KWD',symbol:'KD',digits:3), lat: 0, lng: 0)
            : t.stops.last);
        return ListView(padding: EdgeInsets.zero, children: [
          Container(padding: const EdgeInsets.fromLTRB(14, 8, 14, 12), color: Colors.white,
            child: Row(children: [
              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const Spacer(),
              UPill(text: t.stateLabel.t(lang),
                bg: t.state == 'in_progress' ? UC.warnBg : UC.successBg,
                fg: t.state == 'in_progress' ? const Color(0xFF92400E) : UC.successDk,
                live: t.state == 'in_progress'),
            ])),
          Container(margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white,
              border: Border.all(color: UC.border),
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _stat('${t.doneCount}', ar ? 'تم' : 'Done', UC.successDk),
              _stat('${t.lineCount - t.doneCount - t.failedCount}', ar ? 'متبقي' : 'Left', UC.brown),
              _stat('${t.failedCount}', ar ? 'فشل' : 'Failed', UC.dangerDk),
            ])),
          const SizedBox(height: 10),
          for (final s in t.stops) _stopRow(s, lang),
          const SizedBox(height: 90),
        ]);
      }),
      bottomNavigationBar: FutureBuilder<TripDetail>(future: _f, builder: (_, snap) {
        if (snap.data == null) return const SizedBox.shrink();
        final next = snap.data!.stops.firstWhere((s) => s.status != 'delivered',
          orElse: () => const TripStop(lineId: 0, orderId: 0, sequence: 0,
            orderName: '', customer: '', addrShort: '', status: '',
            statusLabel: BL('',''),
            amount: Money(amount:0,currency:'KWD',symbol:'KD',digits:3),
            lat: 0, lng: 0));
        if (next.orderId == 0) return const SizedBox.shrink();
        return SafeArea(top: false, child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: UC.border))),
          child: ElevatedButton.icon(
            onPressed: () => _navTo(next.lat, next.lng),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: UC.brown, foregroundColor: UC.yellowSoft),
            icon: const Icon(Icons.navigation, size: 18),
            label: Text(ar ? 'انتقل إلى ${next.orderName}'
                            : 'Navigate to ${next.orderName}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
        ));
      }),
    );
  }

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w900)),
    Text(l, style: const TextStyle(fontSize: 10.5, color: UC.muted, fontWeight: FontWeight.w800)),
  ]));

  Widget _stopRow(TripStop s, String lang) {
    final done = s.status == 'delivered';
    final failed = s.status == 'failed';
    return Material(color: Colors.white,
      child: InkWell(onTap: s.orderId > 0 ? () => Navigator.pushNamed(context, '/order',
          arguments: {'id': s.orderId}) : null,
        child: Container(padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: UC.bg))),
          child: Row(children: [
            Container(width: 30, height: 30, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: done ? UC.success : (failed ? UC.danger : UC.yellow),
                boxShadow: !done && !failed ? const [BoxShadow(color: Color(0x40F5C320),
                  blurRadius: 8, spreadRadius: 2)] : null),
              child: Text(done ? '✓' : (failed ? '✕' : '${s.sequence}'),
                style: TextStyle(color: done || failed ? Colors.white : UC.brown,
                  fontWeight: FontWeight.w900, fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.orderName} · ${s.customer}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              Text(s.addrShort, style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Text(s.amount.format(lang),
              style: const TextStyle(fontWeight: FontWeight.w900,
                color: UC.brown, fontSize: 13)),
          ]))));
  }
}
