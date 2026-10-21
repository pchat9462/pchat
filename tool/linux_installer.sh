#!/usr/bin/env bash
# Builds the Linux installer: dist/linux/pchat_app-<version>-linux-x64-installer.run
#
# The result is one self-extracting file (a /bin/sh script with a tar.gz
# appended). Run it and it:
#
#   * unpacks the app into ~/.local/share/pchat-app  (a hidden dot-folder, so
#     the binary, data/ and lib/ are not lying around in the home directory)
#   * installs the icon into ~/.local/share/icons/hicolor/{256x256,512x512}/apps
#   * writes ~/.local/share/applications/io.github.shepu1.pchat.desktop, so
#     PCHAT shows up in the Applications menu / app grid
#   * puts a shortcut on the desktop, marked trusted under GNOME
#   * adds a ~/.local/bin/pchat command
#
# App id, icon names and StartupWMClass match tool/app_icons.sh, so a running
# window is matched to its menu entry (that is how Wayland finds the icon).
#
# Uninstall with:  ./pchat_app-<version>-linux-x64-installer.run --uninstall
#
# Usage: tool/linux_installer.sh [<bundle-dir> [<output-file>]]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(sed -n 's/^version: *\([0-9][^+]*\).*/\1/p' "$root/pubspec.yaml" | head -1)"
version="${version:-1.0.0}"

bundle="${1:-$root/build/linux/x64/release/bundle}"
out="${2:-$root/dist/linux/pchat_app-$version-linux-x64-installer.run}"

[[ -d "$bundle" ]] || {
  echo "missing Linux bundle: $bundle (run: flutter build linux --release)" >&2
  exit 1
}
[[ -x "$bundle/pchat_app" ]] || {
  echo "missing executable: $bundle/pchat_app" >&2
  exit 1
}
[[ -f "$root/assets/icon/icon.png" ]] || {
  echo "missing assets/icon/icon.png" >&2
  exit 1
}

if command -v magick >/dev/null 2>&1; then
  im=magick
elif command -v convert >/dev/null 2>&1; then
  im=convert
else
  echo "ImageMagick is required to build the icons (magick or convert)" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# ── Icons: the artwork is not exactly square, pad it with its own corner
#    colour so the padding is invisible (same rule as tool/app_icons.sh) ──
corner="$("$im" "$root/assets/icon/icon.png" -format '%[pixel:p{0,0}]' info:)"
read -r red green blue <<<"$(printf '%s' "$corner" |
  sed -E 's/.*\(([0-9]+),([0-9]+),([0-9]+).*/\1 \2 \3/')"
side="$("$im" "$root/assets/icon/icon.png" -format '%[fx:max(w,h)]' info:)"
"$im" "$root/assets/icon/icon.png" -background "rgb($red,$green,$blue)" \
  -gravity center -extent "${side}x${side}" "$work/square.png"
for size in 256 512; do
  "$im" "$work/square.png" -resize "${size}x${size}" "$work/icon-$size.png"
done

# ── Payload ───────────────────────────────────────────────────────────────
mkdir -p "$work/payload/bundle"
cp -a "$bundle/." "$work/payload/bundle/"
install -m 755 "$root/tool/linux_launcher.sh" "$work/payload/run.sh"
install -m 644 "$work/icon-256.png" "$work/payload/icon-256.png"
install -m 644 "$work/icon-512.png" "$work/payload/icon-512.png"
mkdir -p "$work/payload/gst-plugins"
install -m 644 "$root/tool/vendor/gst/libgstautodetect.so" \
  "$work/payload/gst-plugins/libgstautodetect.so"
install -m 644 "$root/tool/vendor/gst/README.md" \
  "$work/payload/gst-plugins/README.md"
tar -czf "$work/payload.tar.gz" -C "$work/payload" .

