# Deploy

Eyni Flutter kod bazası üç yerə çıxır: **Android**, **iOS** və **web**.
Müştəri tətbiq yükləmək istəməsə, brauzerdən eyni funksionallığı alır.

---

## Web (müştəri saytı)

Flutter web statik fayllar çıxarır — heç bir Node/server tələb olunmur.

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://booking-service-sld9.onrender.com/api/v1
```

Nəticə `build/web/` qovluğundadır. Onu istənilən statik hostinqə qoyun.

> `API_BASE_URL` **build zamanı** kodun içinə yazılır. Backend ünvanı
> dəyişsə, yenidən build etmək lazımdır.

### Vacib: SPA fallback

Tətbiq tək səhifəlidir. Host bilinməyən yolları `index.html`-ə
yönləndirməsə, səhifə yeniləndikdə 404 alınır. Aşağıdakı konfiqurasiyalar
bunu həll edir.

### Netlify

`netlify.toml` repo kökündədir. Netlify-a repo-nu bağlayın, qalanı avtomatikdir.

### Vercel

`vercel.json` repo kökündədir.

```bash
npm i -g vercel
flutter build web --release --dart-define=API_BASE_URL=https://...
vercel deploy build/web --prod
```

### Render (Static Site)

Render panelində **New → Static Site**:

| Sahə | Dəyər |
|---|---|
| Build Command | `flutter build web --release --dart-define=API_BASE_URL=https://...` |
| Publish Directory | `build/web` |
| Rewrite Rule | `/*` → `/index.html` (Action: Rewrite) |

> Render-in standart image-ində Flutter yoxdur. Ən sadə yol: build-i
> GitHub Actions-da edib hazır `build/web`-i deploy etmək (aşağıdakı
> workflow), ya da Docker istifadə etmək.

### GitHub Pages

Alt qovluqda yerləşirsə `--base-href` vermək lazımdır:

```bash
flutter build web --release --base-href /booking-app/ --dart-define=API_BASE_URL=https://...
```

---

## Backend tərəfdə lazım olan ayar

Web versiya brauzerdən işlədiyi üçün WebSocket origin yoxlamasına düşür.
Backend-də saytın ünvanını icazə siyahısına əlavə edin:

```
APP_WS_ALLOWED_ORIGINS=https://randevu.example.com,https://admin.example.com
```

Boş buraxılsa bütün origin-lərə icazə verilir — bu, yalnız development
üçün uyğundur.

---

## Mobil

### Android

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://booking-service-sld9.onrender.com/api/v1
```

`build/app/outputs/bundle/release/app-release.aab` → Play Console.

İmzalama üçün `android/key.properties` və keystore lazımdır — bunlar
`.gitignore`-dadır və repo-ya düşməməlidir.

### iOS

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://...
```

macOS + Xcode tələb olunur.

---

## Push bildirişləri (opsional)

WebSocket yalnız tətbiq açıq olanda işləyir. Bağlı olanda bildiriş
çatması üçün FCM lazımdır — addımlar `lib/core/push/push_service.dart`
faylının başındadır. Konfiqurasiya edilməsə backend push-u söndürür,
qalan hər şey işləyir.
