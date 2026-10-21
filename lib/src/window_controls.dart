import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';

/// Talks to the Linux/Windows runners, which own the real window.
///
/// The desktop window is borderless and fullscreen, so the operating system
/// draws no title bar; these two calls are the whole replacement.
const MethodChannel _windowChannel = MethodChannel(AppConfig.windowChannel);

/// Iconifies the window.
Future<void> minimizeWindow() => _windowChannel.invokeMethod<void>('minimize');

/// Closes the app.
Future<void> closeWindow() => _windowChannel.invokeMethod<void>('close');

/// The thin bar that replaces the system title bar on Windows and Linux.
///
/// One reload button on the left, minimize and close on the right.
///
/// It is deliberately transparent — the scaffold's canvas colour shows through,
/// which is the same `#070A12` the site paints along its top edge — and only
/// [height] logical pixels tall, so it reads as part of the page's own dark
/// header.
///
/// On Linux the engine draws the WebView in a native GTK overlay *above*
/// Flutter's canvas, so this bar cannot float over the page; the WebView is
/// laid out below it instead.
class DesktopWindowControls extends StatelessWidget {
  const DesktopWindowControls({
    super.key,
    required this.onRefresh,
    required this.onMinimize,
    required this.onClose,
  });

  /// Height of the bar, and of each of its buttons.
  static const double height = 32;

  /// Reloads the page.
  final VoidCallback onRefresh;

  final VoidCallback onMinimize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: <Widget>[
            // Refresh sits on its own at the start of the bar, away from the
            // window buttons, so it can never be hit by accident.
            _WindowButton(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              onPressed: onRefresh,
            ),
            const Spacer(),
            _WindowButton(
              icon: Icons.remove_rounded,
              label: 'Minimize',
              onPressed: onMinimize,
            ),
            const SizedBox(width: 4),
            _WindowButton(
              icon: Icons.close_rounded,
              label: 'Close',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        // Its own material so the ink reaction is drawn above the WebView.
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 16, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