# ── Installer header (appended: tar.gz follows the marker line) ───────────
cat >"$work/header" <<'HEADER'
#!/bin/sh
# ============================================================================
#  PCHAT __VERSION__ — Linux installer (x86_64)
#
#  ছোট্ট ইনস্টলার: অ্যাপটা ~/.local/share/pchat-app-এ বসায় (লুকানো ফোল্ডার),
#  Applications মেনু + ডেস্কটপে শর্টকাট বানায়, আর একই icon.png ব্যবহার করে।
#
#  চালান:      sh pchat_app-__VERSION__-linux-x64-installer.run
#  অথবা:       chmod +x …installer.run && ./…installer.run
#  মুছতে:      ./…installer.run --uninstall
#  অপশন:       --no-desktop-shortcut   ডেস্কটপ শর্টকাট ছাড়া
#              --dir <path>           অন্য জায়গায় ইনস্টল
#  root/sudo লাগে না — সবকিছু আপনার নিজের হোম ফোল্ডারে বসে।
# ============================================================================
set -eu

APP_ID="io.github.shepu1.pchat"
APP_NAME="PCHAT"
VERSION="__VERSION__"
MARKER="__PCHAT_PAYLOAD_BELOW__"
HERE="$(pwd)"

say()  { printf '%s\n' "$*"; }
warn() { printf '! %s\n' "$*" >&2; }
die()  { printf '✗ %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
PCHAT $VERSION — Linux installer

  sh $0                  ইনস্টল করুন (বর্তমান ইউজারের জন্য)
  sh $0 --uninstall      আগের ইনস্টল মুছে ফেলুন
  sh $0 --no-desktop-shortcut
                         ডেস্কটপে শর্টকাট না দিয়ে শুধু মেনুতে রাখুন
  sh $0 --dir <path>     অন্য ফোল্ডারে ইনস্টল করুন
  sh $0 -y               ডিপেন্ডেন্সি (webkit2gtk/gtk3) জিজ্ঞেস না করে বসিয়ে দিন
  sh $0 --no-deps        ডিপেন্ডেন্সি হাতে দেবেন না, শুধু অ্যাপ ইনস্টল করুন
  sh $0 --help           এই সাহায্য

root লাগে না — অ্যাপটা আপনার হোম ফোল্ডারে বসে; শুধু ডিপেন্ডেন্সি বসাতে
sudo লাগতে পারে (তখন পাসওয়ার্ড চাইবে)।

chmod +x দেওয়া না থাকলে এভাবেও চলবে:  bash $0
ইনস্টলের পর: Applications মেনু → PCHAT, অথবা টার্মিনালে 'pchat'.
USAGE
}

desktop_dir() {
  dir=""
  if command -v xdg-user-dir >/dev/null 2>&1; then
    dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
  fi
  if [ -z "$dir" ] || [ "$dir" = "$HOME" ]; then
    dir="$HOME/Desktop"
  fi
  printf '%s' "$dir"
}

# ── System libraries the app needs at run time ────────────────────────────
# Everything else ships inside this file; WebKitGTK and GTK are system
# libraries, so their install commands are kept here and the installer offers
# to run them. It only asks when it has a terminal — nothing happens silently.
missing_deps() {
  out=""
  ldconfig -p 2>/dev/null | grep -q 'libwebkit2gtk-4\.1\.so' || out="webkit2gtk-4.1"
  ldconfig -p 2>/dev/null | grep -q 'libgtk-3\.so' || out="${out:+$out }gtk3"
  # WebKit's audio backend needs GStreamer's autoaudiosink; without it the web
  # process aborts when the page plays a notification/ring sound.
  if ! command -v gst-inspect-1.0 >/dev/null 2>&1; then
    out="${out:+$out }gstreamer"
  elif ! gst-inspect-1.0 --exists autoaudiosink >/dev/null 2>&1; then
    out="${out:+$out }gst-plugins-good"
  fi
  printf '%s' "$out"
}

deps_commands() {
  cat <<EOF
     Arch / Manjaro     sudo pacman -S webkit2gtk-4.1 gtk3 gst-plugins-base gst-plugins-good
     Ubuntu / Debian    sudo apt update && sudo apt install libwebkit2gtk-4.1-0 libgtk-3-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good
     Fedora             sudo dnf install webkit2gtk4.1 gtk3 gstreamer1-plugins-base gstreamer1-plugins-good
     openSUSE           sudo zypper install libwebkit2gtk_4_1-0 gtk3 gstreamer-plugins-base gstreamer-plugins-good
EOF
}

