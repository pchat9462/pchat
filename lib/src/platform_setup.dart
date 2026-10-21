import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:webview_all/webview_all.dart';
import 'package:webview_all_android/webview_all_android.dart';
import 'package:webview_all_linux/webview_all_linux.dart';
import 'package:webview_all_windows/webview_all_windows.dart';

import 'app_config.dart';

/// Everything in this file is the only place that knows about individual
/// platforms, so the screen itself stays engine-agnostic.

/// Engine settings per platform.
///
/// Each platform gets the parameters that matter for a *chat* app:
/// media that is allowed to start without an extra click (voice notes, calls)
/// and downloads that are actually allowed to happen.
PlatformWebViewControllerCreationParams createControllerParams() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // The Android implementation already enables DOM storage, JavaScript
      // popups and multi-window support for us.
      return AndroidWebViewControllerCreationParams();

    case TargetPlatform.linux:
      return const LinuxWebViewControllerCreationParams(
        // Voice messages and calls must start on their own.
        mediaPlaybackRequiresUserGesture: false,
        mediaPlaybackAllowsInline: true,
        javascriptCanOpenWindowsAutomatically: true,
        downloadsEnabled: true,
        pageCacheEnabled: true,
      );

    case TargetPlatform.windows:
      return const WindowsWebViewControllerCreationParams(
        // A `target="_blank"` that we did not intercept simply reuses the
        // window instead of leaking an invisible second one.
        popupWindowPolicy: WindowsPopupWindowPolicy.sameWindow,
        downloadsEnabled: true,
        browserAcceleratorKeysEnabled: true,
      );

    default:
      return const PlatformWebViewControllerCreationParams();
  }
}

/// Wires up platform-only controller APIs.
///
/// * Android: answers `<input type="file">` with the native file chooser. The
///   desktop engines open their own dialog and need no Dart callback.
void attachPlatformController(
  WebViewController controller, {
  required Future<List<String>> Function(FileSelectorParams params)
  onShowFileSelector,
}) {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final platform = controller.platform;
  if (platform is! AndroidWebViewController) return;
  unawaited(platform.setOnShowFileSelector(onShowFileSelector));
  // The plugin turns the wide viewport *off*, which means the page's own
  // `<meta name="viewport" content="width=device-width">` is ignored and the
  // site is laid out for a desktop-width window: on a phone the chat UI then
  // runs off both sides of the screen. Turning it back on makes the system
  // WebView lay the page out the way Chrome for Android does.
  unawaited(platform.setUseWideViewPort(true));
  // Voice notes and a ringing call have to be able to start on their own here
  // too: the system WebView defaults to *requiring* a user gesture, which would
  // swallow the first ringtone of an incoming call. The desktop engines get the
  // same setting through their creation params.
  unawaited(platform.setMediaPlaybackRequiresUserGesture(false));
}

/// True on the platforms whose runner draws no window decorations at all.
///
/// Windows and Linux start borderless, so the app has to draw its own
/// minimize/close buttons. Android keeps the system's own chrome.
bool get usesDesktopWindowControls =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// The offline artwork that matches the shape of this screen.
///
/// Phones get the portrait drawing, desktop windows the wide one; both carry
/// the same "Connection Lost" wording, so nothing has to be repeated in text.
String get offlineImage => defaultTargetPlatform == TargetPlatform.android
    ? AppConfig.offlineImagePhone
    : AppConfig.offlineImageDesktop;

/// True when the request is the camera/microphone kind, the only one with an
/// operating system permission of its own behind it.
///
/// Everything else an engine asks about — screen sharing, the device list,
/// clipboard reads, desktop notifications — arrives with an **empty** type set:
/// both WebKitGTK and WebView2 report those without a type (the Windows plugin
/// maps `clipboardRead`, `notifications`, `geoLocation` and `otherSensors` to
/// an empty set, and the Linux plugin only fills in camera/microphone). So an
/// empty set is never a camera/microphone ask.
bool isMediaPermissionRequest(Set<WebViewPermissionResourceType> types) =>
    types.contains(WebViewPermissionResourceType.camera) ||
    types.contains(WebViewPermissionResourceType.microphone);

/// Asks the operating system for the permissions a WebRTC call needs.
///
/// The WebView only decides whether the *page* may use the camera; Android
/// additionally requires the app itself to hold the runtime permission. On
/// desktop the OS/engine owns this, so it is treated as granted.
Future<bool> requestMediaPermissions({
  required bool camera,
  required bool microphone,
}) async {
  if (defaultTargetPlatform != TargetPlatform.android) return true;

  final List<permissions.Permission> wanted = <permissions.Permission>[
    if (camera) permissions.Permission.camera,
    if (microphone) permissions.Permission.microphone,
  ];
  if (wanted.isEmpty) return true;

  final Map<permissions.Permission, permissions.PermissionStatus> result =
      await wanted.request();

  // "Don't allow again" cannot be answered with a dialog, so send the user to
  // the one screen that can undo it. Without this a call would just fail with
  // nothing on screen to explain why.
  if (result.values.any((status) => status.isPermanentlyDenied)) {
    await permissions.openAppSettings();
  }

  return result.values.every((status) => status.isGranted);
}

/// Opens the native file chooser for a page `<input type="file">`.
Future<List<String>> pickFilesForWebInput(FileSelectorParams params) async {
  try {
    final List<XTypeGroup> typeGroups = _typeGroups(params.acceptTypes);
    if (params.mode == FileSelectorMode.openMultiple) {
      final List<XFile> files = await openFiles(acceptedTypeGroups: typeGroups);
      return files
          .map((XFile file) => webViewFilePath(file.path))
          .where((String path) => path.isNotEmpty)
          .toList(growable: false);
    }
    final XFile? file = await openFile(acceptedTypeGroups: typeGroups);
    final String? path = file?.path;
    return (path == null || path.isEmpty)
        ? const <String>[]
        : <String>[webViewFilePath(path)];
  } catch (_) {
    // A cancelled or failing picker must never break the page.
    return const <String>[];
  }
}

/// The URI form of a picked file, which is what Android's WebView wants.
///
/// The engine passes every string straight to `Uri.parse`, so a bare path —
/// which is exactly what the picker returns, because `file_selector` first
/// copies the chosen file into the app's own cache — becomes a URI with no
/// scheme, and the WebView then silently uploads nothing at all. Turning it
/// into a `file://` URI is the difference between a working attachment button
/// and one that appears to do nothing. Anything the picker already reports as a
/// URI (a `content://` one, say) is left untouched.
String webViewFilePath(String pickedPath) =>
    pickedPath.contains('://') ? pickedPath : Uri.file(pickedPath).toString();

List<XTypeGroup> _typeGroups(List<String> acceptTypes) {
  final List<XTypeGroup> groups = <XTypeGroup>[];
  for (final String raw in acceptTypes) {
    final String type = raw.trim().toLowerCase();
    if (type.isEmpty || type == '*/*') continue;
    if (type.startsWith('.')) {
      groups.add(
        XTypeGroup(label: 'Files', extensions: <String>[type.substring(1)]),
      );
    } else if (type.contains('/')) {
      groups.add(XTypeGroup(label: 'Files', mimeTypes: <String>[type]));
    } else {
      groups.add(XTypeGroup(label: 'Files', extensions: <String>[type]));
    }
  }
  return groups;
}
