# PCHAT App

**PCHAT** ওয়েবসাইটকে (`https://pchatshepu.vercel.app/`) একটি নেটিভ ডেস্কটপ ও মোবাইল অ্যাপে পরিণত করার জন্য Flutter দিয়ে লেখা একটি হালকা, প্রোডাকশন-রেডি **URL-to-App** র‍্যাপার।

একই কোডবেস থেকে **Android (APK)**, **Windows** এবং **Linux** — তিনটি প্ল্যাটফর্মের জন্য অ্যাপ তৈরি হয়।

---

## ১. অ্যাপটি কী করে

- চালু হওয়ামাত্র সরাসরি PCHAT ওয়েবসাইট লোড হয় — কোনো স্প্ল্যাশ স্ক্রিন, বাটন বা মেনু নেই।
- **Windows ও Linux-এ চালু হওয়ামাত্র বর্ডারলেস ম্যাক্সিমাইজড** — OS-এর কোনো টাইটেল বার বা উইন্ডো বাটন থাকে না। Android স্বাভাবিকভাবেই ফুলস্ক্রিন।
- **OS-এর টাস্কবার/প্যানেল দেখা যায় ও ব্যবহার করা যায়** — উইন্ডোটি ফুলস্ক্রিন নয়, বরং *work area* (টাস্কবার বাদ দিয়ে বাকি স্ক্রিন) জুড়ে ম্যাক্সিমাইজড থাকে (বিভাগ ৮)।
- উপরে একটা **৩২ পিক্সেলের স্বচ্ছ বার** (শুধু Windows/Linux): বাঁয়ে **Refresh**, ডানে **minimize** ও **close**।
- পেজ লোড হওয়ার সময় স্ক্রিনের মাঝে ছোট করে একটি **APNG লোডিং অ্যানিমেশন** দেখায় (`assets/animations/animation.apng`), কোনো সাধারণ প্রোগ্রেস-বার নয়।
- সাইটের সব ফিচার (ডিজাইন, লগইন পেজ, ইন্টারঅ্যাকশন, localStorage/IndexedDB persistence, WebSocket, QR স্ক্যানার, ভয়েস/ভিডিও কল) WebView-এর ভেতরেই চলে।
- বাইরের যেকোনো লিংক (Google Sheets / Drive, `mailto:`, `tel:` ইত্যাদি) স্বয়ংক্রিয়ভাবে সিস্টেমের আসল ব্রাউজার/অ্যাপে খোলে।
- **Google দিয়ে লগইন** বাটনটির জন্য অ্যাপ নিজেই একটি popup WebView খোলে, যাতে লগইন শেষে token সাইটে ফেরত আসে (বিভাগ ৬)।
- একই সাইটের লিংক অ্যাপের ভেতরেই থাকে — তাই ইউজার অ্যাপ থেকে বেরিয়ে যায় না।
- **নেট থাকা অবস্থায় সাইট লোড ব্যর্থ হলে** আলাদা **"PCHAT is unreachable"** নোটিশ + ইঞ্জিনের নিজের এরর-বার্তা + **Try again** দেখায় (এখানে "connection lost" বলা ভুল হতো, কারণ নেট ঠিকই আছে)।
- **ডিভাইসের নেট একেবারে না থাকলে / বিচ্ছিন্ন হয়ে গেলে** সাথে সাথে **"Connection Lost" আর্টওয়ার্ক** (ডেস্কটপে চওড়া, ফোনে লম্বা ছবি) + নিচে ছবির রঙের সাথে মেলা **Try again** বাটন দেখায়, সাথে অটো-রিকানেক্ট — পেজ আগে লোড হয়ে থাকলেও।
- Android-এর ব্যাক বাটন/জেসচার আগে পেজের history-তে পিছনে যায়, history শেষ হলে অ্যাপ বন্ধ হয়।
- Android-এ `<input type="file">` এর জন্য নেটিভ ফাইল পিকার ব্যবহার হয়।

---

## ২. আর্কিটেকচার (এক নজরে)

প্রতিটি প্ল্যাটফর্মে তার **নিজস্ব নেটিভ ইঞ্জিন** ব্যবহার করা হয়েছে — কোনো ভারী Chromium বান্ডল করা হয়নি, তাই অ্যাপ হালকা ও দ্রুত:

| প্ল্যাটফর্ম | WebView ইঞ্জিন | প্যাকেজ |
|---|---|---|
| Android | System WebView (Chromium) | `webview_all` → `webview_all_android` |
| Windows | WebView2 (Edge/Chromium) | `webview_all` → `webview_all_windows` |
| Linux | WebKitGTK 4.1 | `webview_all` → `webview_all_linux` |

```
lib/
├── main.dart                     # অ্যাপ এন্ট্রি + ডার্ক থিম
└── src/
    ├── app_config.dart           # target URL, অনুমোদিত host, ব্রিজের নাম
    ├── url_policy.dart           # কোন URL অ্যাপে থাকবে / বাইরে যাবে (pure logic, টেস্ট করা)
    ├── pchat_screen.dart         # মূল স্ক্রিন: WebView + navigation + permission + offline
    ├── platform_setup.dart       # প্ল্যাটফর্ম-ভিত্তিক ইঞ্জিন সেটিংস, permission, file picker
    ├── popup_bridge.dart         # window.open / target="_blank" কে Dart-এ পাঠানোর JS
    ├── google_auth.dart          # Google sign-in popup (দ্বিতীয় WebView) + উত্তর relay
    ├── window_controls.dart      # Windows/Linux-এর উপরের স্বচ্ছ বার + window মেথড চ্যানেল
    └── status_overlay.dart       # লোডিং APNG + Offline/Error আর্টওয়ার্ক ও Try again
assets/
├── animations/animation.apng     # লোডিং অ্যানিমেশন (AssetImage হিসেবে বান্ডল করা)
├── icon/icon.png                 # অ্যাপ আইকনের একমাত্র সোর্স (তিন প্ল্যাটফর্মেরই)
└── images/
    ├── c_lost_desktop.png        # অফলাইন আর্টওয়ার্ক — চওড়া (Linux/Windows)
    └── c_lost_phone.png          # অফলাইন আর্টওয়ার্ক — লম্বা (Android)
tool/
├── app_icons.sh                  # icon.png থেকে Android/Windows/Linux আইকন বানায়
├── package_release.sh            # Linux + Android-এর সব প্যাকেজ একবারে বানিয়ে dist/-এ রাখে
└── build_windows.ps1             # একই কাজ Windows-এ (exe + zip)
```

**নিরাপত্তার সীমারেখা:** শুধুমাত্র `pchatshepu.vercel.app` হোস্ট অ্যাপের ভেতরে লোড হয় (`lib/src/app_config.dart`)। বাকি সব host সিস্টেম ব্রাউজারে যায় — ব্যতিক্রম কেবল Google-এর sign-in popup, যা নিজস্ব আলাদা WebView-তে চলে (বিভাগ ৬)। `javascript:`, `file:`, `content:` স্কিম ব্লক করা।

---

## ৩. প্রয়োজনীয়তা

