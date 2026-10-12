// FORK: Plex-style TV detail page (StreamerFork.plexDetailLayout).
//
// Same pieces as upstream's _buildTvDetailScreen, arranged top to bottom the
// way Plex does on Android TV:
//
//   season tabs
//   title (plain text) / episode title / facts / scores / summary
//   episodes of the selected season
//   action buttons ............................ stream chips (1080p, audio…)
//   (empty space)
//   cast, extras and related rails, peeking at the bottom of the screen
//
// The D-pad goes tabs, episodes, action row, lower rail; the text block is
// not focusable. The page is two blocks in a Stack. D-pad DOWN from the action row hands
// focus to the lower rail and slides both blocks up so that rail is fully
// visible; UP from it slides them back.

part of '../media_detail_screen.dart';

extension _ForkTvDetail on _MediaDetailScreenState {
  /// Hubs of the upper rail: the episodes (or the "seasons failed" retry row).
  bool _isForkTvUpperHub(MediaHub hub) => _isTvDetailEpisodeHub(hub) || hub.id == _tvDetailSeasonsErrorHubId;

  bool _forkTvDetailStartsOnPlay(List<MediaHub> hubs) =>
      StreamerFork.plexDetailLayout && !hubs.any(_isForkTvUpperHub);

  /// UP from the action row: the episodes, when there are any. False only when
  /// the layout is off, so the caller then keeps its upstream target.
  bool _focusForkTvEpisodeRail() {
    if (!StreamerFork.plexDetailLayout) return false;
    final rail = _tvDetailRailKey.currentState;
    if (rail != null) {
      // Cleared first so the rail's focused episode is not discarded as a
      // notification arriving while the action row still has the D-pad.
      _tvDetailActionRowHasFocus = false;
      rail.requestFocus();
    }
    return true;
  }

  /// DOWN from the action row.
  void _focusForkTvLowerRail() {
    final rail = _forkTvLowerRailKey.currentState;
    if (rail == null) return;
    if (!_forkTvLowerRailActive) setStateIfMounted(() => _forkTvLowerRailActive = true);
    rail.requestFocus();
  }

  /// UP from the first row of the lower rail.
  void _leaveForkTvLowerRail() {
    if (_forkTvLowerRailActive) setStateIfMounted(() => _forkTvLowerRailActive = false);
    _focusTvDetailActionRow();
  }

