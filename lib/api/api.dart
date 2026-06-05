// Single-file API client + models. ALL Map casts are null-safe (same
// rule as the customer app post-v2.0.21). The default base URL points
// to production; can be overridden via `--dart-define=UELLOW_BASE=...`.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kDriverApiBase = String.fromEnvironment(
  'UELLOW_BASE',
  defaultValue: 'https://www.uellow.com',
);

class DriverApi {
  DriverApi._();
  static final DriverApi instance = DriverApi._();

  String baseUrl = kDriverApiBase;
  String? _token;
  Driver? _driver;
  final ValueNotifier<String> langNotifier = ValueNotifier<String>('en');

  String get token => _token ?? '';
  Driver? get driver => _driver;
  String get lang => langNotifier.value;
  void setLang(String c) {
    final n = c.toLowerCase().startsWith('ar') ? 'ar' : 'en';
    if (langNotifier.value != n) langNotifier.value = n;
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('driver_token_v1');
    final lng = p.getString('driver_lang_v1');
    if (lng != null && lng.isNotEmpty) setLang(lng);
    final cached = p.getString('driver_me_v1');
    if (cached != null) {
      try { _driver = Driver.fromJson(jsonDecode(cached) as Map<String, dynamic>); } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    if (_token != null) await p.setString('driver_token_v1', _token!);
    else await p.remove('driver_token_v1');
    await p.setString('driver_lang_v1', langNotifier.value);
    if (_driver != null) {
      await p.setString('driver_me_v1', jsonEncode(_driver!.toJson()));
    } else {
      await p.remove('driver_me_v1');
    }
  }

  Map<String, String> _headers({bool auth = true, bool json = false}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
      'X-Lang': langNotifier.value,
    };
  }