### সব প্ল্যাটফর্মের জন্য
- Flutter **stable 3.47+** (Dart 3.13+)
- `flutter doctor` সবুজ (যে প্ল্যাটফর্মের জন্য বিল্ড করবেন সেটি)
- **ImageMagick** — শুধু আইকন নতুন করে বানাতে হলে (`tool/app_icons.sh`, বিভাগ ৫ দেখুন)। অ্যাপ চালানোর বা বিল্ড করার জন্য লাগে না।

### Android
- Android SDK + **JDK 17 বা তার উপরে** (শুধু JRE নয় — `javac` থাকতেই হবে; Arch-এ `sudo pacman -S jdk-openjdk`)
- `flutter doctor --android-licenses` একবার চালিয়ে নিন
- **minSdk 24** (Android 7.0) — ইতিমধ্যেই সেট করা আছে

### Windows
- Windows 10 1809 বা Windows 11
- Visual Studio 2022 — **"Desktop development with C++"** workload
- **WebView2 Runtime** (Windows 11 ও আধুনিক Windows 10-এ আগে থেকেই থাকে; না থাকলে Microsoft-এর Evergreen Bootstrapper ইনস্টল করুন)

### Linux
```bash
# Arch / Manjaro
sudo pacman -S clang cmake ninja pkgconf gtk3 webkit2gtk-4.1

# Ubuntu / Debian
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev

# Fedora
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel webkit2gtk4.1-devel
```
> Wayland সেশনে থাকলে XWayland চালু থাকা দরকার (সাধারণত ডিফল্টেই থাকে)।
> **চালানোর সময়** দরকার: `webkit2gtk-4.1`, `gtk3`, এবং GStreamer-এর `gst-plugins-base` +
> `gst-plugins-good` (`sudo pacman -S webkit2gtk-4.1 gtk3 gst-plugins-base gst-plugins-good`)।
> `gst-plugins-good` না থাকলে WebKit-এর **web process** পেজে সাউন্ড বাজাতে গিয়ে `SIGABRT` করে —
> অর্থাৎ অ্যাপ খোলার ১০-২০ সেকেন্ড পরেই "ক্র্যাশ" দেখায়। ইনস্টলার/admin ছাড়া সমাধানের জন্য
> ওই একটি প্লাগিন (`libgstautodetect.so`) অ্যাপের পাশে বান্ডল করা থাকে, `run.sh` শুধু দরকার হলে
> সেটি ব্যবহার করে।
> `dist/linux/…tar.gz`-এ দেওয়া `run.sh` দিয়ে চালালে লাইব্রেরি না থাকলে সেটি চুপচাপ crash না করে
> নিজেই বলে দেবে কোন প্যাকেজ ইনস্টল করতে হবে।

---

## ৪. বিল্ড ও রান

```bash
git clone <your-repo> pchat_app
cd pchat_app
flutter pub get
```

### Android — APK
```bash
# ডেভাইস/এমুলেটরে চালাতে
flutter run -d android

# Release APK (সব ABI)
flutter build apk --release
#  → build/app/outputs/flutter-apk/app-release.apk

# শুধু arm64 (ফাইল সাইজ ছোট)
flutter build apk --release --target-platform android-arm64

# প্লে-স্টোরের জন্য App Bundle
flutter build appbundle --release
#  → build/app/outputs/bundle/release/app-release.aab
```

> ⚠️ **পাবলিশ করার আগে অবশ্যই নিজের keystore দিয়ে সাইন করুন।** `android/app/build.gradle.kts`-এ আপাতত ডিবাগ key দিয়ে সাইন হয় (যাতে `flutter build apk --release` সাথে সাথে কাজ করে)। নিচে নিয়মিত keytool + signingConfig যোগ করে নিন।

> 💾 প্রথম `flutter build apk --release`-এ Gradle Android SDK-র সাথে **NDK (~১ GB)** নামায় (release-এ engine-এর `.so` ফাইল strip করতে হয়) — একবারই নামবে।

<details>
<summary>Release signing সেটআপ</summary>

```bash
keytool -genkey -v -keystore ~/pchat-upload.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

`android/key.properties`:
```properties
storePassword=********
keyPassword=********
keyAlias=upload
storeFile=/home/<you>/pchat-upload.jks
```
তারপর `android/app/build.gradle.kts`-এ `signingConfigs { create("release") { ... } }` যোগ করে
`buildTypes.release.signingConfig = signingConfigs.getByName("release")` করে দিন।
</details>

### সব কিছু একবারে প্যাক করা (`dist/`)

Linux/Arch-এ (Linux + Android দুটোই বানায়):
```bash
tool/package_release.sh          # সিস্টেমে webkit2gtk-4.1 থাকলে
# সিস্টেমে না থাকলে যেকোনো sysroot দেখিয়ে দিন:
PCHAT_SYSROOT=/tmp/opencode/sysroot tool/package_release.sh
```

Windows-এ (Flutter + Visual Studio 2022 থাকলে) — শুধু এই একটি কমান্ড:
```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
```

Windows-এ ইনস্টলার বানাতে (Inno Setup 6 লাগবে):
```powershell
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" tool\windows_installer.iss
```

| তৈরি হয় | কার জন্য |
|---|---|
| `dist/linux/pchat_app-<ver>-linux-x64-installer.run` | **Linux ইনস্টলার** — অ্যাপ + Applications মেনু + ডেস্কটপ শর্টকাট + আইকন, সব এক ফাইলে |
| `dist/linux/pchat_app-<ver>-linux-x64.tar.gz` | Linux/Arch — খুলে `./run.sh` (লাইব্রেরি না থাকলে নিজেই বলে দেবে) |
| `dist/android/pchat_app-<ver>.apk` | **একটাই APK — সব Android ফোনে চলে** (`adb install -r …`) |
| `dist/windows/pchat_app-<ver>-windows-x64-installer.exe` | **Windows ইনস্টলার** — Program Files-এ ইনস্টল করে, ডেস্কটপ + Start মেনু শর্টকাট + "Apps"-এ রেজিস্ট্রেশন, সবগুলোতে PCHAT-এর আইকন |
| `dist/windows/pchat_app-<ver>-windows-x64.zip` | Windows (GitHub Actions বা Windows-এ স্ক্রিপ্ট) — ইনস্টল ছাড়াই চালাতে চাইলে |
| `dist/SHA256SUMS` | সব ফাইলের SHA-256 |

প্রকাশের সময় দরকার হলে `tool/package_release.sh --all-android` চালালে per-ABI APK আর Play Store-এর `.aab`-ও তৈরি হবে (ফোনে ইনস্টলের জন্য লাগে না)।

> ⚠️ প্যাকেজগুলো **ডিবাগ key** দিয়ে সাইন করা — নিজে ইনস্টল করতে বা শেয়ার করতে সমস্যা নেই, কিন্তু প্লে-স্টোরে দেওয়ার আগে নিজের keystore দিয়ে সাইন করতে হবে (উপরের "Release signing সেটআপ")।

### Windows
```bash
flutter run -d windows

