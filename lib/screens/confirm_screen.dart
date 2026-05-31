import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.orderId, this.defaultCash = 0});
  final int orderId;
  final double defaultCash;
  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  Uint8List? _proofBytes;
  final SignatureController _sig = SignatureController(
    penStrokeWidth: 3, penColor: UC.brown, exportBackgroundColor: Colors.white);
  late final TextEditingController _cash;
  late final TextEditingController _notes;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _cash = TextEditingController(text: widget.defaultCash.toStringAsFixed(3));
    _notes = TextEditingController();
  }

  @override
  void dispose() { _sig.dispose(); _cash.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _pickPhoto(ImageSource src) async {
    final picker = ImagePicker();
    final p = await picker.pickImage(source: src, maxWidth: 1280, maxHeight: 1280, imageQuality: 85);
    if (p == null) return;
    final bytes = await File(p.path).readAsBytes();
    setState(() => _proofBytes = bytes);
  }

  void _photoSheet() {
    final ar = DriverApi.instance.lang == 'ar';
    showModalBottomSheet(context: context, builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_outlined),
          title: Text(ar ? 'التقط صورة' : 'Take photo'),
          onTap: () { Navigator.pop(sheet); _pickPhoto(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library_outlined),
          title: Text(ar ? 'من المعرض' : 'From gallery'),
          onTap: () { Navigator.pop(sheet); _pickPhoto(ImageSource.gallery); }),
      ])));
  }

  Future<void> _submit() async {
    final ar = DriverApi.instance.lang == 'ar';
    if (_proofBytes == null) {
      setState(() => _err = ar ? 'صورة الإثبات مطلوبة' : 'Proof photo is required');
      return;
    }
    if (_sig.isEmpty) {
      setState(() => _err = ar ? 'توقيع العميل مطلوب' : 'Customer signature is required');
      return;
    }
    final cash = double.tryParse(_cash.text.trim()) ?? 0;
    setState(() { _busy = true; _err = null; });
    try {
      final sigBytes = await _sig.toPngBytes();
      await DriverApi.instance.orderConfirm(widget.orderId,
        proof: _proofBytes, signature: sigBytes,
        cash: cash, notes: _notes.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? '✓ تم التسليم بنجاح' : '✓ Delivered successfully')));
    } catch (e) {
      setState(() { _busy = false; _err = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = DriverApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'تأكيد التسليم' : 'Confirm delivery')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _lbl(ar ? 'صورة الإثبات (إجباري)' : 'Proof photo (required)'),
        if (_proofBytes != null) AspectRatio(aspectRatio: 1.4,
          child: ClipRRect(borderRadius: BorderRadius.circular(11),
            child: Image.memory(_proofBytes!, fit: BoxFit.cover))),
        const SizedBox(height: 6),
        OutlinedButton.icon(onPressed: _photoSheet,
          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
          label: Text(_proofBytes == null
            ? (ar ? 'إضافة صورة' : 'Add photo')
            : (ar ? 'تغيير الصورة' : 'Change photo'))),
        const SizedBox(height: 14),
        _lbl(ar ? 'توقيع العميل (إجباري)' : 'Customer signature (required)'),
        Container(
          height: 140,
          decoration: BoxDecoration(color: Colors.white,
            border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(11)),
          child: Signature(controller: _sig, backgroundColor: Colors.white)),
        const SizedBox(height: 6),
        Row(children: [
          TextButton.icon(onPressed: _sig.clear,
            icon: const Icon(Icons.clear, size: 14),
            label: Text(ar ? 'مسح' : 'Clear')),
        ]),
        const SizedBox(height: 6),
        _lbl(ar ? 'النقد المستلم' : 'Cash collected'),
        TextField(controller: _cash,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'KD')),
        const SizedBox(height: 14),
        _lbl(ar ? 'ملاحظات (اختياري)' : 'Notes (optional)'),
        TextField(controller: _notes, minLines: 2, maxLines: 4,
          decoration: InputDecoration(
            hintText: ar ? 'مثلاً: تم التسليم للجار' : 'e.g. handed to neighbor')),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: UC.dangerBg,
              borderRadius: BorderRadius.circular(8)),
            child: Text(_err!, style: const TextStyle(
              color: UC.dangerDk, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: UC.success, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          icon: _busy
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check, size: 18),
          label: Text(ar ? 'تم التسليم' : 'Mark delivered',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)))),
      ]),
    );
  }

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10.5,
      fontWeight: FontWeight.w800, color: UC.muted, letterSpacing: .4)));
}
