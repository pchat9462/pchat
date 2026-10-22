import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pchat_app/src/platform_setup.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_all/webview_all.dart';

/// The channel `permission_handler` asks Android over.
const MethodChannel _permissionsChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

/// Camera/microphone are the only asks with an operating system permission
/// behind them, so they are the only ones that must reach the OS. Getting this
/// wrong goes unnoticed on a desktop but makes calls fail on Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> calls = <MethodCall>[];
  PermissionStatus answer = PermissionStatus.granted;

  setUp(() {
    calls.clear();
    answer = PermissionStatus.granted;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, (MethodCall call) async {
          calls.add(call);
          switch (call.method) {
            case 'requestPermissions':
              final List<dynamic> asked = call.arguments as List<dynamic>;
              return <int, int>{
                for (final dynamic value in asked) (value as int): answer.index,
              };
            case 'openAppSettings':
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('isMediaPermissionRequest', () {
    test('recognises camera and microphone asks', () {
      expect(
        isMediaPermissionRequest(<WebViewPermissionResourceType>{
          WebViewPermissionResourceType.camera,
        }),
        isTrue,
      );
      expect(
        isMediaPermissionRequest(<WebViewPermissionResourceType>{
          WebViewPermissionResourceType.microphone,
        }),
        isTrue,
      );
    });

    test('an empty ask is one of the engines other permissions', () {
      // Screen sharing on Linux, the device list, clipboard reads and desktop
      // notifications all arrive with no type at all.
      expect(
        isMediaPermissionRequest(const <WebViewPermissionResourceType>{}),
        isFalse,
      );
    });
  });

  group('requestMediaPermissions', () {
    test('desktop lets the operating system own the decision', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        await requestMediaPermissions(camera: true, microphone: true),
        isTrue,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        await requestMediaPermissions(camera: true, microphone: true),
        isTrue,
      );
      expect(calls, isEmpty);
    });

    test('Android asks for exactly the permissions the call needs', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        await requestMediaPermissions(camera: false, microphone: true),
        isTrue,
      );

      expect(calls.single.method, 'requestPermissions');
      expect(calls.single.arguments, <int>[Permission.microphone.value]);

      calls.clear();
      expect(
        await requestMediaPermissions(camera: true, microphone: true),
        isTrue,
      );
      expect(calls.single.arguments, <int>[
        Permission.camera.value,
        Permission.microphone.value,
      ]);
    });

    test(
      'a denied prompt is a denial, and is not reopened as settings',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        answer = PermissionStatus.denied;

        expect(
          await requestMediaPermissions(camera: true, microphone: false),
          isFalse,
        );
        expect(
          calls.map((MethodCall call) => call.method),
          isNot(contains('openAppSettings')),
        );
      },
    );

    test(
      'a refusal that can no longer be asked opens the settings screen',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        answer = PermissionStatus.permanentlyDenied;

        expect(
          await requestMediaPermissions(camera: true, microphone: false),
          isFalse,
        );
        expect(
          calls.map((MethodCall call) => call.method),
          contains('openAppSettings'),
        );
      },
    );

    test('asking for nothing is not a failure', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        await requestMediaPermissions(camera: false, microphone: false),
        isTrue,
      );
      expect(calls, isEmpty);
    });
  });

  group('webViewFilePath', () {
    test('a picked filesystem path becomes a file URI', () {
      // What the picker returns on Android is a plain path, and a scheme-less
      // URI makes the WebView drop the upload without a word.
      expect(
        webViewFilePath(
          '/data/user/0/com.shepu.pchat/cache/x/photo.jpg',
        ),
        'file:///data/user/0/com.shepu.pchat/cache/x/photo.jpg',
      );
    });

    test('an already-URI path is left alone', () {
      expect(
        webViewFilePath('content://media/external/images/media/42'),
        'content://media/external/images/media/42',
      );
    });
  });
}