flutter build windows --release
#  → build/windows/x64/runner/Release/pchat_app.exe
```
`Release` ফোল্ডারের **সব ফাইল একসাথে** (`data/`, `*.dll`) ডিস্ট্রিবিউট করতে হয় — শুধু `.exe` কপি করলে চলবে না।
ইনস্টলার চাইলে [Inno Setup](https://jrsoftware.org/isinfo.php) বা MSIX প্যাকেজিং ব্যবহার করুন।

### Linux — ইনস্টলার (সবচেয়ে সহজ)
```bash
chmod +x pchat_app-<ver>-linux-x64-installer.run
./pchat_app-<ver>-linux-x64-installer.run
```
`sudo` লাগে না। ইনস্টলারটি:

- অ্যাপ বসায় `~/.local/share/pchat-app`-এ — হোম ফোল্ডারে কোনো ফাইল/ফোল্ডার খোলা অবস্থায় পড়ে থাকে না
- **Applications মেনুতে PCHAT** এন্ট্রি দেয় (`~/.local/share/applications/io.github.shepu1.pchat.desktop`)
- **ডেস্কটপে PCHAT শর্টকাট** দেয় (GNOME-এ "trusted" করা হয়; ডাবল-ক্লিকে "Allow Launching" এলে সেটাই অনুমোদন)
- আইকন `assets/icon/icon.png` থেকেই — ২৫৬px + ৫১২px, অ্যাপ/মেনু/শর্টকাট সবখানে একই
- `~/.local/bin/pchat` কমান্ড বানায়
- **ডিপেন্ডেন্সি নিজেই সামলায়:** `webkit2gtk-4.1` / `gtk3` না থাকলে চার ডিস্ট্রোর কমান্ড দেখায়
  (Arch/Ubuntu/Fedora/openSUSE) এবং টার্মিনালে থাকলে `sudo` দিয়ে বসিয়ে দিতে চায়

```bash
bash pchat_app-<ver>-linux-x64-installer.run   # chmod +x না দিলেও চলে
./…installer.run --no-desktop-shortcut     # ডেস্কটপ শর্টকাট ছাড়া
./…installer.run --dir ~/Apps/pchat        # অন্য ফোল্ডারে
./…installer.run -y                        # ডিপেন্ডেন্সিও না জিজ্ঞেসে বসাও
./…installer.run --no-deps                 # ডিপেন্ডেন্সি হাতে নেব না
./…installer.run --uninstall               # সব সরিয়ে ফেলা
```
ইনস্টলারের সোর্স: `tool/linux_installer.sh` (প্যাকেজ স্ক্রিপ্ট নিজেই ডাকে)।

### Linux — ম্যানুয়াল (tar.gz)
```bash
flutter run -d linux

flutter build linux --release
#  → build/linux/x64/release/bundle/pchat_app
```
পুরো `bundle/` ফোল্ডারটি বিতরণ করুন। প্রয়োজনীয় shared library গুলো সিস্টেমে থাকতে হবে
(`libwebkit2gtk-4.1`, `libgtk-3`); একটি স্বয়ংসম্পূর্ণ AppImage বানাতে চাইলে
`linuxdeploy` + `appimagetool` ব্যবহার করতে পারেন।

ইনস্টলার ব্যবহার না করলে Linux-এর Taskbar/ডকে সঠিক আইকনটি দেখাতে একবার এই কমান্ডটি চালান
(বিস্তারিত ৫ নম্বর বিভাগে):

```bash
tool/app_icons.sh --install-linux       # build/linux/x64/release/bundle/pchat_app খুঁজে নেয়
tool/app_icons.sh --install-linux /path/to/bundle/pchat_app   # অথবা পথ নিজে দিন
```

---

## ৫. প্ল্যাটফর্ম-ভিত্তিক যা যা কনফিগার করা আছে

### Android — `android/app/src/main/AndroidManifest.xml`
| কী | কেন |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | WebView লোডিং + offline সনাক্তকরণ |
| `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` | PCHAT-এর ভয়েস/ভিডিও কল (WebRTC) |
| `<uses-feature ... required="false">` | ক্যামেরা/মাইক না থাকা ডিভাইসেও অ্যাপ ইনস্টল হবে |
| `<queries>` (VIEW/SENDTO/DIAL) | Android 11+ এ বাইরের ব্রাউজার/মেইল/ডায়ালার খোলার জন্য |
| `android:usesCleartextTraffic="false"` | সাইট HTTPS, তাই শুধু এনক্রিপ্টেড ট্রাফিক |
| `android:hardwareAccelerated="true"` | WebView রেন্ডারিং পারফরম্যান্স |
| `android:configChanges=...` | কীবোর্ড/রোটেশনে WebView রিস্টার্ট হবে না (চ্যাট স্টেট হারাবে না) |
| `android:windowSoftInputMode="adjustResize"` | কীবোর্ড খুললে চ্যাট ইনপুট ঠিকভাবে উপরে ওঠে |
| `label="PCHAT"`, `minSdk=24` | অ্যাপের নাম ও ন্যূনতম সমর্থিত Android |

`MainActivity` প্যাকেজ: `com.shepu.pchat` (নিজস্ব applicationId, `com.example` নয়)।

### Linux / Windows
- **চালু হওয়ামাত্র বর্ডারলেস ম্যাক্সিমাইজড, আর OS-এর টাস্কবার/প্যানেল অক্ষত** — OS-এর কোনো টাইটেল বার/বর্ডার/উইন্ডো বাটন নেই, কিন্তু উইন্ডোটি ফুলস্ক্রিন নয়: শুধু *work area* জুড়ে থাকে, তাই টাস্কবার/ডক ঢাকা পড়ে না।
  - Linux: `linux/runner/my_application.cc` → `gtk_window_set_decorated(window, FALSE)` + `gtk_window_maximize(window)` (আগে ছিল `gtk_window_fullscreen()`, যা নিচের প্যানেলটাই ঢেকে দিত)।
  - KDE/KWin (Wayland) "no decorations" অনুরোধ মানে না, ম্যাক্সিমাইজড উইন্ডোতে নিজের টাইটেল বার বসিয়ে দেয় — তাই উইন্ডোকে একটি **খালি client-side titlebar** দেওয়া হয় (`gtk_window_set_titlebar(window, gtk_box_new(GTK_ORIENTATION_VERTICAL, 0))`)। তখন GTK নিজেই ডেকোরেশন আঁকে, আর আঁকিবার কিছু থাকে না; GNOME/Mutter, sway ও X11 উইন্ডো ম্যানেজাররাও এটি একইভাবে মানে।
  - Windows: `windows/runner/win32_window.cpp` → `WS_POPUP` স্টাইলে `GetMonitorInfo()` থেকে এখন **`rcWork`** (টাস্কবার বাদ দিয়ে) নেওয়া হয়; আগের `rcMonitor` পুরো টাস্কবার ঢেকে দিত। সাথে `WS_EX_APPWINDOW` যোগ করা হয়েছে, যাতে বর্ডারলেস উইন্ডোও টাস্কবারে ও Alt+Tab-এ থাকে।
  - বন্ধ করার উপায়: নিচের বারের **✕**, অথবা **Alt + F4**।
  - পুরো স্ক্রিন (টাস্কবার সহ) দখল করতে চাইলে Linux-এ `gtk_window_fullscreen()` ব্যবহার করুন, Windows-এ `rcWork` → `rcMonitor` করুন।
- **উপরে চিকন স্বচ্ছ বার (শুধু Windows ও Linux)** — ৩২ পিক্সেল উঁচু, ব্যাকগ্রাউন্ড স্বচ্ছ (Scaffold-এর `#070A12` ক্যানভাস দেখা যায় — সাইটের একদম উপরের প্রান্ত ঠিক এই রঙই, তাই কার্যত অদৃশ্য)। বাঁয়ে **Refresh**, ডানে **minimize** ও **close**।
  - বাটনগুলো Flutter-এ আঁকা (`lib/src/window_controls.dart`) এবং `io.github.shepu1.pchat/window` মেথড চ্যানেলে কথা বলে; Linux রানার `gtk_window_iconify()`/`gtk_window_close()`, Windows রানার `ShowWindow(SW_MINIMIZE)`/`WM_CLOSE` চালায়। Android-এ এই বার নেই — ওখানে সিস্টেমের নিজের chrome আছে।
  - **Linux-এ এই বার আর লোডিং/এরর স্ক্রিন সাইটের উপরে ভাসতে পারে না।** কারণ এখানে `webview_all_linux` WebView-কে একটি নেটিভ GTK `GtkOverlay`-এ Flutter-এর ক্যানভাসের *উপরে* বসায় (সোর্স: `linux/src/platform/flutter_view.cc`) — অর্থাৎ Flutter-এর কোনো কিছু WebView-কে ঢাকতে পারে না। তাই WebView-কে বারের *নিচে* বসানো হয়, আর প্রথম লোড শেষ না হওয়া পর্যন্ত WebView-কে `Offstage` করে রাখা হয় (প্লাগিন নিজেই "painted নয় → লুকাও" নিয়ম মানে)। Windows-এ WebView টেক্সচার হিসেবে আসে, তবু একই কোড চলে।
