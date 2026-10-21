import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

import 'app_config.dart';
import 'platform_setup.dart';

/// Google sign-in for a WebView app.
///
/// The site signs in with Google Identity Services' *token* model
/// (`google.accounts.oauth2.initTokenClient(...)`). That flow is a popup: GIS
/// opens `accounts.google.com`, waits for the popup to post a `message` back to
/// `window.opener`, and reports `Failed to open popup window` if `window.open`
/// gives it nothing.
///
/// A WebView cannot hand out extra windows, and sending the URL to the system
/// browser loses the opener link, so the token could never come back. Instead
/// the app *is* the popup:
///
///  * [authPopupPrefix] marks the Google URL the injected bridge sends us,
///  * [GoogleAuthPopup] shows it in a second WebView on its own route,
///  * the popup's answer is relayed back onto the page's `window` as a real
///    `message` event, which is exactly what GIS is listening for.
///
/// If the relay never arrives (Google changes its answer page), the token is
/// read out of the page instead and handed to the site through its own
/// `Storage.setAuth(...)`, which is the same call its own sign-in makes.

/// Marks a Google sign-in popup in the messages the injected bridge sends.
const String authPopupPrefix = 'auth:';

/// Host whose pages are allowed inside the sign-in popup.
const String _googleAuthHost = 'accounts.google.com';

/// Origins a relayed answer may claim, most likely first.
///
/// Google Identity Services ignores any message whose origin is not the one it
/// expects, so posting the same answer once per candidate is harmless and
/// covers our bases. The first entry matters most: GIS compares against the
/// origin of its own auth URL (`https://accounts.google.com/o/oauth2/v2/auth`).
List<String> get googleAuthAnswerOrigins => <String>[
  'https://$_googleAuthHost',
  Uri.parse(AppConfig.startUrl).origin,
];

/// True when [payload] is the `authResult` message Google's popup posts.
///
/// The page may hand things to its opener for reasons of its own, and only this
/// message means the sign-in is over — closing the popup on anything else would
/// strand the user.
bool isGoogleAuthResult(String payload) {
  try {
    final Object? decoded = jsonDecode(payload);
    if (decoded is! Map) return false;
    final Object? params = decoded['params'];
    return params is Map && params['type'] == 'authResult';
  } catch (_) {
    return false;
  }
}

/// What the sign-in popup managed to get out of Google, if anything.
class GoogleAuthOutcome {
  const GoogleAuthOutcome({this.payload, this.token, this.expiresIn});

  /// The complete answer GIS expects, exactly as its own popup would post it.
  final String? payload;

  /// A bare OAuth access token, when only that could be recovered.
  final String? token;

  final String? expiresIn;

  bool get isEmpty => payload == null && token == null;
}

/// Runs the sign-in popup and returns what it collected, or `null` if the user
/// gave up.
Future<GoogleAuthOutcome?> showGoogleAuthPopup(
  BuildContext context,
  String url,
) {
  return Navigator.of(context).push<GoogleAuthOutcome>(
    MaterialPageRoute<GoogleAuthOutcome>(
      fullscreenDialog: true,
      builder: (BuildContext context) => GoogleAuthPopup(url: url),
    ),
  );
}

/// Tells the page that its sign-in popup is gone.
///
/// Google Identity Services watches `popup.closed` and reports a cancelled
/// sign-in when it flips, which is exactly what a real popup closing does — so
/// the site's pending `signIn()` settles instead of hanging forever.
Future<void> cancelGoogleAuth(WebViewController controller) async {
  await controller.runJavaScript('''
(function () {
  try {
    if (window.__pchatAuthPopup) { window.__pchatAuthPopup.closed = true; }
  } catch (error) { /* nothing else we can do */ }
})();
''');
}

/// Puts Google's answer back on the page.
///
/// The relayed answer is preferred because it is byte-for-byte what GIS would
/// have received from a real popup. The bare-token fallback signs the page in
/// through the site's own storage instead.
Future<void> deliverGoogleAuth(
  WebViewController controller,
  GoogleAuthOutcome outcome,
) async {
  if (outcome.payload != null) {
    final String data = jsonEncode(outcome.payload);
    final String origins = googleAuthAnswerOrigins.map(jsonEncode).join(',');
    await controller.runJavaScript('''
(function () {
  try {
    var data = $data;
    var origins = [$origins];
    for (var i = 0; i < origins.length; i++) {
      try {
        window.dispatchEvent(new MessageEvent('message', {
          data: data,
          origin: origins[i],
          source: window
        }));
      } catch (error) { /* try the next origin */ }
    }
  } catch (error) { /* nothing else we can do */ }
})();
''');
    return;
  }

  if (outcome.token == null) return;

  final String token = jsonEncode(outcome.token);
  final String expiresIn = jsonEncode(
    int.tryParse(outcome.expiresIn ?? '') ?? 3600,
  );
  await controller.runJavaScript('''
(function () {
  var token = $token;
  var expiresIn = $expiresIn;
  function finish(profile) {
    try {
      // Same shape, and the same merge, as the site's own sign-in callback.
      var authData = {
        accessToken: token,
        expiresAt: Date.now() + (expiresIn - 60) * 1000,
        tokenType: 'Bearer',
        isDemo: false,
        user: profile
      };
      Storage.setAuth(Object.assign({}, Storage.getAuth(), authData));
      if (profile && profile.name) {
        localStorage.setItem('shepu_display_name', profile.name);
      }
      if (profile && profile.picture &&
          localStorage.getItem('shepu_pic_custom') !== '1') {
        localStorage.setItem('shepu_profile_pic', profile.picture);
      }
      location.reload();
    } catch (error) { /* the page will simply stay signed out */ }
  }
  fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
    headers: { Authorization: 'Bearer ' + token }
  }).then(function (res) { return res.json(); }).then(function (data) {
    finish({
      sub: data.sub,
      email: data.email,
      name: data.name,
      picture: data.picture
    });
  }).catch(function () {
    finish({
      sub: 'user_' + Date.now(),
      email: 'user@google.account',
      name: 'Google User',
      picture: ''
    });
  });
})();
''');
}

