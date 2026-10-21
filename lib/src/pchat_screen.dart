import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_all/webview_all.dart';

import 'app_config.dart';
import 'google_auth.dart';
import 'page_smoothing.dart';
import 'platform_setup.dart';
import 'popup_bridge.dart';
import 'status_overlay.dart';
import 'url_policy.dart';
import 'window_controls.dart';

/// The whole app: a full-bleed PCHAT WebView plus the minimum chrome needed to
/// survive a bad network.
class PChatScreen extends StatefulWidget {
  const PChatScreen({super.key});

  @override
  State<PChatScreen> createState() => _PChatScreenState();
}

class _PChatScreenState extends State<PChatScreen> {
  late final WebViewController _controller;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// True while the device itself reports no network at all.
  bool _isOffline = false;

  /// True once a real PCHAT document has been shown.
  bool _hasLoadedOnce = false;

  /// True while a navigation is in flight.
  bool _isLoading = true;

  /// The last main-document failure, kept until a real page loads again.
  String? _loadError;

  /// True when that failure was a connection-level one, i.e. the server was
  /// never reached. Such a page is indistinguishable from a device with no
  /// network, so both get the same screen.
  bool _connectionFailure = false;

  /// Keeps a second tap from stacking a second sign-in popup.
  bool _authInProgress = false;

  /// Retries a page that failed on its own, so the app comes back the moment
  /// the network does. The connectivity events alone are not enough: WebKitGTK
  /// on Linux never delivers them.
  Timer? _autoRetry;

  /// How long a connectivity answer is worth waiting for. It is only ever used
  /// to avoid a pointless reload, so waiting longer than this serves nobody —
  /// and on Linux the call never answers at all.
  static const Duration _connectivityTimeout = Duration(seconds: 1);