- `linux/runner/my_application.cc` এবং `windows/runner/main.cpp`-এ উইন্ডো টাইটেল **"PCHAT"** (task switcher ও `.desktop` এন্ট্রির জন্য; বর্ডারলেস হওয়ায় স্ক্রিনে দেখা যায় না)।
- Linux-এর GTK application ID: `io.github.shepu1.pchat` (`linux/CMakeLists.txt`)।
- `windows/runner/Runner.rc`-তে Product/Description **"PCHAT"**, CompanyName `io.github.shepu1`।
- Linux-এ `mediaPlaybackRequiresUserGesture: false` — ভয়েস মেসেজ/কল নিজে থেকেই বাজবে।
- দুটোতেই downloads সক্রিয়, Windows-এ popup policy `sameWindow`।
- Linux plugin-এ `window.open` নতুন উইন্ডো না খুলে **একই WebView**-এ লোড করে, তাই Google popup-এর জন্য অ্যাপ নিজের WebView ব্যবহার করে (বিভাগ ৬ দেখুন)।

### অ্যাপ আইকন — তিন প্ল্যাটফর্মেই একই ফাইল

আইকনের একটাই সোর্স: **`assets/icon/icon.png`**। এই একটি ফাইল বদলে `tool/app_icons.sh` চালালেই তিন প্ল্যাটফর্মের আইকন বদলে যায় (স্ক্রিপ্টটি চালাতে **ImageMagick** লাগে):

```bash
tool/app_icons.sh                       # Android + Windows আইকন নতুন করে বানায়
tool/app_icons.sh --install-linux       # সাথে Linux-এর desktop entry ও hicolor আইকন বসায়
```

| প্ল্যাটফর্ম | কোথায় কী হয় |
|---|---|
| Android | `android/app/src/main/res/mipmap-{mdpi..xxxhdpi}/ic_launcher.png` — ৫টি ঘনত্বের জন্য (48/72/96/144/192 px), সাথে Android 8+ এর **adaptive icon**: `mipmap-anydpi-v26/ic_launcher.xml` + প্রতিটি ঘনত্বের `ic_launcher_foreground.png` (108dp ক্যানভাসে ৮৫% মাপে বসানো, তাই লঞ্চারের যেকোনো মাস্কে পুরো লোগোটি বাঁচে) + `values/ic_launcher_background.xml` (আর্টওয়ার্কের নিজের রঙ)। Manifest-এ আলাদা কিছু লাগে না — আগের মতোই `android:icon="@mipmap/ic_launcher"`. |
| Windows | `windows/runner/resources/app_icon.ico` — ২৫৬…১৬ px পর্যন্ত ৬টি ফ্রেম; `Runner.rc` এটিকে `IDI_APP_ICON` হিসেবে `.exe`-এর ভেতরে বসায় আর `win32_window.cpp` উইন্ডো ক্লাসে সেটি লোড করে, তাই Taskbar/Alt+Tab/Explorer সবখানেই এই আইকন। |
| Linux | রানটাইমে সোজা বান্ডল থেকে পড়া হয় — `linux/runner/my_application.cc`-এ `gtk_window_set_icon_from_file("<exe-folder>/data/flutter_assets/assets/icon/icon.png")` (তাই `assets/icon/` pubspec-এ রাখা আছে)। এতে X11/XWayland-এ আইকন ঠিক আসে। **Wayland-এ** compositor উইন্ডো-আইকন বলে কিছু রাখেই না — Plasma/KWin সেটি `.desktop` ফাইলের সাথে `app_id` মিলিয়ে খোঁজে, তাই `--install-linux` একটি এন্ট্রি (`~/.local/share/applications/io.github.shepu1.pchat.desktop`, `StartupWMClass=io.github.shepu1.pchat`) ও hicolor আইকন বসায়। |

> `.desktop` এন্ট্রিতে `Exec=` বিল্ডের পথ ধরে লেখা হয় (release থাকলে সেটি, নাহলে debug)। release বিল্ডের পর আবার `tool/app_icons.sh --install-linux` চালালে পথটি ঠিক হয়ে যাবে।

আইকন সত্যিই APK-তে ঢুকেছে কি না, বিল্ডের পর এভাবে দেখা যায়:
```bash
AAPT=$ANDROID_HOME/build-tools/36.0.0/aapt2
APK=build/app/outputs/flutter-apk/app-release.apk
$AAPT dump badging   $APK | grep application-icon   # adaptive (res/….xml) সবার আগে দেখাবে
$AAPT dump resources $APK | grep -A6 mipmap/ic_launcher   # ৫টি ঘনত্বের PNG + anydpi-v26 XML
```
(R8/AGP ফাইলের নাম ছোট করে দেয় — তাই `res/9w.png`-এর মতো নাম দেখতে পারেন, কিন্তু `dump resources` আসল নামই দেখায়।)

### পারমিশন — কে কী চায়, কে দেয়

