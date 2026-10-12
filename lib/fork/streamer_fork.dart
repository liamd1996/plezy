// FORK: single home of the "Plezy Streamer" customisations.
//
// Upstream files only carry one-line hooks that point here, each marked with a
// `// FORK:` comment, so `git grep -n "FORK:"` lists every touch point after a
// rebase onto a new Plezy release. See FORK.md at the repository root.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:material_symbols_icons/symbols.dart';

import 'package:provider/provider.dart';

import '../media/media_item.dart';
import '../media/media_item_types.dart';
import '../providers/hidden_libraries_provider.dart';
import '../providers/libraries_provider.dart';
import '../utils/platform_detector.dart';
import '../widgets/app_icon.dart';

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

  /// Whether [serverId] is the main server: the one of the first library shown
  /// in the side rail. The fork names a server (under a library, after a rail
  /// heading) only when it is another one.
  static bool isMainServer(BuildContext context, String? serverId) {
    if (serverId == null) return true;
    try {
      final hidden = Provider.of<HiddenLibrariesProvider>(context, listen: false).hiddenLibraryKeys;
      for (final library in Provider.of<LibrariesProvider>(context, listen: false).libraries) {
        if (library.serverId == null || hidden.contains(library.globalKey)) continue;
        return library.serverId == serverId;
      }
    } catch (_) {
      // No providers above this context: treat every server as the main one.
    }
    return true;
  }

  /// Rail headings drop the "· server" suffix for the main server.
  static bool hidesRailServerName(BuildContext context, String? serverId) =>
      isAndroidTv && isMainServer(context, serverId);

  /// `defaultValueProvider` for TV appearance settings the fork turns on out
  /// of the box (image-only cards, artwork in the corner). The user can still
  /// change them in Settings > Appearance.
  static bool tvDefaultOn() => isAndroidTv;

  /// Library grids keep the title and year under posters, even with the
  /// image-only cards used everywhere else.
  static bool get captionedLibraryGrids => isAndroidTv;

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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  // Faint light from the top, as on Plex's pages.
                  IgnorePointer(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _videoScreens,
                      builder: (context, videoScreens, _) => videoScreens > 0
                          ? const SizedBox.shrink()
                          : const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.0, 0.6],
                                  colors: [Color(0x10FFFFFF), Color(0x00FFFFFF)],
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Titles as plain text on Android TV, instead of each item's clear-logo
  /// artwork, and how much smaller than upstream's text title they are drawn.
  static bool get textTitles => isAndroidTv;
  static double get textTitleFactor => isAndroidTv ? 0.8 : 1.0;

  /// Gutter between image-only cards in rails and grids; null off Android TV.
  static double? cardGapForScale(double scale) => isAndroidTv ? (20 * scale).clamp(14, 30).toDouble() : null;

  /// Height of a rail's heading strip and how much of the next rail's heading
  /// peeks under the active one, before the rail's scale. Taller than
  /// upstream on Android TV so headings are not glued to the cards.
  static double get railHeaderHeight => isAndroidTv ? 54 : 30;

  /// On Android TV the peek also shows the top of the next rail's cards.
  static double get railNextHeaderPeek => isAndroidTv ? 100 : 20;

  /// Rail headings: larger text and no leading icon on Android TV.
  static double get railHeaderFontSize => isAndroidTv ? 22 : 18;
  static bool get railHeaderIcons => !isAndroidTv;

  /// "S2 · E3" on the detail page's Play button; null keeps upstream's label.
  static String? playEpisodeLabel(int season, int episode) => isAndroidTv ? 'S$season · E$episode' : null;

  /// Plex-style facts under titles: episode name, then "S2 · E3  date
  /// duration  rating", then the scores on their own line
  /// (lib/fork/streamer_meta.dart).
  static bool get plexMetaLines => isAndroidTv;

  // --------------------------------------------------------------------------
  // Cards
  // --------------------------------------------------------------------------

  /// Round cast portraits with the name underneath.
  static bool get roundActors => isAndroidTv;

  /// Caption height under a round portrait, before the rail's scale.
  static double get roundActorLabelHeight => roundActors ? 46 : 0;

  /// "E7" badge (with a check when watched) in the top-right corner of an
  /// episode thumbnail. Null when the card is not an episode or off Android TV.
  static Widget? episodeBadge(MediaItem item, {required bool showWatched}) {
    final number = item.index;
    if (!isAndroidTv || !item.isEpisode || number == null) return null;
    final watched = showWatched && item.isWatched && !item.hasActiveProgress;
    return Positioned(
      top: 7,
      right: 7,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xD91C1C1E),
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (watched) ...[
                const AppIcon(Symbols.check_rounded, fill: 1, size: 15, color: Colors.white),
                const SizedBox(width: 3),
              ],
              Text(
                'E$number',
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.1, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Detail page
  // --------------------------------------------------------------------------

  /// Plex-style TV detail page: season tabs at the top, text title and info,
  /// the episodes, then the action buttons with the stream details on the
  /// same row, and the cast peeking at the bottom of the screen
  /// (lib/screens/media_detail/fork_tv_detail.dart).
  static bool get plexDetailLayout => isAndroidTv;

  // --------------------------------------------------------------------------
  // Colours
  // --------------------------------------------------------------------------

  /// Page background and raised surfaces of the dark themes: charcoal rather
  /// than black, under a faint top-down sheen ([scaleInterface]).
  static const Color tvBackground = Color(0xFF131418);
  static const Color tvSurface = Color(0xFF1D1E23);

  /// Number of open video player screens; the sheen is not drawn over video.
  static final ValueNotifier<int> _videoScreens = ValueNotifier<int>(0);
  static void videoScreenOpened() => _videoScreens.value++;
  static void videoScreenClosed() => _videoScreens.value = math.max(0, _videoScreens.value - 1);

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
