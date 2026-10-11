// FORK: single home of the "Plezy Streamer" customisations.
//
// Upstream files only carry one-line hooks that point here, each marked with a
// `// FORK:` comment, so `git grep -n "FORK:"` lists every touch point after a
// rebase onto a new Plezy release. See FORK.md at the repository root.

import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/platform_detector.dart';

/// Result of [StreamerFork.tabChipStyle].
typedef StreamerTabChipStyle = ({Color background, Color foreground, bool underline});

abstract final class StreamerFork {
  /// GitHub repository whose releases carry the fork's APKs.
  static const String githubRepo = String.fromEnvironment('STREAMER_REPO', defaultValue: 'Liamd1996/plezy');

  /// Number of the GitHub build that produced this APK (0 for a local build).
  static const int buildNumber = int.fromEnvironment('STREAMER_BUILD');

  /// Everything below applies to Android TV / Google TV only, so the same APK
  /// source stays a stock Plezy on phones, tablets and desktop.
  static bool get isAndroidTv => Platform.isAndroid && PlatformDetector.isTV();

  // --------------------------------------------------------------------------
  // Feature switches
  // --------------------------------------------------------------------------

  /// Downloads tab, buttons, menu entries and settings section.
  static bool hideDownloads() => PlatformDetector.isAppleTV() || isAndroidTv;

  /// Watch Together and Companion Remote buttons of the home top bar.
  static bool get hideSocialButtons => isAndroidTv;

  /// Plex-style side rail: Search, Home, one row per library (icons while
  /// collapsed), Settings at the bottom; no "Libraries" header or server groups.
  static bool get plexSidebar => isAndroidTv;

  /// `defaultValueProvider` for TV appearance settings the fork turns on out
  /// of the box (image-only cards, artwork in the corner). The user can still
  /// change them in Settings > Appearance.
  static bool tvDefaultOn() => isAndroidTv;

  // --------------------------------------------------------------------------
  // Interface size
  // --------------------------------------------------------------------------

  /// Whole-interface scale on Android TV. Below 1 everything (text, cards,
  /// spacing) is drawn smaller and the screen holds more.
  static const double tvUiScale = 0.75;

  /// Wraps the app in a larger logical viewport that is painted scaled down
  /// to the physical screen. Returns [child] untouched off Android TV.
  static Widget scaleInterface(Widget child) {
    if (!isAndroidTv) return child;
    const scale = tvUiScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) return child;
        final logicalSize = Size(constraints.maxWidth / scale, constraints.maxHeight / scale);
        final outer = MediaQuery.of(context);
        const inverse = 1 / scale;
        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: logicalSize.width,
          maxWidth: logicalSize.width,
          minHeight: logicalSize.height,
          maxHeight: logicalSize.height,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            transformHitTests: true,
            child: MediaQuery(
              data: outer.copyWith(
                size: logicalSize,
                devicePixelRatio: outer.devicePixelRatio * scale,
                padding: outer.padding * inverse,
                viewPadding: outer.viewPadding * inverse,
                viewInsets: outer.viewInsets * inverse,
                systemGestureInsets: outer.systemGestureInsets * inverse,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Extra shrink of the title artwork (clear logo) in the TV hero and on the
  /// TV detail page, which upstream draws very large.
  static double get tvLogoFactor => isAndroidTv ? 0.6 : 1.0;

  // --------------------------------------------------------------------------
  // Colours
  // --------------------------------------------------------------------------

  /// Plex's orange, used for progress bars and the selected tab or rail item.
  static const Color accent = Color(0xFFE5A00D);

  /// [accent] on Android TV, [fallback] elsewhere.
  static Color accentOr(Color fallback) => isAndroidTv ? accent : fallback;

  /// Plex-style tab chips on Android TV: no pill behind the tabs, the selected
  /// one underlined in orange, the focused one a light block with dark text.
  /// Null elsewhere, where the stock chip colours apply.
  static StreamerTabChipStyle? tabChipStyle(ColorScheme scheme, {required bool selected, required bool focused}) {
    if (!isAndroidTv) return null;
    if (focused) {
      return (background: scheme.onSurface.withValues(alpha: 0.92), foreground: scheme.surface, underline: false);
    }
    return (
      background: Colors.transparent,
      foreground: selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.62),
      underline: selected,
    );
  }

  /// Orange underline of the selected tab.
  static Widget underlineTabLabel(Widget label) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: accent, width: 2)),
      ),
      child: Padding(padding: const EdgeInsets.only(bottom: 3), child: label),
    );
  }
}