অ্যাপ **নিজে থেকে একবারও কোনো পারমিশন চায় না**। পেজ যখন চায়, তখনই চাওয়া হয়: চ্যাট করা, ফাইল পাঠানো বা রুমে ঢোকার জন্য কোনো পারমিশন লাগে না — কল শুরু করলেই কেবল ক্যামেরা/মাইকের প্রশ্ন আসে।

| প্ল্যাটফর্ম | কী ঘটে |
|---|---|
| **Android** | Manifest-এ `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `INTERNET`, `ACCESS_NETWORK_STATE` আছে। পেজ ক্যামেরা/মাইক চাইলে (`onPermissionRequest`) অ্যাপ প্রথমে **সিস্টেমের runtime permission** চায় (`permission_handler` — কেন `12.0.3`-এ পিন করা, বিভাগ ৯ দেখুন), তারপর WebView-কে grant করে; ডিভাইস অনুমতি না দিলে WebView-ও deny করে — পেজ পরিষ্কারভাবে "not allowed" পায়, চুপচাপ আটকে থাকে না। |
| **Linux** | WebKitGTK-র `permission-request` সিগন্যাল অ্যাপ নিজে উত্তর দেয় (ডিফল্টে WebKit নিজে থেকে কিছু মঞ্জুর করে না)। ডেস্কটপে ক্যামেরা/মাইকের আসল দরজা OS/PipeWire-র হাতে, তাই অ্যাপ সোজা allow করে। |
| **Windows** | WebView2-র `PermissionRequested`-ও অ্যাপই উত্তর দেয়; allow করার পরও আসল ছাড়পত্র Windows-এর Privacy settings-এ (Settings → Privacy → Camera/Microphone)। |

- ক্যামেরা/মাইক ছাড়া বাকি যা কিছু ইঞ্জিন জিজ্ঞেস করে — **স্ক্রিন শেয়ার, ডিভাইসের তালিকা, ক্লিপবোর্ড পড়া, ডেস্কটপ নোটিফিকেশন** — সেগুলো সোজা grant করা হয়। কারণ in-app WebView কেবল PCHAT-ই লোড করে (`url_policy.dart`), আর এখানে "deny" দিলে সাইটের নিজের ফিচারই ভাঙে — যেমন Linux-এ স্ক্রিন শেয়ার WebKitGTK কোনো type ছাড়াই পাঠায়, তাই আগের "শুধু camera/microphone, বাকি সব deny" নিয়মে সেটি নিজের থেকেই আটকে যেত।
- Android-এ কেউ **"Never ask again"** দিলে ডায়ালগ আর দেখানো যায় না, তাই অ্যাপ নিজে থেকেই অ্যাপের Settings স্ক্রিন খুলে দেয় (`openAppSettings`) — নাহলে কল ব্যর্থ হত অথচ কী করতে হবে তা বলা থাকত না।
- সাইট যা **ডাকে না**, তার পারমিশন যোগ করা হয়নি (necessity নেই): `POST_NOTIFICATIONS`/`VIBRATE`/`READ_MEDIA_*`/লোকেশন — সাইটে `Notification`, `navigator.vibrate`, `geolocation` কোথাও ব্যবহারই হয় না, আর ফাইল পাঠানো হয় সিস্টেমের picker (`ACTION_GET_CONTENT`) দিয়ে, তাই storage পারমিশনও লাগে না; ডাউনলোড বাইরের ব্রাউজারে খোলে।
- Android-এ ফাইল পাঠাতে (attachment) কোনো পারমিশন লাগে না, কিন্তু **URI লাগে**: WebView ইঞ্জিন প্রতিটি string সোজা `Uri.parse`-এ দেয়, আর picker ফেরত দেয় সাধারণ ফাইল-পাথ (`file_selector` আগে ফাইলটি অ্যাপের নিজের cache-এ কপি করে) — scheme ছাড়া URI পেলে WebView চুপচাপ কিছুই আপলোড করে না। তাই `webViewFilePath()` পাথকে `file://` URI-তে বদলে দেয় (আগে থেকে URI থাকলে হাত দেওয়া হয় না)।
- Android-এ ভয়েস মেসেজ/রিংটোন নিজে থেকে বাজতে পারে (`setMediaPlaybackRequiresUserGesture(false)`) — সিস্টেম WebView ডিফল্টে প্রথম শব্দের জন্য ইউজারের ছোঁয়া দাবি করে, ফলে ইনকামিং কলের প্রথম রিংটোন চাপা পড়ত।
- **Android-এ স্ক্রিন শেয়ার কাজ করবে না** — Android WebView নিজে থেকে `getDisplayMedia`-কে MediaProjection অনুমতি দেয় না; সাইটের স্ক্রিন শেয়ার তাই শুধু Windows/Linux-এ চলে, ক্যামেরা/মাইক কল সব প্ল্যাটফর্মেই চলে।

