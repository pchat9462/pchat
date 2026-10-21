/// JavaScript injected before each document is parsed.
///
/// Every page of the site plays an entrance animation on the elements that
/// make up the page: the heading rises from 20px below, a card scales up from
/// 90%, the chat history slides up 8px. Navigation between PCHAT's pages is a
/// normal document load, so the whole page appears to jump (or "shake") each
/// time the user goes somewhere else.
///
/// The app cannot edit the site, so this script settles those animations the
/// moment they start: the element is put straight into its final state instead
/// of travelling there. Animations that belong to interaction rather than page
/// entry — a modal opening, a toast, a reaction, a message that arrives while
/// the chat is open — keep playing; only the ones that start with the document
/// are settled (plus the first burst of `msgIn` when a room's history is
/// drawn, which happens a moment after load).
///
/// The same script also removes the movement of the site's full-screen
/// overlays (the room sheets). They fade a dark backdrop in and only then
/// slide their card up, so opening one — the "+" button, for instance — first
/// shows a screen that looks like a different page and only afterwards the
/// card. Without the transitions both arrive in the same frame.
///
/// Finally it lets the message composer shrink. Its input bubble only has
/// `flex: 1`, and a flex item may not sink below its own content, so the
/// text area's ~200px intrinsic width made the row wider than a phone screen:
/// the send button was pushed past the right edge and could not be pressed.
///
/// The script must be registered for `documentStart` so it runs before the
/// page's own stylesheets and scripts; it is idempotent, because some engines
/// inject a user script once per frame or per navigation.
const String pageSmoothingJavaScript = r'''
(function () {
  if (window.__pchatPageSmoothing) { return; }
  window.__pchatPageSmoothing = true;

  // Names used by the entrance animations of cards, headings and pages.
  var entrance = { fadeIn: true, fadeInUp: true, scaleIn: true };

  // Played for every message row. The first rows are drawn right after the
  // room's history arrives, which would ripple the whole feed; a message that
  // arrives while the user is reading keeps its little slide-in.
  var history = { msgIn: true };
  var historyWindow = 4000;
  var started = Date.now();

  function settle(target, name) {
    if (!target || !target.getAnimations) { return; }
    var animations = target.getAnimations();
    for (var i = 0; i < animations.length; i++) {
      var animation = animations[i];
      if (animation.animationName !== name) { continue; }
      var timing = animation.effect && animation.effect.getTiming
        ? animation.effect.getTiming()
        : null;
      // Looping animations (spinners, pulses) are not entrance effects and
      // cannot be finished at all.
      if (timing && timing.iterations === Infinity) { continue; }
      try {
        animation.finish();
      } catch (error) {
        // A browser that refuses is no reason to break the page.
      }
    }
  }

  // Overlays have to arrive in one step.
  //
  // The create sheet is a full-screen backdrop that fades in while the card
  // slides up behind it, so a tap first shows a dark blurred screen and only
  // then the card — on a phone that reads as "something else flashed, then the
  // card came". With the transitions gone, the backdrop and the card are both
  // in place in the same frame, and nothing travels across the screen.
  //
  // The composer needs the second rule. Its input bubble is only `flex: 1`,
  // and a flex item may not shrink below its own content: the text area's
  // intrinsic width is about 200px, so on a phone the row is wider than the
  // screen and the last button — send — is pushed past the right edge and
  // simply does not exist on screen. `min-width: 0` lets the bubble and the
  // text area take whatever space is left, which is what every other browser
  // does with the same CSS.
  var styleRules = [
    '.bottom-sheet-overlay,',
    '.bottom-sheet-overlay .bottom-sheet-card,',
    '.bottom-sheet-overlay.active .bottom-sheet-card {',
    '  transition: none !important;',
    '}',
    '.chat-input-wrap,',
    '.chat-input {',
    '  min-width: 0 !important;',
    '}'
  ].join('\n');

  function installStyleRules() {
    if (document.getElementById('pchat-app-rules')) { return true; }
    var parent = document.head || document.documentElement;
    if (!parent) { return false; }
    var style = document.createElement('style');
    style.id = 'pchat-app-rules';
    style.textContent = styleRules;
    parent.appendChild(style);
    return true;
  }

  if (!installStyleRules()) {
    // The document element may not exist yet at document-start time.
    document.addEventListener('DOMContentLoaded', installStyleRules);
  }

  document.addEventListener('animationstart', function (event) {
    var name = event.animationName;
    if (entrance[name]) {
      settle(event.target, name);
    } else if (history[name] && Date.now() - started < historyWindow) {
      settle(event.target, name);
    }
  }, true);
})();
''';
