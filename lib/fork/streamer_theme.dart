// FORK: a show's theme music on its detail page, like Plex. Played once per
// visit; stopped when the page closes or another page (the player, a cast
// member) opens on top of it. Plex servers on Android TV only; the audio is
// played natively (android/.../fork/StreamerThemeChannel.kt).

import 'package:flutter/services.dart';

import '../media/media_backend.dart';
import '../media/media_item.dart';
import '../media/media_item_types.dart';
import '../media/media_server_client.dart';
import '../utils/app_logger.dart';
import 'streamer_fork.dart';

abstract final class StreamerThemeMusic {
  static const _channel = MethodChannel('com.plezy.fork/theme');

  /// Playback gain (linear). Theme songs are mastered far louder than TV
  /// dialogue, so this sits around -20 dB to land under the shows' own level.
  static const double _volume = 0.1;

  static bool get enabled => StreamerFork.isAndroidTv;

  /// Starts the theme of [item]'s show. A season or an episode plays its
  /// show's; movies have none. Silently does nothing when the server has no
  /// theme for it.
  static void playFor(MediaItem item, MediaServerClient? client) {
    if (!enabled || client == null || item.backend != MediaBackend.plex) return;
    final showId = item.isShow ? item.id : (item.isSeason ? item.parentId : (item.isEpisode ? item.grandparentId : null));
    if (showId == null || showId.isEmpty) return;
    // On Plex an unsized "thumbnail" URL is just the server path made
    // absolute and authenticated, which is what the theme needs.
    final url = client.thumbnailUrl('/library/metadata/$showId/theme');
    if (url.isEmpty) return;
    _invoke('play', {'url': url, 'headers': client.streamHeaders, 'volume': _volume});
  }

  static void stop() {
    if (!enabled) return;
    _invoke('stop');
  }

  static void _invoke(String method, [Map<String, Object?>? arguments]) {
    _channel.invokeMethod<void>(method, arguments).catchError((Object e) {
      appLogger.d('Streamer theme music: $method failed', error: e);
    });
  }
}