### কোড-লেভেলে
- **Android-এ status bar/gesture bar-এর নিচে পেজ ঢুকে যেত না** — Android 15 (API 35) থেকে প্রতিটি অ্যাপ জোর করে edge-to-edge আঁকে, তাই সাইটের হেডার ঘড়ি-ব্যাটারির নিচে চলে যাচ্ছিল। অ্যাপ এখন `SafeArea`-র ভিতরে পেজ রাখে, আর status bar-টি `SystemUiOverlayStyle` দিয়ে সাইটের নিজের top-edge রঙেই (`#070A12`, সাদা আইকন) আঁকা হয় — তাই পেজ বার-এর সামনে শুরু হয়, বিদঘুটে খালি ফাঁক দেখায় না। ডেস্কটপে এটি নিষ্ক্রিয় (উইন্ডোতে সিস্টেম বারই নেই)।
- **Android-এ সাইটের UI দুই পাশ থেকে কাটা পড়ত** — প্লাগিন ডিফল্টে `setUseWideViewPort(false)` রাখে, অর্থাৎ পেজের `<meta name="viewport" content="width=device-width">` উপেক্ষা করে সাইটটিকে ডেস্কটপ-প্রস্থে সাজায়; ফোনের ছোট স্ক্রিনে তাই চ্যাট UI দুই দিক দিয়ে বেরিয়ে যেত। অ্যাপ এখন সেটি `setUseWideViewPort(true)` করে দেয় (`attachPlatformController`) — ফলে Chrome for Android-এর মতোই মোবাইল লেআউট আসে।
- `onPermissionRequest` → কলের আগে OS থেকে camera/mic permission নেওয়া হয়, তারপর WebView-কে grant করা হয়।
- `NavigationDelegate.onNavigationRequest` → বাইরের লিংক সিস্টেম ব্রাউজারে।
- `addJavaScriptChannel('PChatBridge')` + injected JS → `window.open` ও `target="_blank"` কেও একইভাবে হ্যান্ডল করা হয় (Android WebView-এ `onCreateWindow` সাপোর্ট নেই, তাই এটাই নির্ভরযোগ্য পথ)। Google-এর sign-in URL আলাদা করে চেনা হয় এবং অ্যাপের নিজের popup WebView-তে খোলা হয় — বিস্তারিত বিভাগ ৬-এ।
- `onWebResourceError` → শুধুমাত্র **মূল পেজ** ব্যর্থ হলে error UI; কোনো `favicon`/`css` ফেল করলে নয়।
- **ইঞ্জিনের নিজের এরর-পেজ আর অ্যাপের স্ক্রিনকে ঢেকে দিতে পারে না** (`_handlePageFinished`) — লোড ব্যর্থ হলেও `onPageFinished` ফায়ার হয়, কারণ ইঞ্জিন নিজের একটা এরর-ডকুমেন্ট বসিয়ে দেয়। সেটি `about:blank`-এ থাকে, তাই পেজ শেষ হওয়ার পর পেজকেই জিজ্ঞেস করা হয় (`window.location.href`) ডকুমেন্টটি আসল কি না; আসল হলে তবেই error সরে যায়। আগে `onPageStarted`/`onPageFinished` না-ভেবে error মুছে দিত — ফলে নেট না থাকলেও ইঞ্জিনের "Error resolving …" পেজটাই দেখা যেত, অ্যাপের "Connection Lost" স্ক্রিন নয়।
- **অটো-রিট্রাই** (`_scheduleAutoRetry`) — পেজ লোড না হলে প্রতি ১০ সেকেন্ডে নিজে থেকেই `reload()` চেষ্টা করে, পেজ এলেই থেমে যায়। ওই অবস্থায় স্ক্রিনে রাখার মতো কিছু থাকে না, তাই রিলোডে ক্ষতি নেই। Linux-এ `connectivity_plus` কোনো ইভেন্টই দেয় না, তাই সেখানে এটিই একমাত্র স্বয়ংক্রিয় রিকভারি (পরীক্ষিত: DNS ফিরে আসার পর অ্যাপ নিজে থেকেই সাইটে ফিরে এসেছে)।
- `Offstage(offstage: !showWebView)` → Linux/Windows-এর নেটিভ WebView প্রথম লোড শেষ হওয়ার আগে লুকিয়ে রাখা হয়, নাহলে লোডিং অ্যানিমেশন ও Offline স্ক্রিন WebView-এর নিচে চাপা পড়ে যেত। লোড হওয়া চ্যাট কেবল তখনই সরানো হয় যখন নেট চলে যায় বা পেজ লোডই না হয় (তখন দেখানোর মতো কিছু থাকে না)।
- `Image.asset('assets/animations/animation.apng')` → Flutter নিজেই APNG-এর ফ্রেম ডিকোড করে (`frameCount` = ১০, প্রতি ফ্রেম ২০০ms), তাই `Image` অ্যানিমেশনটি চালায় — আলাদা APNG প্যাকেজ লাগে না।
- `StatusOverlay` **দুটি আলাদা স্ক্রিন** দেখায়, কারণ দুটো সমস্যা আলাদা:
  - **কানেক্টিভিটি-লেভেল সমস্যা** (`_isOffline`, বা `_connectionFailure` = সার্ভারেই পৌঁছানো যায়নি) → `assets/images/c_lost_desktop.png` (ডেস্কটপ) বা `c_lost_phone.png` (Android) আর্টওয়ার্ক; বাছাইটি `platform_setup.dart`-এর `offlineImage` করে, কারণ প্ল্যাটফর্ম চেনা একমাত্র ওই ফাইলের কাজ। ছবিটিতেই "Connection Lost" লেখা আছে, তাই স্ক্রিনে আর আলাদা টেক্সট নেই। **ছবিটি পুরো স্ক্রিন জুড়ে থাকে** (`BoxFit.cover`, `Stack`-এ `Positioned.fill`) — আগে এটি একটি `Column`-এর ভেতরে `BoxFit.contain` ছিল, ফলে চারপাশে খালি জায়গা থেকে যেত।
  - **সার্ভার উত্তর দিয়েছে কিন্তু পেজ আসেনি** (TLS হ্যান্ডশেক ব্যর্থ, redirect loop, ইত্যাদি) → "PCHAT is unreachable" + ইঞ্জিনের এরর-বার্তা, কারণ এখানে নেটকে দোষ দেওয়া ভুল হতো।
  - দুই ক্ষেত্রেই **Try again** বাটন — আর্টওয়ার্কের *উপরে* (নিচে ভাসমান) থাকে, তাই আর্টওয়ার্ক কখনো ছোট হয় না; তার রঙ আর্টওয়ার্কের নিজের নীল→সায়ান গ্রেডিয়েন্ট (`#0065F4 → #01E8FC`) থেকে নেওয়া।
  - শ্রেণিবিভাগটি ইচ্ছাকৃতভাবে উল্টো করে লেখা — "সার্ভার উত্তর দিয়েছে" তালিকায় যেগুলো আছে সেগুলো বাদে বাকি সব কানেক্টিভিটি সমস্যা। কারণ WebKitGTK DNS ব্যর্থতাও `unknown` বলে, তাই অন্যভাবে লিখলে Linux-এ কানেক্টিভিটি স্ক্রিন কখনোই আসত না।
- কানেক্টিভিটি নিয়ম: `connectivity_plus` যদি **খালি লিস্ট** ফেরত দেয় (`[]` = প্ল্যাটফর্মের উত্তর নেই) তবে সেটিকে *অনলাইন* ধরা হয় — আগে অফলাইন ধরা হতো, ফলে চালু হওয়ার মুহূর্তে ভুল করে Connection Lost স্ক্রিন উঠে আসত। প্রতিটি কল **১ সেকেন্ডের টাইমআউটে** বাঁধা, কারণ Linux-এ `checkConnectivity()` কখনো উত্তরই দেয় না — টাইমআউট না থাকলে **Try again** বাটনটি আটকে যেত।
- `DesktopWindowControls` → **Refresh** বাটনটি সরাসরি Flutter-এর `_retry()` ডাকে (সেটি কানেক্টিভিটি দেখে `reload()` করে, ব্যর্থ হলে মূল URL-এ ফেরে); **minimize** ও **close** বাটন `io.github.shepu1.pchat/window` চ্যানেলে কল পাঠায়, যার উত্তর দেয় Linux/Windows রানার।

---

## ৬. Google লগইন

PCHAT-এর লগইন ঐচ্ছিক (“Quick rooms + joining work logged-out”), আর `login.html`-এ তিনটি উপায় আছে — **Email**, **Demo user** ও **Google**।

### সমস্যাটা কী ছিল

সাইট Google Identity Services-এর **token model** ব্যবহার করে (`google.accounts.oauth2.initTokenClient(...)` → `requestAccessToken()`), যা মূলত একটি **popup**:

1. GIS `window.open(...)` দিয়ে `accounts.google.com` খোলে,
2. লগইন শেষে popup-টি `window.opener.postMessage(...)` দিয়ে token ফেরত পাঠায়,
3. GIS সেটি পেয়ে সাইটের callback ডাকে।

WebView আলাদা popup উইন্ডো দিতে পারে না। আগে অ্যাপ URL-টি সিস্টেম ব্রাউজারে পাঠাত — সেখানে `window.opener` সম্পর্কই থাকে না, তাই token কখনো অ্যাপে ফিরত। বরং আরও খারাপ হতো: `window.open` কিছু ফেরত না দেওয়ায় GIS সাথে সাথে `Failed to open popup window` বলে হাল ছেড়ে দিত — অর্থাৎ **বাটন চাপলে কিছুই হতো না**।

