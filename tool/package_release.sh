#!/usr/bin/env bash
# Builds every artefact this machine can produce and collects them in dist/.
#
#   Linux   -> dist/linux/pchat_app-<version>-linux-x64-installer.run
#              (one self-extracting installer: puts the app in a hidden
#              ~/.local/share folder, adds Applications-menu + desktop
#              shortcuts and the app icon; no root needed)
#           -> dist/linux/pchat_app-<version>-linux-x64.tar.gz   (portable tar
#              of the release bundle: the executable, data/, lib/ and run.sh)
#   Android -> dist/android/pchat_app-<version>.apk              (one APK for any phone)
#              with --all-android: the per-ABI splits and the Play Store .aab
#   Windows -> cannot be built off Windows; dist/windows/ gets the one-click
#              PowerShell script instead (run it on Windows).
#
# Everything is also listed with SHA-256 sums in dist/SHA256SUMS.
#
# Usage:  tool/package_release.sh [--all-android]
#   override toolchains with the usual variables: JAVA_HOME, ANDROID_HOME
#   point a local webkit2gtk sysroot at the build with: PCHAT_SYSROOT=/path

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="$(sed -n 's/^version: *\([0-9][^+]*\).*/\1/p' pubspec.yaml | head -1)"
NAME="pchat_app-${VERSION:-1.0.0}"
DIST="$ROOT/dist"

# ── Toolchain ─────────────────────────────────────────────────────────────
# Use whatever is in the environment; fall back to a local install if the
# machine keeps the JDK/SDK somewhere non-standard (see README section ৩).
if [[ -z "${JAVA_HOME:-}" ]]; then
  for candidate in /mnt/storage/jdk/jdk-*; do
    [[ -x "$candidate/bin/javac" ]] && export JAVA_HOME="$candidate"
  done
fi
if [[ -z "${ANDROID_HOME:-}" && -d /mnt/storage/android-sdk ]]; then
  export ANDROID_HOME=/mnt/storage/android-sdk
fi
[[ -n "${JAVA_HOME:-}" ]] && export PATH="$JAVA_HOME/bin:$PATH"
[[ -n "${ANDROID_HOME:-}" ]] && export ANDROID_SDK_ROOT="$ANDROID_HOME"
if [[ -n "${PCHAT_SYSROOT:-}" && -d "$PCHAT_SYSROOT/usr/lib/pkgconfig" ]]; then
  export PKG_CONFIG_PATH="$PCHAT_SYSROOT/usr/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
fi

rm -rf "$DIST"
mkdir -p "$DIST/linux" "$DIST/android" "$DIST/windows"

# ── Linux (Arch and friends) ──────────────────────────────────────────────
echo "== [1/3] Linux release bundle =="
flutter build linux --release
mkdir -p "$DIST/linux/$NAME"
cp -a build/linux/x64/release/bundle/. "$DIST/linux/$NAME/"
install -m 755 tool/linux_launcher.sh "$DIST/linux/$NAME/run.sh"
# Fallback for systems without gst-plugins-good (WebKit's autoaudiosink).
mkdir -p "$DIST/linux/$NAME/gst-plugins"
install -m 644 tool/vendor/gst/libgstautodetect.so \
  "$DIST/linux/$NAME/gst-plugins/libgstautodetect.so"
install -m 644 tool/vendor/gst/README.md "$DIST/linux/$NAME/gst-plugins/README.md"
tar -czf "$DIST/linux/$NAME-linux-x64.tar.gz" -C "$DIST/linux" "$NAME"
rm -rf "$DIST/linux/$NAME"
tool/linux_installer.sh build/linux/x64/release/bundle \
  "$DIST/linux/$NAME-linux-x64-installer.run"

# ── Android ───────────────────────────────────────────────────────────────
# One APK that installs on every phone. Pass --all-android to also produce the
# per-ABI splits and the Play Store bundle, which only matter when publishing.
echo "== [2/3] Android APK =="
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "$DIST/android/$NAME.apk"

if [[ "${1:-}" == "--all-android" ]]; then
  echo "== [2/3] Android APK (per ABI) =="
  flutter build apk --release --split-per-abi
  for abi in arm64-v8a armeabi-v7a x86_64; do
    src="build/app/outputs/flutter-apk/app-$abi-release.apk"
    [[ -f "$src" ]] && cp "$src" "$DIST/android/$NAME-$abi.apk"
  done

  echo "== [2/3] Android App Bundle (Play Store) =="
  flutter build appbundle --release
  cp build/app/outputs/bundle/release/app-release.aab "$DIST/android/$NAME.aab"
fi

# ── Windows: script only, the build itself needs Windows ──────────────────
cp tool/build_windows.ps1 "$DIST/windows/"
cat > "$DIST/windows/HOW-TO-BUILD.txt" <<'EOF'
Windows .exe cannot be produced on Linux: it needs the MSVC toolchain.

On a Windows machine with Flutter + Visual Studio 2022
("Desktop development with C++"):

    powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1

That produces, in dist\windows\:
    pchat_app-<version>-windows-x64\        <- run pchat_app.exe from here
    pchat_app-<version>-windows-x64.zip     <- what you hand out

Ship the WHOLE folder (data\ and the .dll files next to the .exe), not the
.exe alone. Users need the WebView2 Runtime, which ships with Windows 10/11.
EOF

# ── Release notes ─────────────────────────────────────────────────────────
cp tool/dist_readme.md "$DIST/README.md"

# ── Checksums ─────────────────────────────────────────────────────────────
echo "== [3/3] SHA-256 sums =="
(cd "$DIST" && find . -type f ! -name SHA256SUMS -print0 |
  sort -z | xargs -0 sha256sum > SHA256SUMS)

echo
echo "== done: $DIST =="
find "$DIST" -type f | sort | while read -r file; do
  printf '%10s  %s\n' "$(du -h "$file" | cut -f1)" "${file#"$ROOT"/}"
done
