import 'package:flutter/material.dart';

import 'app_config.dart';
import 'platform_setup.dart';

/// The two pieces of chrome the app owns: the loading animation and the
/// offline/error screen. Everything else is the website itself.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.size = 120});

  /// Edge length of the square the animation is drawn into.
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          // `Image` animates any multi-frame image, APNG included.
          child: Image.asset(
            AppConfig.loadingAnimation,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// Full-screen replacement shown when nothing can be displayed.
///
/// Two different problems get two different screens, because telling a user
/// with a perfectly good connection to "check your internet" is its own kind
/// of bug:
///
/// * no network on the device → the artwork, which says "Connection Lost" in
///   so many words;
/// * the site could not be reached while the device is online → a plain
///   notice with the engine's own message.
class StatusOverlay extends StatelessWidget {
  const StatusOverlay({
    super.key,
    required this.offline,
    required this.onRetry,
    this.details,
  });

  /// True when the device itself reports no connectivity at all.
  final bool offline;

  /// Engine message for a failed load, if any.
  final String? details;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _backdrop),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (offline)
            // Full bleed: the drawing is the screen, and `cover` keeps it
            // filling every window shape without leaving bars at the sides.
            Image.asset(
              offlineImage,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              // The wording lives in the drawing, so it is decorative; the
              // button on top of it is what matters.
              excludeFromSemantics: true,
            )
          else
            _UnreachableNotice(details: details),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
                child: TryAgainButton(onPressed: onRetry),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "The site did not answer", shown while the device itself has a network.
class _UnreachableNotice extends StatelessWidget {
  const _UnreachableNotice({this.details});

  final String? details;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String detail = details?.trim() ?? '';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: Color(0xFF0065F4),
              ),
              const SizedBox(height: 20),
              Text(
                'PCHAT is unreachable',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(
                  color: const Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                detail.isEmpty
                    ? 'The site did not answer. Your own connection looks fine.'
                    : detail,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill button painted in the artwork's own blue → cyan gradient.
class TryAgainButton extends StatelessWidget {
  const TryAgainButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const double _radius = 999;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Try again',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF0065F4), Color(0xFF01E8FC)],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF0065F4).withValues(alpha: 0.45),
              blurRadius: 26,
              spreadRadius: 1,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_radius),
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 34, vertical: 15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Try again',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fills the letterbox around the artwork with its own background, so an
/// unusually shaped window blends instead of showing bars.
const LinearGradient _backdrop = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[Color(0xFF010E36), Color(0xFF010823)],
);
