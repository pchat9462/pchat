import 'package:flutter_test/flutter_test.dart';
import 'package:pchat_app/src/app_config.dart';
import 'package:pchat_app/src/url_policy.dart';

void main() {
  group('classifyUrl keeps PCHAT inside the app', () {
    test('accepts the configured start URL', () {
      expect(classifyUrl(AppConfig.startUrl), UrlDisposition.inApp);
    });

    test('accepts every page and sub-path of the site', () {
      const List<String> urls = <String>[
        'https://pchatshepu.vercel.app/pchat',
        'https://pchatshepu.vercel.app/pchat/',
        'https://pchatshepu.vercel.app/pchat/pchat/index.html',
        'https://pchatshepu.vercel.app/pchat/pchat/login.html?redirect=x',
        'https://pchatshepu.vercel.app/pchat/pchat/#/rooms/42',
      ];
      for (final String url in urls) {
        expect(classifyUrl(url), UrlDisposition.inApp, reason: url);
      }
    });

    test('accepts same-page and inline URLs', () {
      expect(classifyUrl('about:blank'), UrlDisposition.inApp);
      expect(classifyUrl('/pchat/pchat/index.html'), UrlDisposition.inApp);
      expect(
        classifyUrl('blob:https://pchatshepu.vercel.app/2f8c-4a1'),
        UrlDisposition.inApp,
      );
    });
  });

  group('classifyUrl defers third parties to the operating system', () {
    test('sends external hosts to the browser', () {
      const List<String> urls = <String>[
        'https://docs.google.com/spreadsheets/d/abc/edit',
        'https://accounts.google.com/o/oauth2/v2/auth',
        'https://drive.google.com/file/d/abc/view',
        'https://example.com/',
        'http://pchatshepu.vercel.app.evil.com/pchat/',
      ];
      for (final String url in urls) {
        expect(classifyUrl(url), UrlDisposition.external, reason: url);
      }
    });

    test('sends non-web schemes to the operating system', () {
      expect(
        classifyUrl('mailto:someone@example.com'),
        UrlDisposition.external,
      );
      expect(classifyUrl('tel:+8801700000000'), UrlDisposition.external);
      expect(classifyUrl('sms:+8801700000000'), UrlDisposition.external);
    });
  });

  group('classifyUrl blocks junk', () {
    test('rejects scripts, local files and empty input', () {
      expect(classifyUrl('javascript:alert(1)'), UrlDisposition.block);
      expect(classifyUrl('file:///etc/passwd'), UrlDisposition.block);
      expect(classifyUrl(''), UrlDisposition.block);
      expect(classifyUrl('   '), UrlDisposition.block);
      expect(classifyUrl(null), UrlDisposition.block);
    });
  });

  group('looksLikeAsset', () {
    test('recognises static files', () {
      const List<String> assets = <String>[
        'https://pchatshepu.vercel.app/pchat/pchat/assets/icons/icon.png',
        'https://pchatshepu.vercel.app/pchat/pchat/css/base.css?v=20261016a',
        'https://pchatshepu.vercel.app/pchat/pchat/js/auth.js',
        'https://pchatshepu.vercel.app/favicon.ico',
      ];
      for (final String url in assets) {
        expect(looksLikeAsset(url), isTrue, reason: url);
      }
    });

    test('treats pages and directories as documents', () {
      const List<String> documents = <String>[
        'https://pchatshepu.vercel.app/pchat/',
        'https://pchatshepu.vercel.app/pchat/pchat/',
        'https://pchatshepu.vercel.app/pchat/pchat/login.html',
        'https://pchatshepu.vercel.app/pchat/pchat/index.HTM',
      ];
      for (final String url in documents) {
        expect(looksLikeAsset(url), isFalse, reason: url);
      }
    });
  });
}
