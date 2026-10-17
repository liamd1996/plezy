// FORK: resuming after a long pause.
//
// After hours on pause (the TV in standby, the app in the background) the
// server has usually closed the stream: Play then does nothing and the video
// has to be reopened from the menu. Play after StreamerFork.longPause
// reopens the stream in place at the paused position instead.

part of '../../video_player_screen.dart';

extension _ForkLongPause on VideoPlayerScreenState {
  bool _forkPausedTooLong(Player currentPlayer) {
    if (!StreamerFork.reloadAfterLongPause || widget.isLive || _isOfflinePlayback) return false;
    if (currentPlayer.state.playing) return false;
    final pausedAt = _lastPlaybackPauseAt;
    return pausedAt != null && DateTime.now().difference(pausedAt) >= StreamerFork.longPause;
  }

  Future<void> _forkResumeAfterLongPause(Player currentPlayer) async {
    final position = currentPlayer.state.position;
    _lastPlaybackPauseAt = null;
    _playbackIntentShouldPlay = true;
    appLogger.i('Resuming after a long pause: reopening the stream at ${position.inSeconds}s');
    final outcome = await _reloadMediaInPlace(
      metadata: _currentMetadata,
      resumePosition: position,
      preserveCurrentTrackSelection: true,
      reason: 'resume after long pause',
    );
    if (outcome == MediaReloadOutcome.opened || !mounted || player != currentPlayer) return;
    // The reopen did not happen: fall back to a plain play.
    await currentPlayer.play();
  }
}
