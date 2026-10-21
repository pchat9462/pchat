# PCHAT — রিলিজ প্যাকেজ

সাইট: `https://pchatshepu.vercel.app/` · এটি একটি ওয়েব-অ্যাপ র‍্যাপার; অ্যাপ লজিক সাইট থেকেই আসে।
উৎস কোড ও বিস্তারিত (বাংলা) ডকুমেন্টেশন: প্রজেক্টের `README.md`।

## কোন ফাইল কার জন্য

| ফাইল | কী | কীভাবে চালাবেন |
|---|---|---|
| `linux/pchat_app-<ver>-linux-x64-installer.run` | **Linux ইনস্টলার** — Applications মেনু + ডেস্কটপে শর্টকাট, একই আইকন, ফাইলগুলো লুকানো ফোল্ডারে | `chmod +x …installer.run && ./…installer.run` |
| `linux/pchat_app-<ver>-linux-x64.tar.gz` | Linux/Arch বিল্ড (অ্যাপ + `run.sh` + `data/` + `lib/`) | `tar xzf …` → `cd pchat_app-<ver>` → `./run.sh` |
| `android/pchat_app-<ver>.apk` | **একটাই APK — সব Android ফোনে চলে** | ফোনে কপি করে ট্যাপ করুন, বা `adb install -r dist/android/pchat_app-<ver>.apk` |
| `windows/…-windows-x64.zip` | Windows | GitHub Actions দিয়ে বানান (নিচে) বা Windows মেশিনে `tool\build_windows.ps1` |
| `SHA256SUMS` | সব ফাইলের চেকসাম | `cd dist && sha256sum -c SHA256SUMS` |

> ফোনের জন্য আলাদা আলাদা APK লাগে না — উপরের একটিই যথেষ্ট। প্রকাশের সময় দরকার হলে
> `tool/package_release.sh --all-android` চালালে per-ABI APK আর Play Store-এর `.aab`-ও তৈরি হবে।

## Linux-এ ইনস্টল (ইনস্টলার)

```bash
chmod +x pchat_app-<ver>-linux-x64-installer.run
./pchat_app-<ver>-linux-x64-installer.run
```

এটি যা করে (কোনো `sudo` লাগে না, শুধু ডিপেন্ডেন্সি বসাতে চাইতে পারে):

- অ্যাপ বসায় `~/.local/share/pchat-app`-এ — হোম ফোল্ডারে কোনো ফাইল/ফোল্ডার দেখা যাবে না
- **Applications মেনুতে PCHAT** এন্ট্রি (`~/.local/share/applications/io.github.shepu1.pchat.desktop`)
- **ডেস্কটপে PCHAT শর্টকাট** (GNOME-এ নিজে থেকেই "trusted" করা হয়; প্রথমবার ডাবল-ক্লিকে
  "Allow Launching" চাইলে সেটাই অনুমোদন করুন)
- আইকন: `assets/icon/icon.png` থেকেই ২৫৬px ও ৫১২px — অ্যাপ, মেনু এন্ট্রি, শর্টকাট সবখানে একই আইকন
- টার্মিনালে `pchat` কমান্ড (`~/.local/bin/pchat`)
- **ডিপেন্ডেন্সি:** `webkit2gtk-4.1` ও `gtk3` না থাকলে ইনস্টলার নিজেই চার ডিস্ট্রোর সঠিক কমান্ড
  দেখায়, আর টার্মিনালে চাইলে `sudo` দিয়ে নিজেই বসিয়ে দেয় (`-y` দিলে না জিজ্ঞেস করে)।
- **পেজ বদলানোর ঝাঁকুনি:** সাইটের entrance animation (`fadeIn`/`fadeInUp`/`scaleIn`/`msgIn`) অ্যাপের
  ভিতরে বন্ধ/শেষ অবস্থায় পৌঁছে দেওয়া হয় (`lib/src/page_smoothing.dart`, document-start user script) —
  তাই এক পেজ থেকে আরেক পেজে গেলে কনটেন্ট আর লাফ দেয় না। সাইটের CSS-ও opacity-only করা আছে।
  `chmod +x` দিতে না চাইলে সরাসরি: `bash pchat_app-<ver>-linux-x64-installer.run`

অন্য জায়গায় বসাতে: `./…installer.run --dir ~/Apps/pchat` · ডেস্কটপ শর্টকাট ছাড়া: `--no-desktop-shortcut`
· ডিপেন্ডেন্সি নিজে না বসাতে: `--no-deps` · মুছতে: `./…installer.run --uninstall`।


## দরকার যা লাগবে