/// The sign-in popup itself: Google's page in a WebView of its own.
class GoogleAuthPopup extends StatefulWidget {
  const GoogleAuthPopup({super.key, required this.url});

  final String url;

  @override
  State<GoogleAuthPopup> createState() => _GoogleAuthPopupState();
}

class _GoogleAuthPopupState extends State<GoogleAuthPopup> {
  late final WebViewController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController.fromPlatformCreationParams(
      createControllerParams(),
    );
    unawaited(_start());
  }

  Future<void> _start() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(Colors.white);
    await _controller.addJavaScriptChannel(
      'PChatAuth',
      onMessageReceived: _onRelay,
    );

    // Document-start injection is the only way to be sure the opener shim is
    // in place before Google's page runs; where it is unavailable the shim is
    // re-injected on every navigation and [_extract] covers the rest.
    try {
      if (await _controller.isUserScriptInjectionSupported(
        WebViewUserScriptInjectionTime.documentStart,
      )) {
        await _controller.addUserScript(
          const WebViewUserScript(source: _shimJavaScript),
        );
      }
    } catch (_) {
      // Not supported here; the per-navigation injection below still runs.
    }

    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          unawaited(_controller.runJavaScript(_shimJavaScript));
        },
        onPageFinished: (String url) {
          unawaited(_controller.runJavaScript(_extractJavaScript));
        },
      ),
    );

    await _controller.loadRequest(Uri.parse(widget.url));
  }

  void _onRelay(JavaScriptMessage message) {
    final String raw = message.message;
    if (raw == 'closed') return;

    if (raw.startsWith('raw:')) {
      final String payload = raw.substring(4);
      if (isGoogleAuthResult(payload)) {
        _complete(GoogleAuthOutcome(payload: payload));
      }
      return;
    }

    if (raw.startsWith('json:')) {
      Object? decoded;
      try {
        decoded = jsonDecode(raw.substring(5));
      } catch (_) {
        return;
      }
      if (decoded is! Map) return;

      final Object? payload = decoded['payload'];
      if (payload is String && isGoogleAuthResult(payload)) {
        _complete(GoogleAuthOutcome(payload: payload));
        return;
      }
      final Object? token = decoded['token'];
      if (token is String && token.isNotEmpty) {
        _complete(
          GoogleAuthOutcome(
            token: token,
            expiresIn: decoded['expires']?.toString(),
          ),
        );
      }
    }
  }

  void _complete(GoogleAuthOutcome outcome) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: <Widget>[
                  Text(
                    'Sign in with Google',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}

/// Gives Google's answer page a `window.opener` that leads back to the app.
const String _shimJavaScript = r'''
(function () {
  try {
    if (window.__pchatAuthShim) { return; }
    window.__pchatAuthShim = true;

    function relay(text) {
      try { window.PChatAuth.postMessage(String(text)); } catch (error) {}
    }

    function relayData(data) {
      relay('raw:' + (typeof data === 'string' ? data : JSON.stringify(data)));
    }

    try {
      var handle = {
        postMessage: function (data) { relayData(data); },
        closed: false,
        focus: function () {},
        blur: function () {},
        close: function () {}
      };
      Object.defineProperty(window, 'opener', {
        configurable: true,
        get: function () { return handle; }
      });
    } catch (error) {}

    try {
      window.close = function () { relay('closed'); };
    } catch (error) {}
  } catch (error) {}
})();
''';

/// Reads the answer straight out of the page, for when the shim arrived late.
const String _extractJavaScript = r'''
(function () {
  function relay(text) {
    try { window.PChatAuth.postMessage(String(text)); } catch (error) {}
  }

  // The answer is a JSON object, and braces inside it are nested, so rather
  // than guess where it ends, take the shortest chunk that parses *and* really
  // is a sign-in answer.
  function grabAnswer(text) {
    var start = text.indexOf('{"params"');
    if (start < 0) { return null; }
    var limit = Math.min(text.length, start + 8000);
    for (var end = start + 1; end < limit; end++) {
      if (text.charAt(end) !== '}') { continue; }
      var chunk = text.substring(start, end + 1);
      try {
        var parsed = JSON.parse(chunk);
        if (parsed && parsed.params && parsed.params.type === 'authResult') {
          return chunk;
        }
      } catch (error) { /* not balanced yet */ }
    }
    return null;
  }

  try {
    var out = {
      url: String(location.href),
      payload: null,
      token: null,
      expires: null,
      note: ''
    };
    var html = '';
    try {
      html = document.documentElement ? document.documentElement.outerHTML : '';
    } catch (error) {}

    out.payload = grabAnswer(html);
    if (!out.payload) { out.payload = grabAnswer(html.replace(/&quot;/g, '"')); }

    if (!out.payload) {
      var token = location.href.match(/[#&?]access_token=([^&]+)/);
      if (!token) {
        token = html.match(/access_token["'\\:= ]+([A-Za-z0-9._-]{20,})/);
      }
      if (token) { out.token = decodeURIComponent(token[1]); }
      var expires = html.match(/expires_in["'\\:= ]+([0-9]+)/);
      if (expires) { out.expires = expires[1]; }
    }
    relay('json:' + JSON.stringify(out));
  } catch (error) {
    relay('json:' + JSON.stringify({ note: String(error) }));
  }
})();
''';
