// ════════════════ PICKUPS — collect a trip from the Uellow warehouse ═══════
// The pickup courier (a driver assigned as the trip's pickup_driver) collects
// the orders from the Uellow warehouse — by scanning barcodes or one-by-one —
// which moves them pending → picked_up. The carrier sorting centre then
// receives them. Mirrors the carrier app's receiving UX.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/api.dart';
import '../theme/theme.dart';

class PickupsScreen extends StatefulWidget {
  const PickupsScreen({super.key});
  @override
  State<PickupsScreen> createState() => _PickupsScreenState();
}

class _PickupsScreenState extends State<PickupsScreen> {
  List<Map<String, dynamic>>? _pickups;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final v = await DriverApi.instance.pickups();
      if (mounted) setState(() => _pickups = v);
    } catch (_) {
      if (mounted) setState(() => _pickups = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    final pickups = _pickups;
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الاستلام من مخزن يلو' : 'Pickups from Uellow')),
      body: pickups == null
          ? const Center(child: USpinner())
          : RefreshIndicator(
              onRefresh: _load,
              child: pickups.isEmpty
                  ? ListView(children: [Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: UC.muted),
                        const SizedBox(height: 12),
                        Text(ar ? 'لا توجد مهام استلام حالياً' : 'No pickups assigned',
                            style: UT.body, textAlign: TextAlign.center),
                      ]))])
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: pickups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _card(pickups[i], ar))),
    );
  }

  Widget _card(Map<String, dynamic> p, bool ar) {
    final total = (p['total'] as num?)?.toInt() ?? 0;
    final toCollect = (p['to_collect'] as num?)?.toInt() ?? 0;
    final collected = total - toCollect;
    final pct = total == 0 ? 0.0 : collected / total;
    final done = toCollect == 0;
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(13),
      child: InkWell(borderRadius: BorderRadius.circular(13),
        onTap: () => _open(p),
        child: Container(padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(border: Border.all(color: UC.border),
              borderRadius: BorderRadius.circular(13)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 42, height: 42, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? UC.successBg : UC.yellowFaint,
                  borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.warehouse_outlined,
                    color: done ? UC.successDk : UC.brown)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text((p['name'] ?? '').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                Text('${ar ? "من مخزن يلو" : "From Uellow"} · $total ${ar ? "طلبات" : "orders"}',
                    style: UT.small),
              ])),
              UPill(
                text: done ? (ar ? 'تم الجمع' : 'Collected')
                           : '$toCollect ${ar ? "للجمع" : "to collect"}',
                bg: done ? UC.successBg : UC.warnBg,
                fg: done ? UC.successDk : const Color(0xFF92400E)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: pct,
                  backgroundColor: UC.bg,
                  color: done ? UC.success : UC.yellow, minHeight: 6)),
          ]))));
  }

  Future<void> _open(Map<String, dynamic> p) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PickupReceiveScreen(
          tripId: (p['id'] as num).toInt(),
          tripName: (p['name'] ?? '').toString()),
    ));
    if (changed == true) _load();
  }
}

// ════════════════ PICKUP RECEIVE SCREEN ════════════════
class PickupReceiveScreen extends StatefulWidget {
  const PickupReceiveScreen({super.key, required this.tripId, required this.tripName});
  final int tripId;
  final String tripName;
  @override
  State<PickupReceiveScreen> createState() => _PickupReceiveScreenState();
}

