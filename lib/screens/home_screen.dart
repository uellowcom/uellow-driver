// Home shell with bottom navigation. Wraps the 5 main tabs:
// Dashboard, Orders, Trips, Cash, Profile.
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';
import '../location_beacon.dart';
import 'dashboard_tab.dart';
import 'orders_tab.dart';
import 'trips_tab.dart';
import 'cash_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late final List<Widget> _pages;
  @override
  void initState() {
    super.initState();
    _pages = const [
      DashboardTab(), OrdersTab(), TripsTab(), CashTab(), ProfileTab(),
    ];
    // v1.1.2 — start the GPS heartbeat so the customer can track the driver
    // live during delivery. Backend only broadcasts while a stop is active.
    LocationBeacon.instance.start();
  }

  @override
  void dispose() {
    LocationBeacon.instance.stop();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white,
          border: Border(top: BorderSide(color: UC.border)),
          boxShadow: [BoxShadow(color: Color(0x14000000),
            blurRadius: 8, offset: Offset(0, -2))]),
        child: SafeArea(top: false, child: SizedBox(height: 62,
          child: Row(children: [
            _tabBtn(0, Icons.home_outlined, ar ? 'الرئيسية' : 'Home'),
            _tabBtn(1, Icons.inventory_2_outlined, ar ? 'الطلبات' : 'Orders'),
            _tabBtn(2, Icons.route_outlined, ar ? 'الرحلات' : 'Trips'),
            _tabBtn(3, Icons.payments_outlined, ar ? 'النقد' : 'Cash'),
            _tabBtn(4, Icons.person_outline, ar ? 'حسابي' : 'Me'),
          ]))),
      ),
    );
  }
  Widget _tabBtn(int idx, IconData icon, String label) {
    final on = _tab == idx;
    return Expanded(child: InkWell(onTap: () => setState(() => _tab = idx),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: on ? UC.brown : UC.muted, size: 22),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
          color: on ? UC.brown : UC.muted,
          fontSize: 10, fontWeight: FontWeight.w800)),
      ])));
  }
}
