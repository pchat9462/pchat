/// Single source of truth for the wrapper's behaviour.
///
/// Everything the app needs to know about *which* site it wraps lives here, so
/// changing the target website (or the set of hosts that are allowed to stay
/// inside the app) is a one-line edit.
class AppConfig {
  const AppConfig._();

  /// The page that is always opened when the app starts.
  ///
  /// The Vercel deployment is the live one; it serves the same file layout as
  /// the old GitHub Pages copy and redirects `/` to `/pchat/index.html`.
  static const String startUrl = 'https://pchatshepu.vercel.app/';

  /// Window / launcher / task title.
  static const String appTitle = 'PCHAT';

  /// Hosts that are allowed to load *inside* the app.
  ///
  /// Anything else is handed to the operating system instead, which keeps the
  /// app focused on PCHAT and keeps third-party logins in a real browser.
  static const Set<String> inAppHosts = <String>{'pchatshepu.vercel.app'};

  /// Name of the JavaScript channel used to answer `window.open(...)` and
  /// `target="_blank"` clicks coming from the page.
  static const String bridgeChannel = 'PChatBridge';

  /// Marker prefix the page uses to tell us "this is a file download".
  static const String downloadPrefix = 'download:';

  /// Method channel used by the desktop window controls (minimize / close).
  ///
  /// Implemented by the Linux and Windows runners, which own the real window.
  static const String windowChannel = 'io.github.shepu1.pchat/window';

  /// Animation shown small and centred while the page is loading.
  static const String loadingAnimation = 'assets/animations/animation.apng';

  /// Offline artwork, wide version, for desktop windows (Linux / Windows).
  static const String offlineImageDesktop = 'assets/images/c_lost_desktop.png';

  /// Offline artwork, tall version, for phones.
  static const String offlineImagePhone = 'assets/images/c_lost_phone.png';

  /// Dark canvas colour, matching the PCHAT theme (`--hub-bg-canvas`), so the
  /// window never flashes white while the page is loading.
  static const int canvasColor = 0xFF070A12;
}
