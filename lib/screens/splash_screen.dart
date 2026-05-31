import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final api = DriverApi.instance;
    if (api.token.isEmpty || api.driver == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    // Touch /me to verify the session is still valid; if it fails, log out.
    try {
      await api.me();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      await api.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UC.yellow,
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 96, height: 96, alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Color(0x33000000),
                  blurRadius: 16, offset: Offset(0, 8))]),
          child: const Text('🚚', style: TextStyle(fontSize: 48)),
        ),
        const SizedBox(height: 18),
        const Text('Uellow Driver',
            style: TextStyle(color: UC.brown, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 22),
        const USpinner(size: 22),
      ])),
    );
  }
}
