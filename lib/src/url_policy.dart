import 'app_config.dart';

/// What the app should do with a URL the page asked to open.
enum UrlDisposition {
  /// Load it in the embedded web view.
  inApp,

  /// Hand it to the operating system (browser, mail client, dialer, ...).
  external,

  /// Drop it.
  block,
}

final RegExp _extension = RegExp(r'\.[a-z0-9]{2,5}$', caseSensitive: false);

/// File extensions that are still *pages*, not static assets.
const Set<String> _documentExtensions = <String>{'html', 'htm'};

/// True when [url] points at a static file (icon, css, js, image, ...) rather
/// than at a document.
///
/// Used to ignore failed sub-resource loads when deciding whether the *page*
/// failed, so a missing favicon never replaces the app with an error screen.
bool looksLikeAsset(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return false;
  final String path = uri.path.toLowerCase();
  if (path.isEmpty || path.endsWith('/')) return false;
  final RegExpMatch? match = _extension.firstMatch(path);
  if (match == null) return false;
  return !_documentExtensions.contains(match.group(0)!.substring(1));
}

/// Decides how to handle [raw] without touching any platform API.
///
/// This is the security boundary of the wrapper: only [AppConfig.inAppHosts]
/// ever load inside the app.
UrlDisposition classifyUrl(String? raw) {
  if (raw == null) return UrlDisposition.block;
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return UrlDisposition.block;

  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) return UrlDisposition.block;

  final String scheme = uri.scheme.toLowerCase();
  switch (scheme) {
    case '':
      // A relative URL — the page itself is resolving it, keep it in-app.
      return UrlDisposition.inApp;
    case 'http':
    case 'https':
      final String host = uri.host.toLowerCase();
      return AppConfig.inAppHosts.contains(host)
          ? UrlDisposition.inApp
          : UrlDisposition.external;
    case 'about':
    case 'blob':
    case 'data':
      // `about:blank`, blob previews and inline data are always same-page.
      return UrlDisposition.inApp;
    case 'javascript':
    case 'file':
    case 'content':
      return UrlDisposition.block;
    default:
      // mailto:, tel:, sms:, market:, intent:, ... — the OS knows best.
      return UrlDisposition.external;
  }
}