  /// How long to wait between automatic retries of a page that failed.
  static const Duration _autoRetryDelay = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _controller = _createController();
    unawaited(_controller.setNavigationDelegate(_createNavigationDelegate()));
    _watchConnectivity();
    unawaited(_start());
  }

  @override
  void dispose() {
    _autoRetry?.cancel();
    _autoRetry = null;
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
    super.dispose();
  }

  // ── WebView wiring ──────────────────────────────────────────────────────

  WebViewController _createController() {
    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(
          createControllerParams(),
          onPermissionRequest: _handlePermissionRequest,
        );

    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(
      controller.setBackgroundColor(const Color(AppConfig.canvasColor)),
    );
    unawaited(
      controller.addJavaScriptChannel(
        AppConfig.bridgeChannel,
        onMessageReceived: _handleBridgeMessage,
      ),
    );

    attachPlatformController(
      controller,
      onShowFileSelector: pickFilesForWebInput,
    );
    return controller;
  }

  NavigationDelegate _createNavigationDelegate() {
    return NavigationDelegate(
      onNavigationRequest: _handleNavigationRequest,
      onPageStarted: (String url) {
        // The error is *not* cleared here: the engine fires this again for the
        // failing URL when it commits its own error page, and dropping the
        // error there is what used to leave the user staring at the engine's
        // error page instead of the app's screen.
        if (!mounted) return;
        setState(() => _isLoading = true);
      },
      onPageFinished: (String url) => unawaited(_handlePageFinished()),
      onWebResourceError: _handleWebResourceError,
    );
  }

  /// Runs when a document finishes loading.
  ///
  /// A *failed* navigation ends here too: the engine commits an error
  /// document of its own. That document has no address of its own (WebKit puts
  /// it at `about:blank`), so asking the page where it is tells a real load
  /// apart from an error page — the URL handed to this callback is the failing
  /// one either way.
  Future<void> _handlePageFinished() async {
    final bool loaded = await _pageActuallyLoaded();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (loaded) {
        // A real document: the site is up, so an earlier failure is history.
        _hasLoadedOnce = true;
        _loadError = null;
        _connectionFailure = false;
      } else {
        // Keep the failure that was reported for this navigation on screen. The
        // fallback keeps a WebView that somehow ends up blank from leaving the
        // window empty.
        _loadError ??= 'Could not load PCHAT.';
      }
    });

    if (!loaded) {
      _scheduleAutoRetry();
      return;
    }

    _autoRetry?.cancel();
    _autoRetry = null;
    unawaited(_installPopupBridge());
  }

  /// Keeps reloading a page that did not load until one does.
  ///
  /// Nothing worth keeping is on screen while the status screen is up, so a
  /// reload cannot cost the user anything — and on a platform whose
  /// connectivity events never arrive this is the only way the app heals by
  /// itself.
  void _scheduleAutoRetry() {
    _autoRetry?.cancel();
    if (_loadError == null) return;

    _autoRetry = Timer(_autoRetryDelay, () async {
      if (!mounted || _loadError == null) return;
      try {
        await _controller.reload();
      } catch (_) {
        // The next attempt is scheduled below.
      }
      if (mounted && _loadError != null) _scheduleAutoRetry();
    });
  }

  /// True when the WebView holds a real document rather than the engine's own
  /// error page.
  Future<bool> _pageActuallyLoaded() async {
    final String href;
    try {
      final Object answer = await _controller
          .runJavaScriptReturningResult('window.location.href')
          // A page that never answers must not hold the loading state forever.
          .timeout(const Duration(seconds: 2));
      href = answer.toString().replaceAll('"', '').trim();
    } catch (_) {
      // No answer from the engine: assume the page is fine, so a working app is
      // never replaced by an error screen.
      return true;
    }

    return href.isNotEmpty &&
        href != 'about:blank' &&
        !href.startsWith('chrome-error:');
  }

  /// Keeps PCHAT inside the app and pushes everything else to the OS.
  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    switch (classifyUrl(request.url)) {
      case UrlDisposition.inApp:
        return NavigationDecision.navigate;
      case UrlDisposition.external:
        unawaited(_openExternally(request.url));
        return NavigationDecision.prevent;
      case UrlDisposition.block:
        return NavigationDecision.prevent;
    }
  }

  /// Answers the engine's permission prompts for the page (PCHAT calls).
  ///
  /// Only camera and microphone have a runtime permission behind them, so only
  /// those are put to the operating system first (Android; on desktop the OS
  /// owns that decision). Every other ask is granted rather than denied: the
  /// in-app WebView only ever hosts PCHAT itself (`url_policy.dart`), and an
  /// unhandled "deny" is what silently breaks the site's own features — screen
  /// sharing on Linux, for one, arrives here with no type at all.
  Future<void> _handlePermissionRequest(
    WebViewPermissionRequest request,
  ) async {
    if (!isMediaPermissionRequest(request.types)) {
      await request.grant();
      return;
    }

    final bool granted = await requestMediaPermissions(
      camera: request.types.contains(WebViewPermissionResourceType.camera),
      microphone: request.types.contains(
        WebViewPermissionResourceType.microphone,
      ),
    );
    if (granted) {
      await request.grant();
    } else {
      await request.deny();
    }
  }

  Future<void> _installPopupBridge() async {
    try {
      await _controller.runJavaScript(popupBridgeJavaScript);
    } catch (_) {
      // The bridge is a convenience; failing to install it must not break the
      // page.
    }
  }

  /// Handles `window.open(...)` and `target="_blank"` forwarded by the page.
  void _handleBridgeMessage(JavaScriptMessage message) {
    final String raw = message.message.trim();
    if (raw.isEmpty) return;

    // The site's Google sign-in popup. A WebView cannot give it a window, so
    // the app opens one of its own and relays the answer back.
    if (raw.startsWith(authPopupPrefix)) {
      unawaited(_runGoogleAuth(raw.substring(authPopupPrefix.length)));
      return;
    }

    if (raw.startsWith(AppConfig.downloadPrefix)) {
      final String url = raw.substring(AppConfig.downloadPrefix.length).trim();
      if (url.isNotEmpty) unawaited(_openExternally(url));
      return;
    }

    switch (classifyUrl(raw)) {
      case UrlDisposition.inApp:
        unawaited(_controller.loadRequest(Uri.parse(raw)));
      case UrlDisposition.external:
        unawaited(_openExternally(raw));
      case UrlDisposition.block:
        break;
    }
  }

  // ── Errors and connectivity ─────────────────────────────────────────────

  bool _isMainDocumentFailure(WebResourceError error) {
    if (error.isForMainFrame == false) return false;

    final String? url = error.url;
    // A failed favicon, stylesheet or script must never hide the app.
    if (url != null && looksLikeAsset(url)) return false;

    if (error.isForMainFrame == true) return true;
    // Some engines leave the flag unset; fall back to "it was our own page".
    return url == null || classifyUrl(url) == UrlDisposition.inApp;
  }

  void _handleWebResourceError(WebResourceError error) {
    if (!_isMainDocumentFailure(error)) return;
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _connectionFailure = _isConnectionLevelFailure(error.errorType);
      _loadError = error.description.isEmpty
          ? 'Could not load PCHAT.'
          : error.description;
    });
    _scheduleAutoRetry();
  }

  /// Whether a failure means "the server was never reached", as opposed to the
  /// server answering with something the engine rejected. Only the former is
  /// worth blaming on the user's connection.
  ///
  /// The list is written as "the server answered" on purpose: engines that
  /// classify nothing (WebKitGTK reports a DNS failure as plain `unknown`)
  /// would otherwise never show the connection screen, which is the one case
  /// users hit most.
  static bool _isConnectionLevelFailure(WebResourceErrorType? type) {
    return switch (type) {
      WebResourceErrorType.authentication ||
      WebResourceErrorType.badUrl ||
      WebResourceErrorType.failedSslHandshake ||
      WebResourceErrorType.file ||
      WebResourceErrorType.fileNotFound ||
      WebResourceErrorType.proxyAuthentication ||
      WebResourceErrorType.redirectLoop ||
      WebResourceErrorType.tooManyRequests => false,
      _ => true,
    };
  }

  void _watchConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _applyConnectivity,
    );
    unawaited(_refreshConnectivity());
  }

  static bool _reportsOffline(List<ConnectivityResult> results) {
    // An empty list means the platform has no answer, not that the device is
    // offline - treating it as offline is what made the connection screen flash
    // up on startup while the site was loading perfectly well.
    return results.isNotEmpty &&
        results.every((ConnectivityResult r) => r == ConnectivityResult.none);
  }

  Future<void> _refreshConnectivity() async {
    try {
      _applyConnectivity(
        await _connectivity.checkConnectivity().timeout(_connectivityTimeout),
      );
    } catch (_) {
      // A platform that cannot report connectivity - or never answers - is
      // assumed to be online, and the load itself decides what to show.
    }
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    final bool offline = _reportsOffline(results);
    if (!mounted || offline == _isOffline) return;

    final bool wasOffline = _isOffline;
    setState(() => _isOffline = offline);
    // Coming back online is the moment to heal a page that never loaded, or
    // one that was lost while the device was offline.
    //
    // The "never loaded" case matters as much as the failed one: a retry the
    // user asked for while the device was offline cannot have loaded anything
    // (there was no network to load it from), so the page is still missing
    // even though no error is on screen any more.
    if (!offline && (wasOffline || _loadError != null || !_hasLoadedOnce)) {
      unawaited(_retry());
    }
  }

  // ── Navigation helpers ──────────────────────────────────────────────────

  Future<void> _loadStartUrl() =>
      _controller.loadRequest(Uri.parse(AppConfig.startUrl));

  /// Installs the page smoothing script, then asks for the start page.
  ///
  /// A user script only applies to documents that begin loading after it is
  /// registered, so the very first navigation has to wait for it (a few
  /// milliseconds). Later navigations are covered by the registration itself.
  Future<void> _start() async {
    // A platform channel that never answers must not hold the first page
    // hostage; without the script the app only loses a cosmetic touch-up.
    await _installPageSmoothing().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    if (!mounted) return;
    await _loadStartUrl();
  }

  /// Stops the site's page-entrance animations from making every navigation
  /// look like a jump.
  ///
  /// Registered for `documentStart`, i.e. before the document is parsed, which
  /// is the only moment at which the page's own animations can still be
  /// settled unseen. Engines that do not offer that hook simply keep the
  /// site's animations; this is purely cosmetic, never a reason to fail a load.
  Future<void> _installPageSmoothing() async {
    try {
      const WebViewUserScript script = WebViewUserScript(
        source: pageSmoothingJavaScript,
        injectionTime: WebViewUserScriptInjectionTime.documentStart,
      );
      if (!await _controller.isUserScriptInjectionSupported(
        WebViewUserScriptInjectionTime.documentStart,
      )) {
        return;
      }
      await _controller.addUserScript(script);
    } catch (_) {
      // Older Android WebViews have no document-start injection; the app still
      // works, it just shows the site's transitions.
    }
  }

  /// Retries whatever failed, either because the user asked for it or because
  /// the network came back.
  Future<void> _retry() async {
    bool offline = false;
    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity()
          .timeout(_connectivityTimeout);
      offline = _reportsOffline(results);
    } catch (_) {
      offline = false;
    }

    if (!mounted) return;

    // Nothing can be loaded while the device is offline, so the failure stays
    // on screen: it is what the network coming back is waited for, and it is
    // what keeps the "Try again" button there to press. Clearing it here
    // would leave the app with no page, no error and nothing to wait for —
    // a loading animation that never ends.
    if (offline) {
      setState(() => _isOffline = true);
      return;
    }

    setState(() {
      _isOffline = false;
      _loadError = null;
      _connectionFailure = false;
      _isLoading = true;
    });

    // `reload()` retries whatever page failed, keeping the user's place.
    try {
      await _controller.reload();
    } catch (_) {
      await _loadStartUrl();
    }
  }

  /// Shows Google's sign-in page in a WebView of its own, then hands whatever
  /// it produced back to the page.
  ///
  /// The site's flow needs a popup whose answer reaches `window.opener`; a
  /// WebView cannot provide one, so the app provides it instead.
  Future<void> _runGoogleAuth(String url) async {
    if (!mounted || _authInProgress || url.isEmpty) return;

    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'accounts.google.com') return;

    _authInProgress = true;
    try {
      final GoogleAuthOutcome? outcome = await showGoogleAuthPopup(
        context,
        url,
      );
      if (!mounted) return;

      if (outcome == null || outcome.isEmpty) {
        await cancelGoogleAuth(_controller);
        return;
      }
      await deliverGoogleAuth(_controller, outcome);
    } finally {
      _authInProgress = false;
    }
  }

  Future<void> _openExternally(String raw) async {
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null) return;
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) _notify('Could not open that link.');
    } catch (_) {
      _notify('Could not open that link.');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Android back button / gesture: walk the page history first.
  void _handleSystemBack(bool didPop, Object? result) {
    if (didPop) return;
    unawaited(_goBackOrExit());
  }

  Future<void> _goBackOrExit() async {
    bool canGoBack = false;
    try {
      canGoBack = await _controller.canGoBack();
    } catch (_) {
      canGoBack = false;
    }
    if (canGoBack) {
      await _controller.goBack();
      return;
    }
    await SystemNavigator.pop();
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Losing the network replaces the app straight away, whether or not a page
    // has been shown before: a P2P chat cannot do anything useful without a
    // connection, and that is exactly the moment the user expects to see the
    // connection screen. A page that failed to load *while* the device is
    // online is a different problem and gets the "unreachable" notice instead.
    final bool showStatus = _isOffline || _loadError != null;

    // A device with no network and a server that was never reached look the
    // same from here, and they get the same artwork. Only a failure that came
    // back with an answer (a refused redirect, a bad certificate) gets the
    // plain notice, where blaming the connection would be wrong.
    final bool connectionLost =
        _isOffline || (_loadError != null && _connectionFailure);

    // Linux and Windows draw the WebView as a native view instead of into
    // Flutter's canvas, so it has to stay offstage until there is something
    // worth showing — otherwise our own loading animation and error screen
    // could never be seen at all.
    final bool showWebView = _hasLoadedOnce && !showStatus;
    final bool showLoading = _isLoading && !showStatus && !_hasLoadedOnce;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleSystemBack,
      child: Scaffold(
        backgroundColor: const Color(AppConfig.canvasColor),
        // The page must not run underneath the phone's status bar or its gesture
        // bar: Android 15 and newer lay every app out edge-to-edge whether it
        // wants it or not, so the app reserves the bars' space — painted in the
        // canvas colour, which is the site's own top-edge pixel — and the page
        // starts below it. On the desktop this is a no-op, because a window
        // there has no system bars of its own.
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // The desktop window is borderless, so the app draws the only
              // controls it needs, in a transparent bar of its own.
              if (usesDesktopWindowControls)
                DesktopWindowControls(
                  onRefresh: () => unawaited(_retry()),
                  onMinimize: () => unawaited(minimizeWindow()),
                  onClose: () => unawaited(closeWindow()),
                ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Offstage(
                        offstage: !showWebView,
                        child: WebViewWidget(controller: _controller),
                      ),
                    ),
                    if (showStatus)
                      Positioned.fill(
                        child: StatusOverlay(
                          offline: connectionLost,
                          details: _loadError,
                          onRetry: () => unawaited(_retry()),
                        ),
                      )
                    else if (showLoading)
                      const Positioned.fill(child: LoadingIndicator()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