  Widget _buildForkTvDetailContent(
    BuildContext context,
    MediaItem metadata, {
    required List<MediaHub> hubs,
    required bool hideSpoilers,
    required Size size,
  }) {
    final theme = Theme.of(context);
    final scale = TvLayoutConstants.scaleForSize(size);
    final upperHubs = [
      for (final hub in hubs)
        if (_isForkTvUpperHub(hub)) hub,
    ];
    final lowerHubs = [
      for (final hub in hubs)
        if (!_isForkTvUpperHub(hub)) hub,
    ];
    final showTabs = _showTvSeasonTabs(metadata);
    final hasEpisodes = upperHubs.isNotEmpty;

    // Left edge shared with the first card of the rails.
    final contentLeft = TvBrowseRailLayout.horizontalInsetForScale(scale) + 17 * scale;

    final upperRailHeight = hasEpisodes ? _estimateTvBrowseRailHeight(size, upperHubs) : 0.0;
    final lowerRailHeight = lowerHubs.isEmpty ? 0.0 : _estimateTvBrowseRailHeight(size, lowerHubs);
    // What stays visible of the lower rail at rest: its heading and the top
    // of the first row.
    final lowerPeek = lowerHubs.isEmpty ? 0.0 : (lowerRailHeight < 116 * scale ? lowerRailHeight : 116 * scale);
    final lowerActive = _forkTvLowerRailActive && lowerHubs.isNotEmpty;
    final upperHeight = size.height - lowerPeek;

    // Vertical budget of the upper block.
    final topMargin = (showTabs ? 24 : 40) * scale;
    final tabsGap = 16 * scale;
    final tabsHeight = showTabs ? _tvDetailSeasonTabsHeight + tabsGap : 0.0;
    final titleHeight = 60 * scale;
    final lineGap = 6 * scale;
    final episodeLineHeight = hasEpisodes && !metadata.isMovie ? 32 * scale : 0.0;
    final metadataLineHeight = 26 * scale;
    final summaryGap = 12 * scale;
    final summaryFontSize = 18 * scale;
    final summaryLineHeight = summaryFontSize * 1.35;
    final railGap = hasEpisodes ? 14 * scale : 0.0;
    final actionGap = (hasEpisodes ? 16 : 24) * scale;
    final actionHeight = _tvDetailActionSize * scale;
    final minimumEmptySpace = 36 * scale;
    final fixedHeight =
        topMargin +
        tabsHeight +
        titleHeight +
        lineGap +
        (episodeLineHeight > 0 ? episodeLineHeight + lineGap : 0) +
        metadataLineHeight * 2 +
        lineGap +
        summaryGap +
        railGap +
        upperRailHeight +
        actionGap +
        actionHeight +
        minimumEmptySpace;
    final summaryLines = ((upperHeight - fixedHeight) / summaryLineHeight).floor().clamp(0, hasEpisodes ? 3 : 4);

    // Where the lower rail rests. With episodes it peeks at the bottom of
    // the screen, below an empty band; without (a movie) it follows the
    // action row directly, like Plex. When it takes the D-pad, the page
    // slides up just enough to show it whole.
    final contentHeight = fixedHeight - minimumEmptySpace + summaryLines * summaryLineHeight;
    final peekTop = size.height - lowerPeek;
    final restTop = hasEpisodes ? peekTop : math.min(contentHeight + 12 * scale, peekTop);
    final slide = lowerActive ? math.max(0.0, restTop + lowerRailHeight - size.height) : 0.0;

    final infoBlock = Padding(
      padding: EdgeInsets.only(left: contentLeft, right: size.width * 0.40),
      child: ValueListenableBuilder<MediaItem?>(
        valueListenable: _tvDetailFocusedEpisode,
        builder: (context, _, _) => _buildForkTvDetailInfo(
          context,
          metadata,
          hideSpoilers: hideSpoilers,
          scale: scale,
          titleHeight: titleHeight,
          episodeLineHeight: episodeLineHeight,
          metadataLineHeight: metadataLineHeight,
          lineGap: lineGap,
          summaryGap: summaryGap,
          summaryFontSize: summaryFontSize,
          summaryLines: summaryLines,
        ),
      ),
    );

    final actionRow = Padding(
      padding: EdgeInsets.symmetric(horizontal: contentLeft),
      child: SizedBox(
        height: actionHeight,
        child: Row(
          children: [
            Expanded(child: _buildActionButtons(metadata)),
            SizedBox(width: 16 * scale),
            ValueListenableBuilder<MediaItem?>(
              valueListenable: _tvDetailFocusedEpisode,
              builder: (context, _, _) => _buildPlaybackTracksStatus(
                context,
                metadata,
                isTv: true,
                tvScale: scale,
                maxWidth: size.width * 0.46,
              ),
            ),
          ],
        ),
      ),
    );

    final upperBlock = ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topMargin),
            if (showTabs)
              Padding(
                padding: EdgeInsets.only(left: contentLeft, right: contentLeft, bottom: tabsGap),
                child: SizedBox(
                  height: _tvDetailSeasonTabsHeight,
                  child: Align(alignment: Alignment.centerLeft, child: _buildSeasonTabs()),
                ),
              ),
            infoBlock,
            SizedBox(height: railGap),
            if (hasEpisodes)
              TvBrowseRail(
                key: _tvDetailRailKey,
                hubs: upperHubs,
                focusMemory: _hubFocusMemory,
                iconForHub: _getTvDetailHubIcon,
                onFocusedHubItemChanged: _handleTvDetailFocusedRailItemChanged,
                onRefresh: (source) => unawaited(_refreshItemInPlace(source)),
                onActiveHubChanged: _handleTvDetailHubChanged,
                onActivateItem: _handleTvDetailRailItemActivated,
                trailingForHub: _tvDetailTrailingState,
                leadingItemForHub: _tvDetailLeadingItemForHub,
                onRetryHub: _retryTvDetailHub,
                onNavigateUp: _focusTvSeasonTabs,
                onNavigateDown: _focusTvDetailActionRow,
                onBack: _popMediaDetailIfBackNotSuppressed,
                tallPosterScale: _tvDetailTallPosterScale,
                widePosterScaleForHub: _tvDetailWidePosterScaleForHub,
                initialHubId: _tvDetailInitialHubId(metadata),
                initialItemId: _tvDetailInitialItemId(metadata),
                episodePosterModeForHub: _tvDetailEpisodePosterModeForHub,
                showTitleImpliedForHub: _isTvDetailEpisodeHub,
                plainBackground: true,
              ),
            SizedBox(height: actionGap),
            actionRow,
          ],
        ),
      ),
    );

    const slideDuration = Duration(milliseconds: 220);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shade toward the bottom, where the rails' headings and the action
        // row sit on the artwork without a band of their own.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.2, 0.7],
                  colors: [
                    theme.scaffoldBackgroundColor.withValues(alpha: 0),
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: slideDuration,
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          top: -slide,
          height: upperHeight,
          child: upperBlock,
        ),
        if (lowerHubs.isNotEmpty)
          AnimatedPositioned(
            duration: slideDuration,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            top: restTop - slide,
            child: TvBrowseRail(
              key: _forkTvLowerRailKey,
              hubs: lowerHubs,
              focusMemory: _hubFocusMemory,
              iconForHub: _getTvDetailHubIcon,
              onRefresh: (source) => unawaited(_refreshItemInPlace(source)),
              onActivateItem: _handleTvDetailRailItemActivated,
              trailingForHub: _tvDetailTrailingState,
              leadingItemForHub: _tvDetailLeadingItemForHub,
              onRetryHub: _retryTvDetailHub,
              onNavigateUp: _leaveForkTvLowerRail,
              onBack: _popMediaDetailIfBackNotSuppressed,
              tallPosterScale: _tvDetailTallPosterScale,
              widePosterScaleForHub: _tvDetailWidePosterScaleForHub,
              episodePosterModeForHub: _tvDetailEpisodePosterModeForHub,
              showTitleImpliedForHub: _isTvDetailEpisodeHub,
              plainBackground: true,
            ),
          ),
      ],
    );
  }

  /// Text title, the episode's title, the facts, the series' scores and the
  /// summary. Not focusable. Every line keeps a fixed height so the rows
  /// underneath do not move while the D-pad walks the episodes.
  ///
  /// The episode shown is the focused one, or, while the action row has the
  /// D-pad, the one its Play button starts.
  Widget _buildForkTvDetailInfo(
    BuildContext context,
    MediaItem metadata, {
    required bool hideSpoilers,
    required double scale,
    required double titleHeight,
    required double episodeLineHeight,
    required double metadataLineHeight,
    required double lineGap,
    required double summaryGap,
    required double summaryFontSize,
    required int summaryLines,
  }) {
    final theme = Theme.of(context);
    final foreground = _tvDetailForegroundColor(context);
    final episode =
        _tvDetailFocusedEpisode.value ?? (_tvDetailActionRowHasFocus && metadata.isShow ? _showPlayEpisode() : null);
    String? description;
    if (episode != null) {
      description = _tvDetailItemDescription(episode, hideSpoilers: hideSpoilers);
      if (description == null) {
        final season = _tvDetailSeasonForEpisode(episode, metadata);
        if (season != null) description = _tvDetailItemDescription(season, hideSpoilers: hideSpoilers);
      }
    }
    description ??= _tvDetailItemDescription(metadata, hideSpoilers: hideSpoilers);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: titleHeight,
          width: double.infinity,
          child: _buildDetailTitle(
            context,
            metadata.displayTitle,
            fontSize: 46 * scale,
            fontWeight: FontWeight.w800,
            shadowBlur: 10,
          ),
        ),
        SizedBox(height: lineGap),
        if (episodeLineHeight > 0) ...[
          SizedBox(
            height: episodeLineHeight,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                episode?.title ?? '',
                key: const ValueKey('tv_detail_episode_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: foreground, fontSize: 23 * scale, fontWeight: FontWeight.w700, height: 1.2),
              ),
            ),
          ),
          SizedBox(height: lineGap),
        ],
        StreamerMetaLines(
          item: episode ?? metadata,
          // The scores are always the series' (or the movie's), never an
          // episode's own.
          ratingsItem: metadata,
          scale: scale,
          color: foreground,
          lineHeight: metadataLineHeight,
          gap: lineGap,
          reserveRatingsLine: true,
        ),
        SizedBox(height: summaryGap),
        if (summaryLines > 0)
          SizedBox(
            height: summaryFontSize * 1.35 * summaryLines,
            width: double.infinity,
            child: Text(
              description ?? '',
              maxLines: summaryLines,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: foreground.withValues(alpha: 0.78),
                fontSize: summaryFontSize,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  /// Stream details as outlined chips ("1080p", "English (EAC3 5.1)", …).
  /// The first chips keep their width; the last ones shrink with an ellipsis.
  Widget _buildForkTrackChips(
    BuildContext context,
    List<MetadataLinePart> parts, {
    required double scale,
    required double maxWidth,
  }) {
    final foreground = _tvDetailForegroundColor(context);
    final style = TextStyle(
      color: foreground.withValues(alpha: 0.92),
      fontSize: 15 * scale,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    Widget chip({IconData? icon, required String label, required bool shrinks}) {
      final box = Container(
        margin: EdgeInsets.only(left: 8 * scale),
        padding: EdgeInsets.symmetric(horizontal: 9 * scale, vertical: 5 * scale),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          border: Border.all(color: foreground.withValues(alpha: 0.38)),
          borderRadius: BorderRadius.circular(5 * scale),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIcon(icon, fill: 1, size: 16 * scale, color: style.color),
              SizedBox(width: 5 * scale),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: style),
            ),
          ],
        ),
      );
      return shrinks ? Flexible(child: box) : box;
    }

    final chips = <Widget>[
      for (final part in parts)
        switch (part) {
          MetadataLineText(:final text) => chip(label: text, shrinks: false),
          MetadataLineIconText(:final icon, :final text, :final detail) => chip(
            icon: icon,
            label: detail == null ? text : '$text ($detail)',
            shrinks: true,
          ),
          MetadataLineRatings() => const SizedBox.shrink(),
        },
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: chips),
    );
  }
}
