import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pchat_app/src/app_config.dart';
import 'package:pchat_app/src/google_auth.dart';
import 'package:pchat_app/src/platform_setup.dart';
import 'package:pchat_app/src/popup_bridge.dart';
import 'package:pchat_app/src/status_overlay.dart';
import 'package:pchat_app/src/window_controls.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    home: Scaffold(body: child),
  );
}

void main() {
  group('StatusOverlay', () {
    testWidgets('shows the connection-lost artwork with a Try again button', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await tester.pumpWidget(
        _wrap(StatusOverlay(offline: true, onRetry: () => retries++)),
      );

      expect(_artwork(tester), offlineImage);
      // The artwork is the screen rather than a picture boxed into a column
      // with the button below it: `cover` fills every window shape and the
      // button floats over the drawing.
      final Image art = tester.widget<Image>(find.byType(Image));
      expect(art.fit, BoxFit.cover);
      expect(
        tester.getSize(find.byType(Image)),
        tester.getSize(find.byType(StatusOverlay)),
      );
      // The drawing carries the wording itself, so repeating it would just be
      // noise on top of the art.
      expect(find.text('Connection Lost'), findsNothing);
      expect(find.text('No internet connection'), findsNothing);
      // A device that is offline must not be told the *site* is at fault.
      expect(find.text('PCHAT is unreachable'), findsNothing);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('gives phones the tall art and desktops the wide one', (
      WidgetTester tester,
    ) async {
      // The binding asserts this is cleared before the body returns, so a
      // tear-down would be too late.
      try {
        for (final (TargetPlatform platform, String expected)
            in <(TargetPlatform, String)>[
              (TargetPlatform.android, AppConfig.offlineImagePhone),
              (TargetPlatform.linux, AppConfig.offlineImageDesktop),
              (TargetPlatform.windows, AppConfig.offlineImageDesktop),
            ]) {
          debugDefaultTargetPlatformOverride = platform;
          await tester.pumpWidget(
            // A fresh key forces a real rebuild: an identical `const` widget
            // would be skipped and keep the previous platform's artwork.
            _wrap(
              StatusOverlay(
                key: ValueKey<TargetPlatform>(platform),
                offline: true,
                onRetry: _noop,
              ),
            ),
          );
          expect(_artwork(tester), expected, reason: 'on $platform');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
      'blames the site, not the connection, when only the page failed',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const StatusOverlay(
              offline: false,
              details: 'ERR_NAME_NOT_RESOLVED',
              onRetry: _noop,
            ),
          ),
        );

        expect(find.text('PCHAT is unreachable'), findsOneWidget);
        expect(find.text('ERR_NAME_NOT_RESOLVED'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        // No artwork here: "connection lost" would be a false accusation while
        // the device is online.
        expect(find.byType(Image), findsNothing);
      },
    );

    testWidgets('still explains itself without an engine message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const StatusOverlay(offline: false, onRetry: _noop)),
      );

      expect(find.text('PCHAT is unreachable'), findsOneWidget);
      expect(find.textContaining('did not answer'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('LoadingIndicator', () {
    testWidgets('draws the bundled animation and never eats taps', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator()));

      expect(find.byType(LoadingIndicator), findsOneWidget);

      final Image image = tester.widget<Image>(find.byType(Image));
      expect(
        image.image,
        isA<AssetImage>().having(
          (AssetImage asset) => asset.assetName,
          'assetName',
          AppConfig.loadingAnimation,
        ),
      );

      // The page stays clickable while the animation is on screen.
      expect(
        find.ancestor(
          of: find.byType(Image),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
    });
  });

  group('DesktopWindowControls', () {
    testWidgets('reports refresh, minimize and close taps', (
      WidgetTester tester,
    ) async {
      int refreshed = 0;
      int minimized = 0;
      int closed = 0;

      await tester.pumpWidget(
        _wrap(
          DesktopWindowControls(
            onRefresh: () => refreshed++,
            onMinimize: () => minimized++,
            onClose: () => closed++,
          ),
        ),
      );

      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(refreshed, 1);
      expect(minimized, 1);
      expect(closed, 1);
    });
  });

  group('Google sign-in', () {
    test('the page hands Google URLs to the app instead of the browser', () {
      // Google Identity Services gives up the instant `window.open` returns
      // nothing, so its popup is answered by the app rather than the OS.
      expect(popupBridgeJavaScript, contains('https://accounts.google.com/'));
      expect(popupBridgeJavaScript, contains("forward('auth:' + target)"));
      expect(
        popupBridgeJavaScript,
        contains('closed: false'),
        reason:
            'a null popup makes Google fail with "Failed to open popup '
            'window" before it ever reaches its sign-in page',
      );
      expect(
        popupBridgeJavaScript,
        contains('window.__pchatAuthPopup'),
        reason: 'cancelling has to reach the handle to close it',
      );
      expect(authPopupPrefix, 'auth:');
    });

    test('an answer claims Google\'s origin before our own', () {
      // GIS compares the message origin with the origin of its auth URL and
      // drops anything else, so this order is what makes the answer land.
      expect(googleAuthAnswerOrigins.first, 'https://accounts.google.com');
      expect(
        googleAuthAnswerOrigins,
        contains(Uri.parse(AppConfig.startUrl).origin),
      );
    });

    test('an outcome counts as empty only when it carries nothing', () {
      expect(const GoogleAuthOutcome().isEmpty, isTrue);
      expect(const GoogleAuthOutcome(payload: '{}').isEmpty, isFalse);
      expect(const GoogleAuthOutcome(token: 'ya29.abc').isEmpty, isFalse);
    });

    test('only a real authResult ends the sign-in', () {
      expect(
        isGoogleAuthResult(
          '{"params":{"id":"auth1","clientId":"x","type":"authResult",'
          '"authResult":{"access_token":"ya29.abc"}}}',
        ),
        isTrue,
      );
      // Anything else the page hands its opener must be left alone.
      expect(isGoogleAuthResult('{"params":{"type":"other"}}'), isFalse);
      expect(isGoogleAuthResult('{"unrelated":true}'), isFalse);
      expect(isGoogleAuthResult('not json'), isFalse);
    });
  });
}

void _noop() {}

/// Asset name of the artwork the overlay is currently drawing.
String _artwork(WidgetTester tester) {
  final Image image = tester.widget<Image>(find.byType(Image));
  return (image.image as AssetImage).assetName;
}