  // ── Request helpers ────────────────────────────────────────────
  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final r = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 25));
    return _decode(r);
  }

  Future<Map<String, dynamic>> _post(String path, [Object? body]) async {
    final r = await http.post(Uri.parse('$baseUrl$path'),
        headers: _headers(json: true),
        body: body != null ? jsonEncode(body) : null)
      .timeout(const Duration(seconds: 30));
    return _decode(r);
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw DriverApiException('Bad response (${r.statusCode})', code: 'BAD_RESPONSE');
    }
  }

  Map<String, dynamic> _need(Map<String, dynamic> j) {
    if (j['success'] != true) {
      throw DriverApiException((j['error'] ?? 'Failed').toString(),
          code: (j['code'] ?? 'ERROR').toString());
    }
    return j;
  }

  // ── Auth ───────────────────────────────────────────────────────

  /// FCM push token → backend (mirrored onto the driver's partner so the
  /// fleet push engine can target it). No-op when not logged in.
  Future<void> registerPushToken(String deviceId, String token) async {
    if (_token == null || _token!.isEmpty) return;
    try {
      await _post('/api/driver/v1/me/push-token',
          {'push_token': token, 'device_id': deviceId});
    } catch (_) {}
  }

  Future<Driver> login(String identifier, String password) async {
    final j = _need(await _post('/api/driver/v1/auth/login', {
      'login': identifier, 'password': password,
      'platform': 'android', 'app_version': '1.0.0',
    }));
    final d = j['data'] as Map<String, dynamic>;
    _token = d['token'] as String?;
    _driver = Driver.fromJson(d['driver'] as Map<String, dynamic>);
    await _persist();
    return _driver!;
  }

  Future<void> logout() async {
    try { await _post('/api/driver/v1/auth/logout'); } catch (_) {}
    _token = null; _driver = null;
    await _persist();
  }

  Future<Driver> me() async {
    final j = _need(await _get('/api/driver/v1/me'));
    _driver = Driver.fromJson(((j['data'] as Map)['driver'] as Map).cast<String, dynamic>());
    await _persist();
    return _driver!;
  }

  Future<void> setStatus(String status) async {
    _need(await _post('/api/driver/v1/me/status', {'status': status}));
    if (_driver != null) _driver = _driver!.copyWith(status: status);
    await _persist();
  }

  // ── Dashboard ──────────────────────────────────────────────────
  Future<Dashboard> dashboard() async {
    final j = _need(await _get('/api/driver/v1/dashboard'));
    return Dashboard.fromJson((j['data'] as Map).cast<String, dynamic>());
  }

  // ── Orders ─────────────────────────────────────────────────────
  Future<List<OrderSummary>> orders({String? status, String? search, int page = 1}) async {
    final j = _need(await _get('/api/driver/v1/orders', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': '$page',
    }));
    final rows = (j['data'] as List).cast<Map>();
    return rows.map((m) => OrderSummary.fromJson(m.cast<String, dynamic>())).toList();
  }

  Future<OrderDetail> orderDetail(int id) async {
    final j = _need(await _get('/api/driver/v1/orders/$id'));
    return OrderDetail.fromJson(((j['data'] as Map)['order'] as Map).cast<String, dynamic>());
  }

  Future<void> orderPickup(int id) async { _need(await _post('/api/driver/v1/orders/$id/pickup')); }
  Future<void> orderDecline(int id, String reason) async {
    _need(await _post('/api/driver/v1/orders/$id/decline', {'reason': reason}));
  }
  Future<void> orderStart(int id) async { _need(await _post('/api/driver/v1/orders/$id/start')); }
  Future<void> orderConfirm(int id, {required Uint8List? proof, required Uint8List? signature,
      required double cash, required String notes}) async {
    _need(await _post('/api/driver/v1/orders/$id/confirm', {
      if (proof != null) 'proof_image_base64': base64Encode(proof),
      if (signature != null) 'signature_base64': base64Encode(signature),
      'cash_collected': cash, 'notes': notes,
    }));
  }
  Future<void> orderFail(int id, {required String reason, String details = '',
      bool returnToUellow = false}) async {
    _need(await _post('/api/driver/v1/orders/$id/fail', {
      'reason': reason, 'details': details, 'return_to_uellow': returnToUellow,
    }));
  }

  // ── Payment link ───────────────────────────────────────────────
  Future<PayLink> paylinkGenerate(int orderId, {String provider = 'upayments', double? amount}) async {
    final j = _need(await _post('/api/driver/v1/orders/$orderId/payment-link', {
      'provider': provider, if (amount != null) 'amount': amount,
    }));
    return PayLink.fromJson((j['data'] as Map).cast<String, dynamic>());
  }
  Future<PayStatus> paylinkStatus(int orderId) async {
    final j = _need(await _get('/api/driver/v1/orders/$orderId/payment-link/status'));
    return PayStatus.fromJson((j['data'] as Map).cast<String, dynamic>());
  }
  Future<void> paylinkShare(int orderId, String channel) async {
    _need(await _post('/api/driver/v1/orders/$orderId/payment-link/share', {'channel': channel}));
  }
  Future<void> paylinkCancel(int orderId) async {
    _need(await _post('/api/driver/v1/orders/$orderId/payment-link/cancel'));
  }

  // ── Trips ──────────────────────────────────────────────────────
  Future<List<Trip>> trips() async {
    final j = _need(await _get('/api/driver/v1/trips'));
    return ((j['data'] as List).cast<Map>())
        .map((m) => Trip.fromJson(m.cast<String, dynamic>())).toList();
  }
  Future<TripDetail> tripDetail(int id) async {
    final j = _need(await _get('/api/driver/v1/trips/$id'));
    return TripDetail.fromJson(((j['data'] as Map)['trip'] as Map).cast<String, dynamic>());
  }

  // ── Cash ───────────────────────────────────────────────────────
  Future<CashReady> cashReady() async {
    final j = _need(await _get('/api/driver/v1/cash/ready'));
    return CashReady.fromJson((j['data'] as Map).cast<String, dynamic>());
  }
  Future<Map<String, dynamic>> cashSubmit(List<int> orderIds, String ref) async {
    final j = _need(await _post('/api/driver/v1/cash/submit',
        {'order_ids': orderIds, 'carrier_ref': ref}));
    return (j['data'] as Map).cast<String, dynamic>();
  }
  Future<List<CashHistoryItem>> cashHistory() async {
    final j = _need(await _get('/api/driver/v1/cash/history'));
    return ((j['data'] as List).cast<Map>())
        .map((m) => CashHistoryItem.fromJson(m.cast<String, dynamic>())).toList();
  }

  // ── Notifications ──────────────────────────────────────────────
  Future<List<Notif>> notifs() async {
    final j = _need(await _get('/api/driver/v1/notifications'));
    return ((j['data'] as List).cast<Map>())
        .map((m) => Notif.fromJson(m.cast<String, dynamic>())).toList();
  }

  // ── Help ───────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> faq() async {
    final j = _need(await _get('/api/driver/v1/help/faq'));
    return ((j['data'] as List).cast<Map>()).map((m) => m.cast<String, dynamic>()).toList();
  }
  Future<void> chat(String body) async {
    _need(await _post('/api/driver/v1/help/chat', {'body': body}));
  }
  Future<void> emergency({double? lat, double? lng, String kind = 'unknown'}) async {
    _need(await _post('/api/driver/v1/help/emergency', {'lat': lat, 'lng': lng, 'kind': kind}));
  }

  // ── Preferences ────────────────────────────────────────────────
  Future<void> savePreferences({String? appLang, Map<String, dynamic>? notifPrefs}) async {
    final body = <String, dynamic>{};
    if (appLang != null) body['app_lang'] = appLang;
    if (notifPrefs != null) body['notif_prefs'] = notifPrefs;
    if (body.isEmpty) return;
    _need(await _post('/api/driver/v1/me/preferences', body));
  }

  // ── App meta ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> languages() async {
    final j = _need(await _get('/api/driver/v1/app/languages'));
    return ((j['data'] as List).cast<Map>()).map((m) => m.cast<String, dynamic>()).toList();
  }
}

