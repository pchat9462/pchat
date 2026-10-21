import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pchat_app/src/app_config.dart';
import 'package:pchat_app/src/pchat_screen.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

// ── A connectivity the test drives by hand ──────────────────────────────────

class _FakeConnectivity extends ConnectivityPlatform {
  _FakeConnectivity() : super();

  final StreamController<List<ConnectivityResult>> _events =
      StreamController<List<ConnectivityResult>>.broadcast();

  List<ConnectivityResult> current = <ConnectivityResult>[
    ConnectivityResult.wifi,
  ];

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _events.stream;

  void emit(List<ConnectivityResult> result) {
    current = result;
    _events.add(result);
  }
}

// ── A WebView that answers whatever the test needs ──────────────────────────

class _FakeWebViewPlatform extends WebViewPlatform {
  _FakeWebViewController? controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final _FakeWebViewController controller = _FakeWebViewController(params);
    this.controller = controller;
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  _FakeNavigationDelegate? delegate;

  /// How often the app asked for a page.
  int loadCount = 0;
  int reloadCount = 0;

  /// What `window.location.href` answers.
  String href = AppConfig.startUrl;

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    delegate = handler as _FakeNavigationDelegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadCount++;
  }

  @override
  Future<void> reload() async {
    reloadCount++;
  }

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async => href;

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> goBack() async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}

  @override
  Future<String> addUserScript(WebViewUserScript userScript) async => '';

  @override
  Future<bool> isUserScriptInjectionSupported(
    WebViewUserScriptInjectionTime injectionTime,
  ) async => false;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest request) onPermissionRequest,
  ) async {}
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;
  NavigationRequestCallback? onNavigationRequest;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    this.onPageStarted = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {
    this.onWebResourceError = onWebResourceError;
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

// ── The test ────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWebViewPlatform platform;
  late _FakeConnectivity connectivity;

  setUp(() {
    platform = _FakeWebViewPlatform();
    WebViewPlatform.instance = platform;

    connectivity = _FakeConnectivity();
    ConnectivityPlatform.instance = connectivity;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'the app asks for the page again when the network comes back',
    (WidgetTester tester) async {
      // Android has no refresh button, so the app itself has to heal.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(const MaterialApp(home: PChatScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final _FakeWebViewController controller = platform.controller!;
        expect(controller.loadCount, 1, reason: 'the start page is asked for');

        // The page fails: the app shows its error screen.
        controller.delegate!.onWebResourceError!(
          const WebResourceError(
            errorCode: -2,
            description: 'net::ERR_NAME_NOT_RESOLVED',
            errorType: WebResourceErrorType.unknown,
            isForMainFrame: true,
            url: AppConfig.startUrl,
          ),
        );
        await tester.pump();
        expect(find.text('Try again'), findsOneWidget);

        // The device is offline.
        connectivity.emit(<ConnectivityResult>[ConnectivityResult.none]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(Image), findsOneWidget, reason: 'the offline artwork');

        // The user taps "Try again" while the device is still offline. There
        // is nothing to load from, so the app has to keep waiting for the
        // network rather than give up on the page.
        await tester.tap(find.text('Try again'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text('Try again'),
          findsOneWidget,
          reason: 'the button has to stay, it is the only way out',
        );

        final int loadsBefore = controller.loadCount;
        final int reloadsBefore = controller.reloadCount;

        // Now the network comes back.
        connectivity.emit(<ConnectivityResult>[ConnectivityResult.wifi]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The app must ask for the page again: it is the only thing that can
        // bring the site back.
        expect(
          controller.loadCount + controller.reloadCount,
          greaterThan(loadsBefore + reloadsBefore),
          reason:
              'the app never asked for the page again after the network came '
              'back, so the site can never come back either',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
