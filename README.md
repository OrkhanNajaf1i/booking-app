# booking-app (Flutter)

Booking Platform-un mobil tətbiqi. **Tək kod bazası, iki auditoriya** — login-dən
sonra JWT-dəki rola görə ekranlar dəyişir:

| Rol | Alt naviqasiya |
|---|---|
| `customer` | Bron et · Bronlarım · Bildiriş |
| `provider_owner`, `staff`, `solo_practitioner` | Sorğular · Qrafik · Bildiriş |

---

## Nə lazımdır

- Flutter **3.27+** (Dart 3.6+) — `withValues`, `CardThemeData` üçün
- İşləyən `booking-service` backend-i

Bu maşında Flutter quraşdırılmayıb; qurduqdan sonra:

```bash
flutter doctor
```

## Başlatma

```bash
cd booking-app
flutter pub get

# Android emulyatoru — 10.0.2.2 host maşını göstərir
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1

# Fiziki cihaz — kompüterin LAN IP-si
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080/api/v1

# Deploy olunmuş backend (default)
flutter run
```

`API_BASE_URL` verilməsə `AppConfig`-dəki Render URL-i işlənir.
WebSocket ünvanı avtomatik çıxarılır: `http→ws`, `https→wss`.

> `flutter create . --platforms=android,ios` işlədin ki, `android/` və `ios/`
> qovluqları yaransın — bu repoda yalnız `lib/` və `pubspec.yaml` var.

---

## Struktur

```
lib/
├── main.dart                     Sessiyaya görə Login ↔ HomeShell
├── core/
│   ├── config/app_config.dart    --dart-define ilə gələn ayarlar
│   ├── api/
│   │   ├── api_client.dart       Dio + 401 → refresh → təkrar
│   │   └── token_storage.dart    Token saxlanışı + JWT claim oxuma
│   ├── realtime/realtime_service.dart   WebSocket + avtomatik reconnect
│   ├── push/push_service.dart    FCM (opsional — içindəki addımlara bax)
│   └── theme/app_theme.dart      Açıq/qaranlıq mövzu
├── models/                       Booking, Availability, Notification, Staff
├── repositories/repositories.dart   Bütün API çağırışları
├── state/app_state.dart          Auth / Notification / Booking controller-ləri
└── features/
    ├── auth/login_screen.dart
    ├── customer/
    │   ├── book_screen.dart      Biznes → mütəxəssis → xidmət → tarix → saat
    │   ├── my_bookings_screen.dart   Təklifə "Qəbul et / İmtina"
    │   └── widgets/booking_widgets.dart
    ├── provider/
    │   ├── requests_screen.dart  Təsdiqlə · Başqa vaxt təklif et · Ləğv
    │   └── schedule_screen.dart  İş saatı · nahar fasiləsi · slot addımı
    ├── notifications/
    └── shell/home_shell.dart     Rola görə naviqasiya
```

---

## Realtime necə işləyir

1. Login-dən sonra `RealtimeService.start()` WebSocket-i açır:
   `GET /api/v1/ws?token=<access_token>`
2. Backend hadisə göndərəndə:
   - `NotificationController` bildirişi siyahının başına qoyur (yenidən sorğu yoxdur)
   - `BookingController` `booking.*` hadisələrində siyahını yeniləyir
3. Bağlantı qopanda 1s → 2s → 5s → 10s → 30s gecikmə ilə özü qoşulur.
4. Tətbiq arxa plandan qayıdanda `HomeShell` dərhal `reconnectNow()` çağırır.

AppBar-dakı bulud ikonu bağlantının canlı olub-olmadığını göstərir.

---

## Bron axını (müştəri)

```
GET  /public/businesses                    → biznes seç
GET  /public/businesses/{id}/staff         → mütəxəssis seç
GET  /public/businesses/{id}/services      → xidmət seç (opsional)
GET  /public/availability?...              → boş saatlar
POST /customers/self                       → öz müştəri kartını tap/yarat
POST /bookings                             → bron
```

`/public/*` login tələb etmir — istifadəçi qeydiyyatdan keçmədən qiymətlərə
və boş vaxtlara baxa bilir. Bron üçün isə token lazımdır.

Boş saatlar **heç vaxt tətbiqdə hesablanmır** — iş qrafiki, nahar fasiləsi,
seçim addımı və mövcud bronlar backend-də tətbiq olunur. Tətbiq yalnız
gələn nəticəni göstərir.

---

## Push bildirişləri (opsional)

WebSocket yalnız tətbiq açıq olanda işləyir. Telefon bağlı olanda bildiriş
gəlməsi üçün FCM lazımdır — addımlar `lib/core/push/push_service.dart`
faylının başındadır. Konfiqurasiya edilməsə backend push-u sadəcə söndürür,
qalan hər şey işləyir.