- **Linux:** `webkit2gtk-4.1`, `gtk3` আর GStreamer-এর `gst-plugins-base` + `gst-plugins-good` —
  `sudo pacman -S webkit2gtk-4.1 gtk3 gst-plugins-base gst-plugins-good`
  (Ubuntu: `sudo apt install libwebkit2gtk-4.1-0 libgtk-3-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good`,
  Fedora: `sudo dnf install webkit2gtk4.1 gtk3 gstreamer1-plugins-base gstreamer1-plugins-good`)।
  **না থাকলে `run.sh` নিজেই বলে দেবে কী ইনস্টল করতে হবে** (আগে অ্যাপটি ওই লাইব্রেরি ছাড়া চুপচাপ crash করত)।
  `gst-plugins-good` না থাকলে অ্যাপ খোলার ১০-২০ সেকেন্ড পরেই বন্ধ হয়ে যায় (WebKit-এর web process
  সাউন্ড বাজাতে গিয়ে abort করে) — ইনস্টলার ওই একটি প্লাগিন নিজের সাথে বান্ডল করে রাখে, তাই
  `sudo` ছাড়াও চলে; ডিস্ট্রোর প্যাকেজ দিলে সেটাই সবচেয়ে ভালো।
  X11/XWayland দরকার — Wayland-only সেশনে XWayland চালু থাকতে হবে।
- **Android:** Android 7.0 (API 24) বা তার উপরে। চ্যাট করতে কোনো পারমিশন লাগে না; ভয়েস/ভিডিও কল
  শুরু করলেই ক্যামেরা-মাইকের অনুমতি চাওয়া হবে। ইনস্টল করতে "Install unknown apps" চালু করা লাগবে।
- **Windows:** Windows 10/11 + WebView2 Runtime (আধুনিক Windows-এ আগে থেকেই থাকে)।

## হঠাৎ "network error" দেখালে

অ্যাপ নয় — **DNS**। আপনার রাউটারের DNS মাঝে মাঝে `pchatshepu.vercel.app`-এর জন্য পৌঁছানো-যায় না
এমন IP (`64.29.17.131`, `216.198.79.131`) ফেরত দেয়; তখন অ্যাপ ঠিকই "সংযোগ পাওয়া যায়নি" স্ক্রিন দেখায়।

```bash
# পরীক্ষা: timeout আসলে DNS-এর দোষ
curl -sS -m 8 -o /dev/null -w '%{http_code}\n' https://pchatshepu.vercel.app/pchat/index.html
curl -sS -m 8 -o /dev/null -w '%{http_code}\n' https://example.com      # এটা 200 হলে ইন্টারনেট ঠিক

# স্থায়ী সমাধান: রাউটার/পিসির DNS 1.1.1.1 + 8.8.8.8 করুন
sudo nmcli con mod "<connection name>" ipv4.dns "1.1.1.1 8.8.8.8" ipv4.ignore-auto-dns yes
sudo nmcli con up "<connection name>"

# অথবা দ্রুত কাজ চালানোর জন্য Vercel-এর anycast IP পিন করুন
echo '216.198.79.3 pchatshepu.vercel.app' | sudo tee -a /etc/hosts
# মুছতে: sudo sed -i '/pchatshepu.vercel.app/d' /etc/hosts
```

## Windows `.exe` এখানে নেই কেন

Linux-এ MSVC টুলচেইন থাকে না, তাই Windows বিল্ড এই প্যাকেজে তৈরি হয় না। Windows PC না থাকলেও
সমাধান আছে — **GitHub Actions** (`.github/workflows/release.yml`, শুধু Windows জব):

1. প্রজেক্টটা একটা GitHub রিপোতে পুশ করুন
2. Actions → **Build Windows exe** → *Run workflow*
3. রান শেষ হলে `pchat-windows` artifact-এ `pchat_app-<ver>-windows-x64.zip` নামবে

নিজের Windows মেশিন থাকলে Flutter + Visual Studio 2022 ("Desktop development with C++") দিয়ে
এক কমান্ডেই হয়:

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
```

**পুরো ফোল্ডারটি** বিতরণ করতে হবে (`data\` আর `*.dll` ফাইলগুলো `.exe`-এর পাশে থাকা বাধ্যতামূলক) —
শুধু `.exe` কপি করলে চলবে না।

## সাইনিং সম্পর্কে ⚠️

APK/AAB গুলো **ডিবাগ key** দিয়ে সাইন করা (যাতে `flutter build apk --release` সাথে সাথে কাজ করে)।
নিজের ফোনে ইনস্টল করতে বা বন্ধুদের দিতে কোনো সমস্যা নেই, কিন্তু **Google Play-তে দেওয়ার আগে**
নিজের keystore দিয়ে সাইন করতে হবে — `README.md` বিভাগ ৪-এ (`keytool` + `signingConfigs`) ধাপে ধাপে লেখা আছে।

## আবার নতুন করে প্যাক করতে

```bash
tool/package_release.sh                        # Linux + Android (এক APK), dist/-এ
tool/package_release.sh --all-android          # সাথে per-ABI APK ও Play Bundle
PCHAT_SYSROOT=/path tool/package_release.sh    # সিস্টেমে webkit2gtk-4.1 না থাকলে
```
