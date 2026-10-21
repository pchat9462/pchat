import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app_config.dart';
import 'src/pchat_screen.dart';

void main() {
  runApp(const PChatApp());
}

/// The app is a single screen wrapping the PCHAT website, so this widget only
/// sets up the theme: dark, seeded from the PCHAT accent blue.
class PChatApp extends StatelessWidget {
  const PChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Android 15 and newer force every app edge-to-edge: the system bars become
    // transparent and the app is what shows behind them. Left alone, the page's
    // own header would sit under the clock and battery icons, which looks like
    // a bug. So the app paints the bar itself, in the same colour the site uses
    // along its top edge, with light icons on top of it, and the page itself
    // starts below the bar (see `SafeArea` in PChatScreen).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(AppConfig.canvasColor),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(AppConfig.canvasColor),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        title: AppConfig.appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(AppConfig.canvasColor),
        ),
        home: const PChatScreen(),
      ),
    );
  }
}
