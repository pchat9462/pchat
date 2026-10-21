import 'package:flutter_test/flutter_test.dart';
import 'package:pchat_app/src/page_smoothing.dart';

/// Every page of the site animates its content in (a rise of 8–20px, or a
/// scale from 90%). Navigating between the site's pages is a document load, so
/// that played on every page change and made the app look like it jumped. The
/// injected script has to be registered before the document is parsed and must
/// settle exactly those entrance animations, never the looping ones.
void main() {
  test('smoothing script is idempotent', () {
    // Some engines inject a user script again for every frame; a second pass
    // would stack listeners on the same document.
    expect(pageSmoothingJavaScript, contains('__pchatPageSmoothing'));
    expect(
      pageSmoothingJavaScript,
      contains('if (window.__pchatPageSmoothing)'),
    );
  });

  test('settles the page-entrance animations', () {
    for (final String name in <String>['fadeIn', 'fadeInUp', 'scaleIn']) {
      expect(
        pageSmoothingJavaScript,
        contains('$name: true'),
        reason: '$name is what makes a page rise or zoom as it appears',
      );
    }
    expect(pageSmoothingJavaScript, contains('animation.finish()'));
  });

  test('never touches looping animations', () {
    // Spinners and pulses are infinite; finishing one throws, and freezing
    // them would make the site look broken.
    expect(pageSmoothingJavaScript, contains('timing.iterations === Infinity'));
    expect(pageSmoothingJavaScript, contains('continue;'));
  });

  test('keeps message animations that belong to an arriving message', () {
    // Only the burst that draws the room's history is settled; a message that
    // arrives while the chat is open keeps its slide-in.
    expect(pageSmoothingJavaScript, contains('historyWindow'));
    expect(pageSmoothingJavaScript, contains('< historyWindow'));
  });

  test('makes full-screen overlays appear in one step', () {
    // The room sheets fade their backdrop in first and slide the card up
    // afterwards; tapping "+" therefore looked like "something else flashed,
    // then the card came". The transitions have to be gone, and the rule has
    // to be injected as a style element with `!important` so the site's own
    // stylesheet cannot bring the movement back.
    expect(pageSmoothingJavaScript, contains('.bottom-sheet-overlay'));
    expect(pageSmoothingJavaScript, contains('transition: none !important'));
    expect(pageSmoothingJavaScript, contains('pchat-app-rules'));
    expect(pageSmoothingJavaScript, contains('style.textContent'));
  });

  test('lets the composer shrink so the send button stays on screen', () {
    // The input bubble is `flex: 1` with the default `min-width: auto`, so the
    // text area's intrinsic width kept the row wider than a phone screen and
    // pushed the send button past the right edge.
    expect(pageSmoothingJavaScript, contains('.chat-input-wrap'));
    expect(pageSmoothingJavaScript, contains('.chat-input {'));
    expect(pageSmoothingJavaScript, contains('min-width: 0 !important'));
  });

  test('installs the style rules even before the head exists', () {
    // At document-start time the document element may not be there yet, so
    // the rule has to be retried once the document is parsed.
    expect(pageSmoothingJavaScript, contains('document.head ||'));
    expect(pageSmoothingJavaScript, contains('DOMContentLoaded'));
  });
}
