import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<Notif>>? _f;
  @override
  void initState() { super.initState(); _f = DriverApi.instance.notifs(); }
  Future<void> _refresh() async {
    setState(() => _f = DriverApi.instance.notifs());
    await _f;
  }

  Color _bg(String c) => switch (c) {
    'new_order'   => UC.yellowFaint,
    'reschedule'  => UC.warnBg,
    'settlement'  => UC.successBg,
    'vehicle_doc' => UC.warnBg,
    _ => UC.infoBg,
  };
  Color _fg(String c) => switch (c) {
    'new_order'   => UC.brown,
    'reschedule'  => const Color(0xFF92400E),
    'settlement'  => UC.successDk,
    'vehicle_doc' => const Color(0xFF92400E),
    _ => const Color(0xFF1E40AF),
  };
  IconData _ic(String c) => switch (c) {
    'new_order'   => Icons.inventory_2,
    'reschedule'  => Icons.schedule,
    'settlement'  => Icons.payments,
    'vehicle_doc' => Icons.directions_car,
    _ => Icons.chat,
  };

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الإشعارات' : 'Notifications')),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<List<Notif>>(future: _f, builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (snap.hasError) return Center(child: Text(snap.error.toString(), style: UT.body));
        final rows = snap.data ?? const <Notif>[];
        if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(40),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.notifications_off_outlined, size: 48, color: UC.muted),
            const SizedBox(height: 12),
            Text(ar ? 'لا توجد إشعارات' : 'No notifications', style: UT.body),
          ])));
        return ListView.separated(itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: UC.bg),
          itemBuilder: (_, i) {
            final n = rows[i];
            return InkWell(onTap: n.orderId != null
              ? () => Navigator.pushNamed(context, '/order', arguments: {'id': n.orderId})
              : null,
              child: Container(color: Colors.white, padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 36, height: 36, alignment: Alignment.center,
                    decoration: BoxDecoration(color: _bg(n.category),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(_ic(n.category), color: _fg(n.category), size: 17)),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 13)),
                    if (n.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
                      child: Text(n.body, style: UT.small, maxLines: 2,
                        overflow: TextOverflow.ellipsis)),
                    Padding(padding: const EdgeInsets.only(top: 3),
                      child: Text(n.when.split('T').first,
                        style: const TextStyle(fontSize: 10.5, color: UC.muted))),
                  ])),
                  if (n.isNew) Container(width: 8, height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(color: UC.yellow, shape: BoxShape.circle)),
                ])));
          });
      })),
    );
  }
}