class DriverApiException implements Exception {
  DriverApiException(this.message, {this.code = 'ERROR'});
  final String message, code;
  @override
  String toString() => 'DriverApiException($code): $message';
}

// ─── Models ─────────────────────────────────────────────────────

class BL { // bilingual
  final String en, ar;
  const BL(this.en, this.ar);
  factory BL.fromJson(dynamic v) {
    if (v is Map) return BL((v['en'] ?? '').toString(), (v['ar'] ?? v['en'] ?? '').toString());
    return BL((v ?? '').toString(), (v ?? '').toString());
  }
  String t(String l) => l == 'ar' ? (ar.isNotEmpty ? ar : en) : (en.isNotEmpty ? en : ar);
  Map<String, dynamic> toJson() => {'en': en, 'ar': ar};
}

class Money {
  final double amount;
  final String currency, symbol;
  final int digits;
  const Money({required this.amount, required this.currency,
      required this.symbol, required this.digits});
  factory Money.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return Money(
      amount: ((j['amount'] ?? 0) as num).toDouble(),
      currency: (j['currency'] ?? 'KWD').toString(),
      symbol: (j['symbol'] ?? 'KD').toString(),
      digits: (j['digits'] ?? 3) as int,
    );
  }
  String format([String? lang]) {
    final v = amount.toStringAsFixed(digits);
    final sym = (lang == 'ar')
      ? (const {'KD': 'د.ك', 'KWD': 'د.ك', 'SAR': 'ر.س', 'AED': 'د.إ',
                'EGP': 'ج.م', 'QAR': 'ر.ق', 'OMR': 'ر.ع.'}[symbol] ?? symbol)
      : symbol;
    return '$v $sym';
  }
  Map<String, dynamic> toJson() => {
    'amount': amount, 'currency': currency, 'symbol': symbol, 'digits': digits,
  };
}

class Driver {
  final int id;
  final String name, phone, vehicle, status, appLang;
  final String? photoUrl;
  final bool canSendPaymentLink;
  final Map<String, dynamic>? carrierCompany;
  const Driver({required this.id, required this.name, required this.phone,
      required this.vehicle, required this.status, required this.appLang,
      this.photoUrl, this.canSendPaymentLink = false, this.carrierCompany});
  factory Driver.fromJson(Map<String, dynamic> j) => Driver(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
    vehicle: (j['vehicle'] ?? '').toString(),
    status: (j['status'] ?? 'available').toString(),
    appLang: (j['app_lang'] ?? 'en_US').toString(),
    photoUrl: j['photo_url'] as String?,
    canSendPaymentLink: (j['can_send_payment_link'] ?? false) as bool,
    carrierCompany: (j['carrier_company'] as Map?)?.cast<String, dynamic>(),
  );
  Driver copyWith({String? status}) => Driver(
    id: id, name: name, phone: phone, vehicle: vehicle,
    status: status ?? this.status, appLang: appLang,
    photoUrl: photoUrl, canSendPaymentLink: canSendPaymentLink,
    carrierCompany: carrierCompany);
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone, 'vehicle': vehicle,
    'status': status, 'app_lang': appLang, 'photo_url': photoUrl,
    'can_send_payment_link': canSendPaymentLink, 'carrier_company': carrierCompany,
  };
}