class _PickupReceiveScreenState extends State<PickupReceiveScreen> {
  List<Map<String, dynamic>>? _orders;
  final Set<int> _scanned = {};
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await DriverApi.instance.pickupDetail(widget.tripId);
      final orders = List<Map<String, dynamic>>.from(
          (res['orders'] as List?) ?? const []);
      if (mounted) setState(() => _orders = orders);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  bool _already(Map<String, dynamic> o) => o['collected'] == true;
  bool _done(Map<String, dynamic> o) =>
      _already(o) || _scanned.contains((o['id'] as num).toInt());
  List<Map<String, dynamic>> get _pending =>
      (_orders ?? const []).where((o) => !_already(o)).toList();

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<Set<int>>(MaterialPageRoute(
      builder: (_) => _PickupScanScreen(orders: _pending, initialScanned: _scanned),
    ));
    if (result != null) setState(() => _scanned.addAll(result));
  }

  Future<void> _collectAll() async {
    final ar = DriverApi.instance.lang == 'ar';
    final pendingIds = _pending.map((o) => (o['id'] as num).toInt()).toSet();
    if (pendingIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar ? 'لا يوجد ما يُجمع' : 'Nothing to collect')));
      return;
    }
    final scannedPending = pendingIds.intersection(_scanned);
    final notScanned = pendingIds.difference(_scanned);
    if (notScanned.isEmpty) {
      await _submit(orderIds: scannedPending.toList(), collectMissing: false);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'جمع الطلبات' : 'Collect orders'),
        content: Text(ar
            ? 'يوجد ${notScanned.length} طلب لم يتم مسحه/جمعه.\n'
              'تجمع الكل أم المُمسوح فقط (${scannedPending.length})؟'
            : '${notScanned.length} order(s) not scanned.\n'
              'Collect all, or only scanned (${scannedPending.length})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          if (scannedPending.isNotEmpty)
            TextButton(onPressed: () => Navigator.pop(ctx, 'scanned'),
                child: Text(ar ? 'المُمسوح فقط' : 'Scanned only')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'all'),
              child: Text(ar ? 'جمع الكل' : 'Collect all')),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') return;
    if (choice == 'all') {
      await _submit(orderIds: pendingIds.toList(), collectMissing: true);
    } else {
      await _submit(orderIds: scannedPending.toList(), collectMissing: false);
    }
  }

  Future<void> _submit({required List<int> orderIds, required bool collectMissing}) async {
    final ar = DriverApi.instance.lang == 'ar';
    setState(() => _busy = true);
    try {
      final res = await DriverApi.instance.pickupCollect(widget.tripId,
          orderIds: orderIds, collectMissing: collectMissing);
      final n = (res['collected'] as num?)?.toInt() ?? orderIds.length;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: UC.success,
          content: Text(ar ? '✓ تم جمع $n طلب من مخزن يلو'
                            : '✓ Collected $n order(s) from Uellow')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    final orders = _orders;
    final total = orders?.length ?? 0;
    final doneCount = (orders ?? const []).where(_done).length;
    return Scaffold(
      appBar: AppBar(title: Text('${ar ? "جمع" : "Collect"} · ${widget.tripName}')),
      body: orders == null
          ? const Center(child: USpinner())
          : Column(children: [
              Container(
                width: double.infinity,
                color: UC.brown,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('$doneCount / $total ${ar ? "مجموع" : "collected"}',
                      style: const TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                        value: total == 0 ? 0 : doneCount / total, minHeight: 8,
                        backgroundColor: Colors.white24, color: UC.yellow)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: SizedBox(width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _scan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UC.brown, foregroundColor: UC.yellowSoft,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                    icon: const Icon(Icons.qr_code_scanner, size: 22),
                    label: Text(ar ? 'مسح باركود الطلبات' : 'Scan order barcodes',
                        style: const TextStyle(fontWeight: FontWeight.w900,
                            fontSize: 15)))),
              ),
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                itemCount: orders.length,
                itemBuilder: (_, i) => _orderRow(orders[i], ar))),
              SafeArea(top: false, child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: SizedBox(width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _collectAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UC.success, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child:
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.done_all, size: 22),
                    label: Text(ar ? 'جمع الكل / المُمسوح' : 'Collect all / scanned',
                        style: const TextStyle(fontWeight: FontWeight.w900,
                            fontSize: 15)))),
              )),
            ]),
    );
  }

  Widget _orderRow(Map<String, dynamic> o, bool ar) {
    final id = (o['id'] as num).toInt();
    final done = _done(o);
    final already = _already(o);
    final customer = (o['customer'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: done ? UC.successBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: done ? UC.success.withValues(alpha: 0.5) : UC.border, width: 1.3),
      ),
      child: Row(children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? UC.success : UC.muted, size: 24),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text((o['name'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          Text('${customer['name'] ?? ''} · ${o['addr_short'] ?? ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: UT.small),
        ])),
        if (already)
          Text(ar ? 'مجموع' : 'Collected',
              style: const TextStyle(color: UC.successDk,
                  fontWeight: FontWeight.w800, fontSize: 11))
        else if (done)
          TextButton(onPressed: () => setState(() => _scanned.remove(id)),
              child: Text(ar ? 'تراجع' : 'Undo', style: const TextStyle(fontSize: 11.5)))
        else
          ElevatedButton(
            onPressed: () => setState(() => _scanned.add(id)),
            style: ElevatedButton.styleFrom(
              backgroundColor: UC.brown, foregroundColor: UC.yellowSoft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              minimumSize: const Size(0, 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
            child: Text(ar ? 'جمع' : 'Collect',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

// ════════════════ BARCODE SCANNER ════════════════
class _PickupScanScreen extends StatefulWidget {
  const _PickupScanScreen({required this.orders, required this.initialScanned});
  final List<Map<String, dynamic>> orders;
  final Set<int> initialScanned;
  @override
  State<_PickupScanScreen> createState() => _PickupScanScreenState();
}

class _PickupScanScreenState extends State<_PickupScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back);
  late final Set<int> _scanned = {...widget.initialScanned};
  String _msg = '';
  Color _msgColor = UC.brown;
  String _lastRaw = '';

  int? _match(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.isEmpty) return null;
    for (final o in widget.orders) {
      final id = (o['id'] as num).toInt();
      final code = (o['code'] ?? '').toString().trim().toLowerCase();
      final name = (o['name'] ?? '').toString().trim().toLowerCase();
      if (r == code || r == name || r == '$id') return id;
    }
    return null;
  }

  void _onDetect(BarcodeCapture cap) {
    final ar = DriverApi.instance.lang == 'ar';
    for (final b in cap.barcodes) {
      final raw = (b.rawValue ?? '').trim();
      if (raw.isEmpty || raw == _lastRaw) continue;
      _lastRaw = raw;
      final id = _match(raw);
      if (id == null) {
        _flash(ar ? '✗ باركود غير معروف' : '✗ Unknown barcode', UC.danger);
      } else if (_scanned.contains(id)) {
        _flash(ar ? '• مُسجّل بالفعل' : '• Already scanned', UC.warn);
      } else {
        _scanned.add(id);
        HapticFeedback.mediumImpact();
        final o = widget.orders.firstWhere((x) => (x['id'] as num).toInt() == id);
        _flash('✓ ${o['name']}', UC.success);
      }
    }
  }

  void _flash(String msg, Color color) {
    if (mounted) setState(() { _msg = msg; _msgColor = color; });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    final total = widget.orders.length;
    final got = widget.orders
        .where((o) => _scanned.contains((o['id'] as num).toInt())).length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Center(child: Container(width: 250, height: 250,
          decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(18)))),
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context, _scanned),
                icon: const Icon(Icons.arrow_back, color: Colors.white)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: UC.brown.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999)),
              child: Text(ar ? 'مُمسوح: $got / $total' : 'Scanned: $got / $total',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 13))),
            const Spacer(),
            IconButton(onPressed: () => _controller.toggleTorch(),
                icon: const Icon(Icons.flash_on, color: Colors.white)),
          ]),
        )),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_msg.isNotEmpty) Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: _msgColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_msg, style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 14))),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _scanned),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: UC.brown,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(ar ? 'تم — رجوع' : 'Done — back',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)))),
            ]),
          )),
        ),
      ]),
    );
  }
}
