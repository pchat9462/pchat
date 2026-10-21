# Bundled GStreamer plugin

`libgstautodetect.so` comes from the Arch Linux package **gst-plugins-good
1.28.8-1** (GStreamer is LGPL-2.1-or-later; source: https://gstreamer.freedesktop.org/).

Why it is here: WebKitGTK's audio backend asks GStreamer for the
`autoaudiosink` element. When the system has no `gst-plugins-good`, the element
is missing and the WebKit *web process* aborts (`SIGABRT`) a few seconds after
the page starts playing a sound — the chat app plays notification/ring sounds,
so it hit this every time.

`tool/linux_installer.sh` ships this one plugin next to the app, and
`run.sh` points `GST_PLUGIN_PATH` at it **only** when the system's own
`autoaudiosink` is missing. Installing `gst-plugins-good` from the distro is
still the recommended fix; the bundled copy is the no-root fallback.
