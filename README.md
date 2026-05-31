# Uellow Driver

Mobile companion to the **delivery_carrier_portal** for the Uellow marketplace. Mirrors every feature drivers have in the web portal, but native — camera proof, signature pad, OS-native navigation, instant payment-link sharing over WhatsApp / SMS / QR.

## What's inside

| Path | Purpose |
| --- | --- |
| `lib/` | Flutter app — 14 screens, bilingual EN+AR with RTL, KW flag for Arabic. |
| `lib/api/api.dart` | Single-file API client + null-safe models. Talks to `/api/driver/v1/*`. |
| `lib/screens/` | One file per screen. `paylink_screen.dart` covers the full Send-payment-link flow (UPayments → Odoo fallback, WhatsApp/SMS/QR/copy/share, 8-second auto-poll for payment status). |
| `odoo_backend/` | The companion Odoo 18 module `uellow_driver_api`. Drop into your Odoo addons path and `-i uellow_driver_api`. |
| `MOCKUP.html` | The original interactive HTML mockup. Open in a browser. |
| `android/` | Default Flutter Android scaffold + INTERNET / CAMERA / LOCATION / CALL permissions. |

## Building

```bash
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Hardened patterns

Reused every lesson from the customer Uellow app:

- `flutter_localizations` + 3 delegates from day one (avoids the Arabic Material crash that hit the customer app at v2.0.17).
- `BL.fromJson` / `Money.fromJson` / `OrderItem.fromJson` etc. cast every `Map?` defensively (the bug that hit the customer app at v2.0.21).
- Reactive language via `ValueListenableBuilder` over `DriverApi.langNotifier` — flipping AR/EN re-flows the whole tree without a hot-restart.
- All bearer-token plumbing lives in a separate `driver.session` table, isolated from `mobile.session`, so an auth bug in one app cannot disable the other.

## Backend endpoints

All under `/api/driver/v1/*`:

```
auth/login | auth/logout | me | me/status | me/push-token | me/preferences
dashboard
orders?status=&search= | orders/<id>
orders/<id>/{pickup,decline,start,confirm,fail,return}
orders/<id>/payment-link | /payment-link/status | /payment-link/share | /payment-link/cancel
trips | trips/<id> | trips/<id>/reorder
cash/ready | cash/submit | cash/history | cash/<id>
notifications | notifications/<id>/read
help/faq | help/chat | help/emergency
app/languages | app/version
```

Same audit trail as the portal — every order action posts a chatter message; every payment link write flows through the same `pay_link_status`/`pay_link_url`/`pay_link_sent_by`/`pay_link_sent_date`/`pay_link_provider` fields the portal already uses.
