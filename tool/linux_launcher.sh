#!/usr/bin/env bash
# Starts PCHAT on Linux.
#
# Two system pieces are checked first, because without them the app either
# aborts with a half-written message or dies a few seconds after the page
# starts playing a sound:
#
#   * WebKitGTK / GTK — the engine that draws the site.
#   * GStreamer's `autoaudiosink` (gst-plugins-good) — WebKit's audio backend.
#     Missing it makes the *web process* abort (SIGABRT) as soon as the chat
#     plays a notification/ring sound. A copy of that one plugin ships in
#     gst-plugins/ next to this file and is used only when the system lacks it,
#     so the app works without root; installing gst-plugins-good is better.
#
# This is also the target of the desktop entry and ~/.local/bin/pchat, so the
# directory is resolved from the real file, not from the symlink.

set -e

# readlink -f follows the symlink chain; the fallback keeps the path as given
# if the tool is unavailable.
self="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
cd "$(cd "$(dirname "$self")" && pwd)"

missing=""
if ! ldconfig -p 2>/dev/null | grep -q 'libwebkit2gtk-4\.1\.so'; then
  missing="webkit2gtk-4.1"
fi
if ! ldconfig -p 2>/dev/null | grep -q 'libgtk-3\.so'; then
  missing="${missing:+$missing, }gtk3"
fi

# Audio backend. Resolved here so the message below can name the right package.
audio_missing=""
if ! command -v gst-inspect-1.0 >/dev/null 2>&1; then
  audio_missing="gstreamer"
elif ! gst-inspect-1.0 --exists autoaudiosink >/dev/null 2>&1; then
  audio_missing="gst-plugins-good"
fi
if [[ -n "$audio_missing" && -d "$PWD/gst-plugins" ]]; then
  export GST_PLUGIN_PATH="$PWD/gst-plugins${GST_PLUGIN_PATH:+:$GST_PLUGIN_PATH}"
  audio_missing=""
fi

if [[ -n "$missing" || -n "$audio_missing" ]]; then
  packages="${missing}${missing:+${audio_missing:+, }}${audio_missing}"
  message="PCHAT চালু করা যায়নি — এই লাইব্রেরিগুলো নেই: $packages

  Arch / Manjaro     sudo pacman -S webkit2gtk-4.1 gtk3 gst-plugins-base gst-plugins-good
  Ubuntu / Debian    sudo apt install libwebkit2gtk-4.1-0 libgtk-3-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good
  Fedora             sudo dnf install webkit2gtk4.1 gtk3 gstreamer1-plugins-base gstreamer1-plugins-good
  openSUSE           sudo zypper install libwebkit2gtk-4_1-0 gtk3 gstreamer-plugins-base gstreamer-plugins-good

ইনস্টলের পর আবার চালান:  pchat   (অথবা মেনু থেকে PCHAT)"
  # Started from the menu there is no terminal to read, so show a dialog too.
  if command -v zenity >/dev/null 2>&1; then
    zenity --error --title="PCHAT" --no-wrap --text="$message" 2>/dev/null || true
  elif command -v kdialog >/dev/null 2>&1; then
    kdialog --title "PCHAT" --error "$message" 2>/dev/null || true
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "PCHAT" "$message" 2>/dev/null || true
  fi
  printf '%s\n' "$message" >&2
  exit 1
fi

exec ./pchat_app "$@"