install_deps() {
  if command -v pacman >/dev/null 2>&1; then
    set -- pacman -S --needed --noconfirm \
      webkit2gtk-4.1 gtk3 gst-plugins-base gst-plugins-good
  elif command -v apt-get >/dev/null 2>&1; then
    set -- sh -c 'apt-get update && apt-get install -y \
      libwebkit2gtk-4.1-0 libgtk-3-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good'
  elif command -v dnf >/dev/null 2>&1; then
    set -- dnf install -y \
      webkit2gtk4.1 gtk3 gstreamer1-plugins-base gstreamer1-plugins-good
  elif command -v zypper >/dev/null 2>&1; then
    set -- zypper --non-interactive install \
      libwebkit2gtk_4_1-0 gtk3 gstreamer-plugins-base gstreamer-plugins-good
  else
    return 1
  fi

  if [ "$(id -u)" = 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

action=install
desktop_shortcut=1
custom_dir=""
deps_mode=ask

while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) action=uninstall ;;
    --no-desktop-shortcut) desktop_shortcut=0 ;;
    --no-deps) deps_mode=no ;;
    -y|--yes) deps_mode=yes ;;
    --dir)
      shift
      [ $# -gt 0 ] || die "--dir needs a path"
      custom_dir="$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "অজানা অপশন: $1  (--help দেখুন)" ;;
  esac
  shift
done

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
install_dir="${custom_dir:-$data_home/pchat-app}"
icon_root="$data_home/icons/hicolor"
entry_dir="$data_home/applications"
entry="$entry_dir/$APP_ID.desktop"
shortcut="$(desktop_dir)/$APP_NAME.desktop"
bin_dir="$HOME/.local/bin"

refresh_caches() {
  command -v update-desktop-database >/dev/null 2>&1 &&
    update-desktop-database "$entry_dir" >/dev/null 2>&1 || true
}

# ── Uninstall ─────────────────────────────────────────────────────────────
if [ "$action" = uninstall ]; then
  removed=0
  if [ -d "$install_dir" ]; then
    if [ -f "$install_dir/.pchat-install" ]; then
      rm -rf "$install_dir"
      removed=1
    else
      warn "$install_dir আছে কিন্তু PCHAT-এর ইনস্টল নয় — হাত দেওয়া হলো না"
    fi
  fi
  rm -f "$entry" "$shortcut" "$bin_dir/pchat"
  rm -f "$icon_root/256x256/apps/$APP_ID.png" "$icon_root/512x512/apps/$APP_ID.png"
  refresh_caches
  if [ "$removed" = 1 ] || [ -f "$entry" ]; then
    say "✓ PCHAT সরানো হয়েছে"
  else
    say "PCHAT ইনস্টল করা ছিল না — কিছু মুছতে হয়নি"
  fi
  exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────
case "$install_dir" in
  "$HOME"/*) ;;
  *) die "ইনস্টল পাথ হোম ফোল্ডারের ভিতরে হতে হবে (পেয়েছি: $install_dir)" ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

line="$(awk -v m="$MARKER" '$0 == m { print NR + 1; exit }' "$0")"
[ -n "$line" ] || die "installer ফাইলটা অসম্পূর্ণ (payload নেই)"
tail -n +"$line" "$0" | tar -xzf - -C "$tmp" ||
  die "payload খোলা যায়নি — ফাইলটা আবার ডাউনলোড করুন"
[ -x "$tmp/run.sh" ] && [ -d "$tmp/bundle" ] || die "payload অসম্পূর্ণ"

say "PCHAT $VERSION ইনস্টল হচ্ছে…"

rm -rf "$install_dir"
mkdir -p "$install_dir"
cp -a "$tmp/bundle/." "$install_dir/"
install -m 755 "$tmp/run.sh" "$install_dir/run.sh"
chmod +x "$install_dir/pchat_app" 2>/dev/null || true
if [ -d "$tmp/gst-plugins" ]; then
  rm -rf "$install_dir/gst-plugins"
  cp -a "$tmp/gst-plugins" "$install_dir/gst-plugins"
fi
printf '%s\n' "$APP_ID" >"$install_dir/.pchat-install"

for size in 256 512; do
  mkdir -p "$icon_root/${size}x${size}/apps"
  install -m 644 "$tmp/icon-$size.png" "$icon_root/${size}x${size}/apps/$APP_ID.png"
done

mkdir -p "$entry_dir"
cat >"$entry" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=$APP_NAME
Comment=Private peer-to-peer chat
Exec=$install_dir/run.sh
TryExec=$install_dir/run.sh
Icon=$APP_ID
Terminal=false
Categories=Network;InstantMessaging;
StartupNotify=true
StartupWMClass=$APP_ID
DESKTOP
chmod +x "$entry"

if [ "$desktop_shortcut" = 1 ]; then
  mkdir -p "$(desktop_dir)"
  cp "$entry" "$shortcut"
  chmod +x "$shortcut"
  if command -v gio >/dev/null 2>&1; then
    gio set "$shortcut" metadata::trusted true >/dev/null 2>&1 || true
  fi
fi

mkdir -p "$bin_dir"
cat >"$bin_dir/pchat" <<LAUNCHER
#!/bin/sh
exec "$install_dir/run.sh" "\$@"
LAUNCHER
chmod +x "$bin_dir/pchat"

refresh_caches

say ""
say "✓ PCHAT $VERSION ইনস্টল হয়েছে"
say "   অ্যাপ:     $install_dir  (লুকানো ফোল্ডার)"
say "   মেনু:      Applications → PCHAT"
[ "$desktop_shortcut" = 1 ] && say "   শর্টকাট:   $shortcut"
say "   কমান্ড:    pchat"
say ""
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) warn "$bin_dir আপনার PATH-এ নেই — টার্মিনালে শুধু 'pchat' লিখে পাওয়া যাবে না; মেনু/শর্টকাট ঠিক আছে" ;;
esac

missing="$(missing_deps)"
if [ -n "$missing" ]; then
  case "$missing" in
    *webkit2gtk*|*gtk3*)
      warn "এই লাইব্রেরি ছাড়া অ্যাপ চলবে না: $missing"
      ;;
    *)
      if [ -d "$install_dir/gst-plugins" ]; then
        say "i gst-plugins-good নেই — বান্ডল করা autoaudiosink দিয়ে চলবে (sudo ছাড়াই)"
        say "  (ডিস্ট্রোর প্যাকেজ দিলে আরও ভালো; নিচের কমান্ড)"
      else
        warn "সাউন্ডের জন্য এটা দরকার: $missing"
      fi
      ;;
  esac
  deps_commands >&2

  run_deps=0
  if [ "$deps_mode" = yes ]; then
    run_deps=1
  elif [ "$deps_mode" = ask ] && [ -t 0 ]; then
    printf 'এখনই বসিয়ে দেব? (sudo পাসওয়ার্ড চাইতে পারে) [y/N] '
    read -r answer || answer=""
    case "$answer" in y|Y|yes|YES) run_deps=1 ;; esac
  fi

  if [ "$run_deps" = 1 ]; then
    if install_deps; then
      if [ -z "$(missing_deps)" ]; then
        say "✓ ডিপেন্ডেন্সি ইনস্টল হয়েছে"
      else
        warn "কিছু এখনো নেই: $(missing_deps) — উপরের কমান্ড নিজে চালান"
      fi
    else
      warn "স্বয়ংক্রিয়ভাবে ইনস্টল করা গেল না — উপরের কমান্ড নিজে চালান"
    fi
  fi
fi

say "মুছতে:  sh $0 --uninstall"
exit 0
HEADER

# The last line of the script — everything after it is the tar.gz payload.
printf '%s\n' '__PCHAT_PAYLOAD_BELOW__' >>"$work/header"

sed -i "s|__VERSION__|$version|g" "$work/header"

mkdir -p "$(dirname "$out")"
cat "$work/header" "$work/payload.tar.gz" >"$out"
chmod 755 "$out"

printf 'installer: %s (%s)\n' "$out" "$(du -h "$out" | cut -f1)"
