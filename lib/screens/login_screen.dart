import 'dart:async';

import 'package:flutter/material.dart';
import '../api/api.dart';
import '../fcm_service.dart';
import '../theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  String? _err;
  bool _showPw = false;

  @override
  void dispose() { _id.dispose(); _pw.dispose(); super.dispose(); }

  Future<void> _login() async {
    final ar = DriverApi.instance.lang == 'ar';
    if (_id.text.trim().isEmpty || _pw.text.trim().isEmpty) {
      setState(() => _err = ar ? 'الهاتف وكلمة المرور مطلوبان'
                                : 'Phone and password are required');
      return;
    }
    setState(() { _busy = true; _err = null; });
    try {
      await DriverApi.instance.login(_id.text.trim(), _pw.text.trim());
      unawaited(FcmService.instance.register());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on DriverApiException catch (e) {
      setState(() { _busy = false; _err = e.message; });
    } catch (e) {
      setState(() { _busy = false; _err = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      body: SizedBox.expand(child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFE066), UC.yellow, Color(0xFFC99000)])),
        child: SafeArea(child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 30),
            Center(child: Container(width: 84, height: 84, alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Color(0x33000000),
                    blurRadius: 14, offset: Offset(0, 6))]),
              child: const Text('🚚', style: TextStyle(fontSize: 38)))),
            const SizedBox(height: 18),
            Text(ar ? 'سائق Uellow' : 'Uellow Driver',
              textAlign: TextAlign.center,
              style: const TextStyle(color: UC.brown, fontSize: 24,
                fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(ar ? 'سجّل دخولك لبدء وردية العمل'
                    : 'Sign in to start your shift',
              textAlign: TextAlign.center,
              style: const TextStyle(color: UC.brownSoft, fontSize: 13)),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x29412402),
                    blurRadius: 30, offset: Offset(0, 12))]),
              child: Column(children: [
                TextField(controller: _id, keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: ar ? 'الهاتف أو البريد' : 'Phone or email',
                    prefixIcon: const Icon(Icons.phone, size: 18))),
                const SizedBox(height: 10),
                TextField(controller: _pw, obscureText: !_showPw,
                  decoration: InputDecoration(
                    labelText: ar ? 'كلمة المرور' : 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPw = !_showPw),
                      icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility,
                        size: 18)))),
                if (_err != null) Padding(padding: const EdgeInsets.only(top: 10),
                  child: Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: UC.dangerBg,
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(_err!, style: const TextStyle(
                      color: UC.dangerDk, fontWeight: FontWeight.w700)))),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _busy ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UC.brown,
                    foregroundColor: UC.yellowSoft,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                  child: _busy
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2,
                          color: UC.yellowSoft))
                    : Text(ar ? 'تسجيل الدخول' : 'Sign in',
                        style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w900)))),
              ])),
            const SizedBox(height: 18),
            Center(child: Text(ar ? 'تواجه مشكلة؟ تواصل مع العمليات'
                                  : 'Trouble signing in? Contact ops',
              style: const TextStyle(color: UC.brownSoft, fontSize: 12,
                fontWeight: FontWeight.w600))),
          ]),
        ))),
      )),
    );
  }
}
