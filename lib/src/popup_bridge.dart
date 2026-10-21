/// JavaScript injected into every loaded page.
///
/// The PCHAT page opens a few things with `window.open(...)` and
/// `target="_blank"` links. Embedded WebViews disagree on how (and whether)
/// those should become new windows, so instead of relying on native popup
/// support we forward them to Dart and let the app decide:
///
/// * the Google sign-in popup is answered by the app itself (it needs a real
///   window, which a WebView cannot give it — see `google_auth.dart`),
/// * links that belong to the site keep working, and
/// * everything else is handed to the real browser.
///
/// The script is idempotent — injecting it twice does nothing.
const String popupBridgeJavaScript = r'''
(function () {
  if (window.__pchatBridgeInstalled) { return; }
  var channel = window.PChatBridge;
  if (!channel) { return; }
  window.__pchatBridgeInstalled = true;

  function forward(message) {
    try { channel.postMessage(String(message)); } catch (error) { /* ignore */ }
  }

  // Google Identity Services gives up with "Failed to open popup window" the
  // moment `window.open` hands it nothing, so the sign-in popup gets a
  // stand-in handle. What really happens travels over the bridge instead.
  function authPopupHandle() {
    return {
      closed: false,
      focus: function () {},
      blur: function () {},
      close: function () {}
    };
  }

  var originalOpen = window.open;
  window.open = function (url) {
    if (url) {
      var target = String(url);
      if (target.indexOf('https://accounts.google.com/') === 0) {
        forward('auth:' + target);
        window.__pchatAuthPopup = authPopupHandle();
        return window.__pchatAuthPopup;
      }
      forward(target);
      return null;
    }
    return originalOpen ? originalOpen.apply(window, arguments) : null;
  };

  document.addEventListener('click', function (event) {
    var node = event.target;
    var anchor = node && node.closest ? node.closest('a[href]') : null;
    if (!anchor) { return; }
    var href = anchor.href;
    if (!href) { return; }
    var target = (anchor.getAttribute('target') || '').toLowerCase();
    if (anchor.hasAttribute('download')) {
      event.preventDefault();
      forward('download:' + href);
    } else if (target === '_blank') {
      event.preventDefault();
      forward(href);
    }
  }, true);

})();
''';
