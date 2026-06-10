import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';
import 'pickups_screen.dart';

class TripsTab extends StatefulWidget {
  const TripsTab({super.key});
  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> {
  Future<List<Trip>>? _f;
  List<Map<String, dynamic>> _pickups = const [];
  @override
  void initState() {
    super.initState();
    _f = DriverApi.instance.trips();
    _loadPickups();
  }
  Future<void> _loadPickups() async {
    try {
      final v = await DriverApi.instance.pickups();
      if (mounted) setState(() => _pickups = v);
    } catch (_) {}
  }
  Future<void> _refresh() async {
    setState(() => _f = DriverApi.instance.trips());
    _loadPickups();
    await _f;
  }

  Widget _pickupBanner(bool ar) {
    if (_pickups.isEmpty) return const SizedBox.shrink();
    final n = _pickups.length;
    final toCollect = _pickups.fold<int>(0,
        (s, p) => s + ((p['to_collect'] as num?)?.toInt() ?? 0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(color: UC.brown, borderRadius: BorderRadius.circular(13),
        child: InkWell(borderRadius: BorderRadius.circular(13),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PickupsScreen()));
            _loadPickups();
          },
          child: Padding(padding: const EdgeInsets.all(13),
            child: Row(children: [
              const Icon(Icons.warehouse_outlined, color: UC.yellowSoft, size: 26),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(ar ? 'استلام من مخزن يلو' : 'Pickups from Uellow',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 14)),
                Text(ar ? '$n رحلة · $toCollect طلب للجمع'
                        : '$n trip(s) · $toCollect to collect',
                    style: const TextStyle(color: Color(0xFFE9D9A8), fontSize: 11.5)),
              ])),
              const Icon(Icons.chevron_right, color: UC.yellowSoft),
            ]))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الرحلات' : 'Trips')),
      body: Column(children: [
        _pickupBanner(ar),
        Expanded(child: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<List<Trip>>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (snap.hasError) return Center(child: Text(snap.error.toString(), style: UT.body));
        final rows = snap.data ?? const <Trip>[];
        if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(40),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.route, size: 48, color: UC.muted),
            const SizedBox(height: 12),
            Text(ar ? 'لا توجد رحلات' : 'No trips', style: UT.body),
          ])));
        return ListView.separated(padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _card(rows[i], ar));
      }))),
      ]),
    );
  }

  Widget _card(Trip t, bool ar) {
    final lang = ar ? 'ar' : 'en';
    final progress = t.lineCount == 0 ? 0.0 : t.doneCount / t.lineCount;
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(13),
      child: InkWell(borderRadius: BorderRadius.circular(13),
        onTap: () => Navigator.pushNamed(context, '/trip', arguments: {'id': t.id}),
        child: Container(padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(border: Border.all(color: UC.border),
            borderRadius: BorderRadius.circular(13)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 42, height: 42, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.state == 'in_progress' ? UC.yellowFaint : UC.successBg,
                  borderRadius: BorderRadius.circular(11)),
                child: Icon(
                  t.state == 'in_progress' ? Icons.local_shipping_outlined
                                            : Icons.check_circle_outline,
                  color: t.state == 'in_progress' ? UC.brown : UC.successDk)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                Text('${t.lineCount} ${ar ? "طلبات" : "orders"} · ${t.date.split("T").first}',
                  style: UT.small),
              ])),
              UPill(text: t.stateLabel.t(lang),
                bg: t.state == 'in_progress' ? UC.warnBg : UC.successBg,
                fg: t.state == 'in_progress' ? const Color(0xFF92400E) : UC.successDk,
                live: t.state == 'in_progress'),
            ]),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress,
                backgroundColor: UC.bg, color: UC.success, minHeight: 6)),
            const SizedBox(height: 4),
            Text('${t.doneCount}/${t.lineCount} ${ar ? "تم تسليمها" : "delivered"}'
                 '${t.failedCount > 0 ? " · ${t.failedCount} ${ar ? "فاشلة" : "failed"}" : ""}',
              style: UT.small),
          ]))));
  }
}