### এখন কী করা হয়

অ্যাপ নিজেই popup-টির ভূমিকা নেয় (`lib/src/google_auth.dart`):

1. injected JS `window.open`-এ Google-এর URL দেখলে সেটি `auth:` মার্কার দিয়ে Dart-এ পাঠায় **এবং** একটি নকল popup handle (`closed: false`) ফিরিয়ে দেয়, যাতে GIS এগোয়।
2. অ্যাপ একটি আলাদা route-এ **দ্বিতীয় WebView**-তে আসল Google সাইন-ইন পেজ দেখায়, উপরে সরু “Sign in with Google / Cancel” বারসহ। মূল WebView তখন নিজে থেকেই লুকিয়ে যায়, কারণ route-টি তার উপরে থাকে।
3. সেই WebView-এ `window.opener`-এর জায়গায় একটি shim বসানো হয়, ফলে Google তার উত্তর দিলে সেটি সরাসরি অ্যাপে চলে আসে।
4. উত্তরটি মূল পেজে একটি **সত্যিকারের `message` event** হিসেবে পাঠানো হয় — GIS ঠিক এই ঘটনাটিরই অপেক্ষা করছিল, তাই সাইটের নিজের লগইন কোডই স্বাভাবিকভাবে শেষ হয়।

সহায়ক fallback: shim সময়মতো বসতে না পারলে পেজ থেকেই token পড়ে নিয়ে সাইটের নিজের `Storage.setAuth(...)` দিয়ে লগইন করানো হয় (সাইট যা করে ঠিক তাই), তারপর পেজ reload হয়।

> **সীমা:** Google embedded WebView-এ OAuth আটকে দিতে পারে (`disallowed_useragent`)। ডেস্কটপের WebKitGTK/WebView2 user-agent-এ “WebView” লেখা থাকে না, তাই Linux/Windows-এ এই popup পথটি কাজ করে। Android WebView-এর UA-তে `; wv` থাকে — সেখানে Google আটকালে **Email বা Demo** লগইন নিশ্চিত পথ।

---

## ৭. টার্গেট সাইট বদলানো

শুধু একটি ফাইল: `lib/src/app_config.dart`

```dart
static const String startUrl = 'https://pchatshepu.vercel.app/'; // যে সাইট খুলবে
static const String appTitle = 'PCHAT';                            // উইন্ডো/লঞ্চার নাম
static const Set<String> inAppHosts = {'pchatshepu.vercel.app'};    // অ্যাপে থাকবে যেসব host
```

নতুন সাইটের ডোমেইন `inAppHosts`-এ যোগ করলেই সেটি অ্যাপের ভেতরে চলবে; বাকিসব বাইরের ব্রাউজারে যাবে।

---

## ৮. টেস্ট ও কোড কোয়ালিটি

```bash
flutter analyze     # কোনো issue নেই
flutter test        # ৩১টি টেস্ট
dart format lib test
```

টেস্টগুলো URL policy (কোন লিংক ভেতরে, কোনটি বাইরে, কোনটি ব্লকড), অফলাইন ও "unreachable" স্ক্রিন, লোডিং APNG অ্যানিমেশন, উপরের বারের তিনটি বাটন, Google sign-in-এর popup/relay চুক্তি, এবং পারমিশন নিয়ম কভার করে — কোন ask-এ OS-এর কাছে যেতে হয়, Android থেকে কী কী চাওয়া হয় (camera/microphone-এর সঠিক দুটি), deny আর "Never ask again"-এর পার্থক্য, আর ডেস্কটপে OS-ই সিদ্ধান্ত নেয় কি না (`test/permissions_test.dart`)।

---

## ৯. সমস্যা সমাধান (Troubleshooting)

