// =============================================================================
// Uellow Driver — app root.
// Same defensive patterns we learned the hard way in the customer app:
//   • flutter_localizations + 3 delegates (or Material widgets crash in AR).
//   • Reactive lang via ValueListenableBuilder over DriverApi.langNotifier.
//   • Directionality wrap in `builder:` for instant RTL toggle.
// =============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api.dart';
import 'fcm_service.dart';
import 'theme/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/confirm_screen.dart';
import 'screens/fail_screen.dart';
import 'screens/paylink_screen.dart';
import 'screens/trip_detail_screen.dart';
import 'screens/cash_screen.dart';
import 'screens/cash_history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/help_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DriverApi.instance.init();
  unawaited(FcmService.instance.init());
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: DriverApi.instance.langNotifier,
      builder: (context, lang, _) {
        final isAr = lang == 'ar';
        return MaterialApp(
          title: 'Uellow Driver',
          debugShowCheckedModeBanner: false,
          theme: uellowDriverTheme(),
          locale: isAr ? const Locale('ar') : const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
          initialRoute: '/',
          routes: {
            '/':              (_) => const SplashScreen(),
            '/login':         (_) => const LoginScreen(),
            '/home':          (_) => const HomeScreen(),
            '/cash':          (_) => const CashScreen(),
            '/cash-history':  (_) => const CashHistoryScreen(),
            '/profile':       (_) => const ProfileScreen(),
            '/settings':      (_) => const SettingsScreen(),
            '/notifications': (_) => const NotificationsScreen(),
            '/help':          (_) => const HelpScreen(),
          },
          onGenerateRoute: (settings) {
            final args = (settings.arguments as Map?) ?? const {};
            switch (settings.name) {
              case '/order':
                return MaterialPageRoute(settings: settings,
                    builder: (_) => OrderDetailScreen(orderId: args['id'] as int? ?? 0));
              case '/confirm':
                return MaterialPageRoute(settings: settings,
                    builder: (_) => ConfirmScreen(orderId: args['id'] as int? ?? 0,
                      defaultCash: (args['cash'] as num?)?.toDouble() ?? 0));
              case '/fail':
                return MaterialPageRoute(settings: settings,
                    builder: (_) => FailScreen(orderId: args['id'] as int? ?? 0));
              case '/paylink':
                return MaterialPageRoute(settings: settings,
                    builder: (_) => PaylinkScreen(orderId: args['id'] as int? ?? 0,
                      orderName: args['name'] as String? ?? '',
                      defaultAmount: (args['amount'] as num?)?.toDouble() ?? 0,
                      customerPhone: args['phone'] as String? ?? ''));
              case '/trip':
                return MaterialPageRoute(settings: settings,
                    builder: (_) => TripDetailScreen(tripId: args['id'] as int? ?? 0));
            }
            return null;
          },
        );
      },
    );
  }
}