class Dashboard {
  final int done, pending, failed, successRate;
  final Money cashHeld;
  final String status, driverName;
  final bool hasActiveTrip;
  final List<OrderSummary> next;
  const Dashboard({required this.done, required this.pending, required this.failed,
      required this.successRate, required this.cashHeld, required this.status,
      required this.driverName, required this.hasActiveTrip, required this.next});
  factory Dashboard.fromJson(Map<String, dynamic> j) {
    final k = (j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Dashboard(
      done: (k['done'] ?? 0) as int,
      pending: (k['pending'] ?? 0) as int,
      failed: (k['failed'] ?? 0) as int,
      successRate: (k['success_rate'] ?? 0) as int,
      cashHeld: Money.fromJson((j['cash_held'] as Map?)?.cast<String, dynamic>()),
      status: (j['status'] ?? 'available').toString(),
      driverName: (j['driver_name'] ?? '').toString(),
      hasActiveTrip: (j['has_active_trip'] ?? false) as bool,
      next: ((j['next'] as List?) ?? const [])
        .map((e) => OrderSummary.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }
}

class OrderSummary {
  final int id, lineId;
  final String name, status;
  final BL statusLabel;
  final String customer, addrShort;
  final Money amount;
  final String paymentMethod;
  final int itemCount;
  final String createdAt;
  const OrderSummary({required this.id, required this.lineId, required this.name,
      required this.status, required this.statusLabel, required this.customer,
      required this.addrShort, required this.amount, required this.paymentMethod,
      required this.itemCount, required this.createdAt});
  factory OrderSummary.fromJson(Map<String, dynamic> j) {
    // Dashboard returns customer/addr_short as flat strings; orders/list
    // returns them as nested {name, phone} / {short, street, ...}.
    // `as Map?` blows up on a String, so we have to type-check first.
    final cRaw = j['customer'];
    final aRaw = j['address'];
    final mRaw = j['amount'] ?? j['total'];
    final c = cRaw is Map ? cRaw.cast<String, dynamic>() : const <String, dynamic>{};
    final a = aRaw is Map ? aRaw.cast<String, dynamic>() : const <String, dynamic>{};
    return OrderSummary(
      id: (j['id'] ?? 0) as int,
      lineId: (j['line_id'] ?? 0) as int,
      name: (j['name'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      statusLabel: BL.fromJson(j['status_label']),
      customer: (c['name'] ?? (cRaw is String ? cRaw : '') ?? '').toString(),
      addrShort: (a['short'] ?? (j['addr_short'] is String ? j['addr_short'] : '') ?? '').toString(),
      amount: Money.fromJson(mRaw is Map ? mRaw.cast<String, dynamic>() : null),
      paymentMethod: (j['payment_method'] ?? '').toString(),
      itemCount: (j['item_count'] ?? 0) as int,
      createdAt: (j['created'] ?? '').toString(),
    );
  }
}

class OrderDetail extends OrderSummary {
  final List<OrderItem> items;
  final String notes, failureReason;
  final String? proofImageUrl, signatureUrl;
  final String customerPhone;
  final String addrStreet, addrStreet2, addrCity, addrCountry;
  final double addrLat, addrLng;
  final String payLinkStatus;
  final List<TimelineStep> timeline;
  const OrderDetail({required super.id, required super.lineId, required super.name,
      required super.status, required super.statusLabel, required super.customer,
      required super.addrShort, required super.amount, required super.paymentMethod,
      required super.itemCount, required super.createdAt,
      required this.items, required this.notes, required this.failureReason,
      this.proofImageUrl, this.signatureUrl,
      required this.customerPhone, required this.addrStreet, required this.addrStreet2,
      required this.addrCity, required this.addrCountry,
      required this.addrLat, required this.addrLng, required this.payLinkStatus,
      required this.timeline});
  factory OrderDetail.fromJson(Map<String, dynamic> j) {
    final base = OrderSummary.fromJson(j);
    final cRaw = j['customer'];
    final aRaw = j['address'];
    final c = cRaw is Map ? cRaw.cast<String, dynamic>() : const <String, dynamic>{};
    final a = aRaw is Map ? aRaw.cast<String, dynamic>() : const <String, dynamic>{};
    final tl = ((j['timeline'] as List?) ?? const [])
        .map((e) => TimelineStep.fromJson((e as Map).cast<String, dynamic>())).toList();
    return OrderDetail(
      id: base.id, lineId: base.lineId, name: base.name,
      status: base.status, statusLabel: base.statusLabel,
      customer: base.customer, addrShort: base.addrShort, amount: base.amount,
      paymentMethod: base.paymentMethod, itemCount: base.itemCount,
      createdAt: base.createdAt,
      items: ((j['items'] as List?) ?? const [])
        .map((e) => OrderItem.fromJson((e as Map).cast<String, dynamic>())).toList(),
      notes: (j['notes'] ?? '').toString(),
      failureReason: (j['failure_reason'] ?? '').toString(),
      proofImageUrl: j['proof_image_url'] as String?,
      signatureUrl: j['signature_url'] as String?,
      customerPhone: (c['phone'] ?? '').toString(),
      addrStreet: (a['street'] ?? '').toString(),
      addrStreet2: (a['street2'] ?? '').toString(),
      addrCity: (a['city'] ?? '').toString(),
      addrCountry: (a['country'] ?? '').toString(),
      addrLat: ((a['lat'] ?? 0) as num).toDouble(),
      addrLng: ((a['lng'] ?? 0) as num).toDouble(),
      payLinkStatus: (j['pay_link_status'] ?? 'none').toString(),
      timeline: tl,
    );
  }
}

class OrderItem {
  final int id;
  final BL name;
  final double qty;
  final Money price, subtotal;
  final String imageUrl;
  const OrderItem({required this.id, required this.name, required this.qty,
      required this.price, required this.subtotal, required this.imageUrl});
  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: (j['id'] ?? 0) as int,
    name: BL.fromJson(j['name']),
    qty: ((j['qty'] ?? 0) as num).toDouble(),
    price: Money.fromJson((j['price'] as Map?)?.cast<String, dynamic>()),
    subtotal: Money.fromJson((j['subtotal'] as Map?)?.cast<String, dynamic>()),
    imageUrl: (j['image_url'] ?? '').toString(),
  );
}

class TimelineStep {
  final String code;
  final BL label;
  final String when;
  const TimelineStep({required this.code, required this.label, required this.when});
  factory TimelineStep.fromJson(Map<String, dynamic> j) => TimelineStep(
    code: (j['code'] ?? '').toString(),
    label: BL.fromJson(j['label']),
    when: (j['when'] ?? '').toString(),
  );
}

class PayLink {
  final String link, provider, orderName;
  final Money amount;
  final Map<String, dynamic> customer;
  const PayLink({required this.link, required this.provider, required this.orderName,
      required this.amount, required this.customer});
  factory PayLink.fromJson(Map<String, dynamic> j) => PayLink(
    link: (j['link'] ?? '').toString(),
    provider: (j['provider'] ?? '').toString(),
    orderName: (j['order_name'] ?? '').toString(),
    amount: Money.fromJson((j['amount'] as Map?)?.cast<String, dynamic>()),
    customer: (j['customer'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

class PayStatus {
  final String payLinkStatus, provider, url;
  final bool isPaid;
  final Money paidAmount;
  const PayStatus({required this.payLinkStatus, required this.isPaid,
      required this.paidAmount, required this.provider, required this.url});
  factory PayStatus.fromJson(Map<String, dynamic> j) => PayStatus(
    payLinkStatus: (j['pay_link_status'] ?? 'none').toString(),
    isPaid: (j['is_paid'] ?? false) as bool,
    paidAmount: Money.fromJson((j['paid_amount'] as Map?)?.cast<String, dynamic>()),
    provider: (j['provider'] ?? '').toString(),
    url: (j['url'] ?? '').toString(),
  );
}

class Trip {
  final int id;
  final String name, state, date;
  final BL stateLabel;
  final int lineCount, doneCount, failedCount;
  const Trip({required this.id, required this.name, required this.state,
      required this.date, required this.stateLabel,
      required this.lineCount, required this.doneCount, required this.failedCount});
  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '').toString(),
    state: (j['state'] ?? '').toString(),
    date: (j['date'] ?? '').toString(),
    stateLabel: BL.fromJson(j['state_label']),
    lineCount: (j['line_count'] ?? 0) as int,
    doneCount: (j['done_count'] ?? 0) as int,
    failedCount: (j['failed_count'] ?? 0) as int,
  );
}

class TripDetail extends Trip {
  final List<TripStop> stops;
  final String notes;
  const TripDetail({required super.id, required super.name, required super.state,
      required super.date, required super.stateLabel, required super.lineCount,
      required super.doneCount, required super.failedCount,
      required this.stops, required this.notes});
  factory TripDetail.fromJson(Map<String, dynamic> j) {
    final t = Trip.fromJson(j);
    return TripDetail(
      id: t.id, name: t.name, state: t.state, date: t.date,
      stateLabel: t.stateLabel, lineCount: t.lineCount, doneCount: t.doneCount,
      failedCount: t.failedCount,
      stops: ((j['stops'] as List?) ?? const [])
        .map((e) => TripStop.fromJson((e as Map).cast<String, dynamic>())).toList(),
      notes: (j['notes'] ?? '').toString(),
    );
  }
}

class TripStop {
  final int lineId, orderId, sequence;
  final String orderName, customer, addrShort, status;
  final BL statusLabel;
  final Money amount;
  final double lat, lng;
  const TripStop({required this.lineId, required this.orderId, required this.sequence,
      required this.orderName, required this.customer, required this.addrShort,
      required this.status, required this.statusLabel, required this.amount,
      required this.lat, required this.lng});
  factory TripStop.fromJson(Map<String, dynamic> j) => TripStop(
    lineId: (j['line_id'] ?? 0) as int,
    orderId: (j['order_id'] ?? 0) as int,
    sequence: (j['sequence'] ?? 0) as int,
    orderName: (j['order_name'] ?? '').toString(),
    customer: (j['customer'] ?? '').toString(),
    addrShort: (j['addr_short'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    statusLabel: BL.fromJson(j['status_label']),
    amount: Money.fromJson((j['amount'] as Map?)?.cast<String, dynamic>()),
    lat: ((j['lat'] ?? 0) as num).toDouble(),
    lng: ((j['lng'] ?? 0) as num).toDouble(),
  );
}

class CashReady {
  final List<CashRow> items;
  final Money total;
  final int count;
  const CashReady({required this.items, required this.total, required this.count});
  factory CashReady.fromJson(Map<String, dynamic> j) => CashReady(
    items: ((j['items'] as List?) ?? const [])
      .map((e) => CashRow.fromJson((e as Map).cast<String, dynamic>())).toList(),
    total: Money.fromJson((j['total'] as Map?)?.cast<String, dynamic>()),
    count: (j['count'] ?? 0) as int,
  );
}

class CashRow {
  final int lineId, orderId;
  final String orderName, customer, addrShort, when;
  final Money amount;
  const CashRow({required this.lineId, required this.orderId,
      required this.orderName, required this.customer, required this.addrShort,
      required this.amount, required this.when});
  factory CashRow.fromJson(Map<String, dynamic> j) => CashRow(
    lineId: (j['line_id'] ?? 0) as int,
    orderId: (j['order_id'] ?? 0) as int,
    orderName: (j['order_name'] ?? '').toString(),
    customer: (j['customer'] ?? '').toString(),
    addrShort: (j['addr_short'] ?? '').toString(),
    amount: Money.fromJson((j['amount'] as Map?)?.cast<String, dynamic>()),
    when: (j['when'] ?? '').toString(),
  );
}

class CashHistoryItem {
  final int id;
  final String name, state, when;
  final BL stateLabel;
  final Money total, net;
  final int orderCount;
  const CashHistoryItem({required this.id, required this.name,
      required this.state, required this.when, required this.stateLabel,
      required this.total, required this.net, required this.orderCount});
  factory CashHistoryItem.fromJson(Map<String, dynamic> j) => CashHistoryItem(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '').toString(),
    state: (j['state'] ?? '').toString(),
    when: (j['when'] ?? '').toString(),
    stateLabel: BL.fromJson(j['state_label']),
    total: Money.fromJson((j['total'] as Map?)?.cast<String, dynamic>()),
    net: Money.fromJson((j['net'] as Map?)?.cast<String, dynamic>()),
    orderCount: (j['order_count'] ?? 0) as int,
  );
}

class Notif {
  final int id;
  final String title, body, category, when;
  final bool isNew;
  final int? orderId;
  const Notif({required this.id, required this.title, required this.body,
      required this.category, required this.when, required this.isNew, this.orderId});
  factory Notif.fromJson(Map<String, dynamic> j) => Notif(
    id: (j['id'] ?? 0) as int,
    title: (j['title'] ?? '').toString(),
    body: (j['body'] ?? '').toString(),
    category: (j['category'] ?? 'ops_message').toString(),
    when: (j['when'] ?? '').toString(),
    isNew: (j['is_new'] ?? false) as bool,
    orderId: j['order_id'] as int?,
  );
}