| সমস্যা | সমাধান |
|---|---|
| Linux-এ `webkit2gtk-4.1 not found` | `sudo pacman -S webkit2gtk-4.1` (Ubuntu: `libwebkit2gtk-4.1-dev`) |
| **হঠাৎ "network error" / অফলাইন স্ক্রিন, অথচ ইন্টারনেট চালু** | রাউটারের DNS `pchatshepu.vercel.app`-এর জন্য পৌঁছানো-যায় না এমন IP (যেমন `64.29.17.131`) ফেরত দিচ্ছে (`curl -sS -m 8 https://pchatshepu.vercel.app/pchat/index.html` → timeout, অথচ `example.com` চলে)। 1.1.1.1 ঠিক IP দেয় — যাচাই: `curl --doh-url https://1.1.1.1/dns-query -v https://pchatshepu.vercel.app/pchat/index.html`। সমাধান: রাউটার/পিসির DNS `1.1.1.1`+`8.8.8.8` করুন, অথবা এক লাইনে: `echo '216.198.79.3 pchatshepu.vercel.app' \| sudo tee -a /etc/hosts` (Vercel-এর anycast IP, কাজ করে যাচাই করা) |
| **পেজ বদলালে পুরো কনটেন্ট হালকা ঝাঁকুনি/লাফ দেয়** | সাইটের page-entry animation (`fadeIn`/`fadeInUp`/`scaleIn`/`msgIn`) — প্রতিটি পেজ লোডে ৮–২০px উঠে আসত বা ৯০%→১০০% জুম হতো। অ্যাপ এখন `documentStart` user script দিয়ে ওগুলো শেষ অবস্থায় পৌঁছে দেয় (`lib/src/page_smoothing.dart`); সাইটের `css/base.css` ও `css/chat.css`-ও opacity-only করা হয়েছে (লাইভ সাইটে দেখতে হলে ডিপ্লয় করতে হবে)। পুরোনো APK/ইনস্টলার হলে নতুনটা নিন |
| **`+` চাপলে আগে অন্য কিছু (গাঢ়/ঝাপসা স্ক্রিন) এক ঝলক আসে, তারপর কার্ড** | সাইটের bottom sheet দুই ধাপে আসে: আগে পুরো স্ক্রিনে `rgba(0,0,0,.65)` + `blur(8px)` ব্যাকড্রপ ০.২s ফেড-ইন, পরে কার্ড ০.৩s স্লাইড। অ্যাপ এখন `documentStart` script দিয়ে ওই দুটোর `transition` বন্ধ করে দেয়, তাই ব্যাকড্রপ আর কার্ড একই ফ্রেমে হাজির হয় (`lib/src/page_smoothing.dart`)। ব্রাউজারেও একরকম চাইলে সাইটের `css/components.css`-এ `.bottom-sheet-overlay` ও `.bottom-sheet-card`-এর `transition` সরিয়ে ডিপ্লয় করুন |
| **রুমে send (পাঠানোর) বাটন দেখা যায় না / ডান পাশে কেটে গেছে** | `.chat-input-wrap` শুধু `flex: 1` ছিল, আর flex item নিজের কনটেন্টের চেয়ে ছোট হয় না — textarea-র নিজস্ব প্রস্থ (~200px) থাকায় সারিটি ফোনের স্ক্রিনের চেয়ে চওড়া হয়ে send বাটন ডান কিনারার বাইরে চলে যেত। অ্যাপ এখন `.chat-input-wrap` ও `.chat-input`-এ `min-width: 0` বসায় (`lib/src/page_smoothing.dart`), সাইটের `css/chat.css`-ও ঠিক করা হয়েছে (ডিপ্লয় করলে ব্রাউজারেও)। যাচাই: 400px প্রস্থে `#send-btn` আগে x=374…420 (স্ক্রিনের বাইরে), এখন x=341…387 ✅ |
| **Linux-এ খোলার ১০-২০ সেকেন্ড পরেই অ্যাপ/পেজ বন্ধ হয়ে যায়** (journal-এ `WebKitWebProces ... SIGABRT`, আগে `GStreamer element autoaudiosink not found`) | `gst-plugins-good` নেই — WebKit সাউন্ড বাজাতে গিয়ে web process abort করে। `sudo pacman -S gst-plugins-base gst-plugins-good` (Ubuntu: `gstreamer1.0-plugins-base gstreamer1.0-plugins-good`)। ইনস্টলারের ভিতরে ওই প্লাগিনের কপি আছে, তাই `sudo` ছাড়াও নতুন ইনস্টলে কাজ করার কথা |
| Linux-এ অ্যাপ চুপচাপ বন্ধ/`core dumped`, এরর `Unable to spawn a new child process: /usr/lib/webkit2gtk-4.1/WebKitNetworkProcess` | WebKitGTK-এর helper বাইনারিগুলোই নেই (প্যাকেজটি ইনস্টল করা হয়নি) — `sudo pacman -S webkit2gtk-4.1` / `sudo apt install libwebkit2gtk-4.1-0`; তারপর ব্যবহার করুন `dist` tarball-এর `./run.sh` (সেটি আগেই বলবে কী নেই) |
| Android-এ সাইটের UI দুই পাশ থেকে কাটা / ডেস্কটপ-প্রস্থে দেখা যাচ্ছে | `setUseWideViewPort(true)` করা আছে কি না দেখুন (`lib/src/platform_setup.dart`) — এটিই পেজের `width=device-width` মানতে বাধ্য করে; পুরোনো APK হলে নতুন `dist/android/pchat_app-<ver>.apk` ইনস্টল করুন |
| Android 15+ এ সাইটের হেডার ঘড়ি/ব্যাটারির নিচে ঢুকে যাচ্ছে | `lib/main.dart`-এর `SystemUiOverlayStyle` + `pchat_screen.dart`-এর `SafeArea` ঠিক আছে কি না দেখুন; পুরোনো বিল্ড হলে নতুন APK নিন |
| Windows-এ সাদা/খালি উইন্ডো | WebView2 Runtime ইনস্টল করুন (Evergreen Bootstrapper) |
| Windows-এ `flutter build windows` ব্যর্থ | Visual Studio-তে "Desktop development with C++" ইনস্টল করুন |
| Android-এ `flutter build apk` ব্যর্থ: `requires … compile against version 37` | `pubspec.yaml`-এ `permission_handler` ইচ্ছাকৃতভাবে `12.0.3`-এ পিন করা আছে — এর Android অংশ SDK 35-এ কম্পাইল হয়। Flutter-এর AGP ৩৭ সাপোর্ট করলে পিনটি তুলে দেওয়া যাবে |
| Android-এ `Flutter build` ব্যর্থ: `Toolchain installation … does not provide the required capabilities: [JAVA_COMPILER]` | মেশিনে শুধু **JRE** আছে, **JDK** নেই (`javac` চেক করুন) — `sudo pacman -S jdk-openjdk` / `sudo apt install openjdk-17-jdk` |
| Android-এ কলের সময় ক্যামেরা/মাইক কাজ করে না | Settings → Apps → PCHAT → Permissions-এ Camera ও Microphone চালু করুন (আগে "Never ask again" দেওয়া থাকলে অ্যাপ নিজেই Settings খুলে দেয়) |
| Android-এ স্ক্রিন শেয়ার হচ্ছে না | Android WebView `getDisplayMedia` সাপোর্ট করে না — এটাই প্রত্যাশিত; ক্যামেরা/মাইক কল কাজ করে |
| Android-এ ফাইল/ছবি পাঠানো হচ্ছে না | অ্যাপ picker-এর পাথকে `file://` URI-তে বদলে WebView-কে দেয়; তবু সমস্যা হলে `webViewFilePath()` ঠিক ফাইলে আছে কি না দেখুন (`lib/src/platform_setup.dart`) |
| Linux/Windows-এ ক্যামেরা বা মাইক নেই | OS-এর নিজের অনুমতি দেখুন — Windows: Settings → Privacy → Camera/Microphone; Linux (Wayland): PipeWire/xdg-desktop-portal চালু আছে কি না |
| নেট বন্ধ → "Connection Lost" স্ক্রিন আসে না | এখন লোড ব্যর্থ হলে স্ক্রিনটি আসেই এবং ১০ সেকেন্ডে একবার নিজে থেকেই রিট্রাই হয়; দ্রুত দরকার হলে **Try again** চাপুন |
| নেট ঠিক আছে কিন্তু সাইট খুলছে না | "PCHAT is unreachable" নোটিশ + আসল এরর দেখাবে; সার্ভার/ডিপ্লয়মেন্ট চেক করুন |
| টাস্কবার/প্যানেল উইন্ডোর নিচে চাপা পড়ছে | উইন্ডোটি ম্যাক্সিমাইজড হওয়া উচিত, ফুলস্ক্রিন নয় — বিভাগ ৮-এর Linux/Windows অংশ দেখুন |
| Android-এ ব্যাক বাটনে অ্যাপ বন্ধ হচ্ছে | history শেষ হলেই বন্ধ হয় — এটি ইচ্ছাকৃত |
| Google লগইন popup খুলছে কিন্তু লগইন শেষ হচ্ছে না | Android WebView-এ Google `disallowed_useragent` দিয়ে আটকাতে পারে — সেখানে **Email/Demo** লগইন ব্যবহার করুন (বিভাগ ৬) |
| Google popup আটকে গেছে, বন্ধ করতে চাই | popup-এর উপরের ডান কোণে **Cancel** বাটন |
| Linux-এর Taskbar/ডকে সাধারণ (জেনেরিক) আইকন | `tool/app_icons.sh --install-linux` একবার চালান; release বিল্ডের পর আবার চালালে `Exec=` পথটাও ঠিক হবে |
| Android/Windows-এ পুরোনো Flutter আইকন দেখাচ্ছে | `assets/icon/icon.png` বদলে `tool/app_icons.sh` চালান, তারপর নতুন করে বিল্ড করুন |

---

## ১০. লাইসেন্স / নোট

এই র‍্যাপারটি শুধু UI শেল; সম্পূর্ণ অ্যাপ লজিক `https://pchatshepu.vercel.app/` থেকে লোড হয়।
ওয়েবসাইটের কনটেন্ট ও ব্র্যান্ডিং তার নিজস্ব মালিকানাধীন।
