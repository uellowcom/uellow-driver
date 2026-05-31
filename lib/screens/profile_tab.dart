import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    final d = DriverApi.instance.driver;
    if (d == null) return const Center(child: USpinner());
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'حسابي' : 'My profile'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings')),
        ]),
      body: ListView(padding: EdgeInsets.zero, children: [
        // Hero
        Container(padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [UC.yellow, UC.yellowSoft])),
          child: Row(children: [
            Container(width: 68, height: 68, alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x29412402),
                  blurRadius: 12, offset: Offset(0, 6))]),
              child: d.photoUrl != null && d.photoUrl!.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(18),
                    child: CachedNetworkImage(
                      imageUrl: '${DriverApi.instance.baseUrl}${d.photoUrl}',
                      width: 64, height: 64, fit: BoxFit.cover,
                      errorWidget: (_,__,___) => _initial(d.name)))
                : _initial(d.name)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: const TextStyle(color: UC.brown, fontSize: 18,
                fontWeight: FontWeight.w900)),
              Text(d.phone, style: const TextStyle(color: UC.brownSoft, fontSize: 12.5)),
              if (d.vehicle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0x29412402),
                    borderRadius: BorderRadius.circular(999)),
                  child: Text('🚗 ${d.vehicle}',
                    style: const TextStyle(color: UC.brown,
                      fontSize: 10.5, fontWeight: FontWeight.w800)))),
            ])),
          ])),
        // Menu
        Container(color: Colors.white, child: Column(children: [
          _row(Icons.notifications_outlined, ar ? 'الإشعارات' : 'Notifications',
            () => Navigator.pushNamed(context, '/notifications')),
          _row(Icons.payments_outlined, ar ? 'سجل النقد' : 'Cash history',
            () => Navigator.pushNamed(context, '/cash-history')),
          _row(Icons.settings_outlined, ar ? 'الإعدادات' : 'Settings',
            () => Navigator.pushNamed(context, '/settings')),
          _row(Icons.chat_bubble_outline, ar ? 'مساعدة / محادثة العمليات' : 'Help / Ops chat',
            () => Navigator.pushNamed(context, '/help')),
          _row(Icons.logout, ar ? 'تسجيل الخروج' : 'Sign out', () async {
            await DriverApi.instance.logout();
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          }, danger: true),
        ])),
      ]),
    );
  }

  Widget _initial(String name) => Center(child: Text(
    name.isNotEmpty ? name[0].toUpperCase() : 'D',
    style: const TextStyle(color: UC.brown, fontSize: 26, fontWeight: FontWeight.w900)));

  Widget _row(IconData ic, String label, VoidCallback onTap, {bool danger = false}) {
    return InkWell(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: UC.bg))),
      child: Row(children: [
        Container(width: 34, height: 34, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: danger ? UC.dangerBg : UC.yellowFaint,
            borderRadius: BorderRadius.circular(10)),
          child: Icon(ic, color: danger ? UC.dangerDk : UC.brown, size: 17)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(
          color: danger ? UC.dangerDk : UC.ink,
          fontWeight: FontWeight.w700, fontSize: 13))),
        const Icon(Icons.chevron_right, color: UC.muted, size: 18),
      ])));
  }
}
