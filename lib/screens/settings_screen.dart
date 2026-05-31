import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _langs = const [];
  String _lang = DriverApi.instance.lang;
  bool _push = true;
  bool _bgLoc = false;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { _langs = await DriverApi.instance.languages(); } catch (_) {}
    final p = await SharedPreferences.getInstance();
    _push = p.getBool('driver_push_v1') ?? true;
    _bgLoc = p.getBool('driver_bgloc_v1') ?? false;
    if (mounted) setState(() => _loading = false);
  }

  void _pickLang() {
    final ar = DriverApi.instance.lang == 'ar';
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(child: Container(
        constraints: const BoxConstraints(maxHeight: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Text(ar ? 'اختر اللغة' : 'Select language', style: UT.h2)),
          const Divider(height: 1),
          Expanded(child: ListView(children: [
            for (final l in _langs.isNotEmpty ? _langs : [
              {'code':'en_US','name':'English','flag':'🇺🇸'},
              {'code':'ar_001','name':'العربية','flag':'🇰🇼'},
            ])
              ListTile(
                leading: Text((l['flag'] ?? '🌐').toString(),
                  style: const TextStyle(fontSize: 22)),
                title: Text((l['name'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text((l['code'] ?? '').toString(), style: UT.small),
                trailing: ((l['code'] ?? '').toString().toLowerCase().startsWith(_lang))
                  ? const Icon(Icons.check_circle, color: UC.success) : null,
                onTap: () async {
                  final code = (l['code'] ?? '').toString();
                  Navigator.pop(sheet);
                  DriverApi.instance.setLang(code);
                  setState(() => _lang = DriverApi.instance.lang);
                  try { await DriverApi.instance.savePreferences(appLang: code); } catch (_) {}
                }),
          ])),
        ]))));
  }

  Future<void> _toggle(String key, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    if (_loading) return const Scaffold(body: Center(child: USpinner()));
    final currentLang = _langs.firstWhere(
      (l) => (l['code'] ?? '').toString().toLowerCase().startsWith(_lang),
      orElse: () => {'name': _lang.toUpperCase(), 'flag': '🌐'});
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'الإعدادات' : 'Settings')),
      body: ListView(children: [
        _section(ar ? 'التفضيلات' : 'PREFERENCES'),
        _row(Icons.language, ar ? 'اللغة' : 'Language',
          trailing: Text('${currentLang['flag'] ?? '🌐'}  ${currentLang['name'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
          onTap: _pickLang),
        _toggleRow(Icons.notifications_outlined,
          ar ? 'الإشعارات' : 'Push notifications', _push,
          (v) { setState(() => _push = v); _toggle('driver_push_v1', v); }),
        _toggleRow(Icons.my_location,
          ar ? 'الموقع في الخلفية' : 'Background location', _bgLoc,
          (v) { setState(() => _bgLoc = v); _toggle('driver_bgloc_v1', v); }),
        _section(ar ? 'حول' : 'ABOUT'),
        _row(Icons.info_outline, ar ? 'الإصدار' : 'Version',
          trailing: const Text('v1.0.0 (1)', style: TextStyle(color: UC.muted))),
        _row(Icons.privacy_tip_outlined, ar ? 'الشروط والخصوصية' : 'Terms & privacy',
          onTap: () {}),
      ]),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(t, style: const TextStyle(fontSize: 10.5, color: UC.muted,
      fontWeight: FontWeight.w800, letterSpacing: .4)));

  Widget _row(IconData ic, String label, {Widget? trailing, VoidCallback? onTap}) {
    return Container(color: Colors.white, child: InkWell(onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(width: 30, height: 30, alignment: Alignment.center,
            decoration: BoxDecoration(color: UC.yellowFaint,
              borderRadius: BorderRadius.circular(9)),
            child: Icon(ic, color: UC.brown, size: 16)),
          const SizedBox(width: 11),
          Expanded(child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          if (trailing != null) trailing,
          if (onTap != null) const Padding(padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.chevron_right, color: UC.muted, size: 18)),
        ]))));
  }

  Widget _toggleRow(IconData ic, String label, bool v, ValueChanged<bool> onCh) {
    return _row(ic, label, trailing: Switch(value: v, onChanged: onCh, activeColor: UC.yellow));
  }
}
