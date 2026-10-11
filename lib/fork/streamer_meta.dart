// FORK: Plex-style facts under a title, shared by the home hero and the TV
// detail page:
//
//   S2 · E3    15 sept. 2024    42min    TV-MA
//   (ratings)

import 'dart:async';

import 'package:flutter/material.dart';

import '../media/catalog_item_ref.dart';
import '../media/media_item.dart';
import '../media/media_item_types.dart';
import '../media/media_server_client.dart';
import '../utils/content_utils.dart';
import '../utils/formatters.dart';
import '../widgets/fitted_metadata_line.dart';
import '../widgets/media_rating_badge.dart';

class StreamerMetaLines extends StatelessWidget {
  const StreamerMetaLines({
    super.key,
    required this.item,
    required this.scale,
    required this.color,
    this.ratingsItem,
    this.trailing,
    this.lineHeight,
    this.gap = 0,
    this.reserveRatingsLine = false,
  });

  /// The item the facts describe (the focused episode, or the show or movie).
  final MediaItem item;

  /// Whose scores are shown instead of [item]'s own: the series of an
  /// episode. Null shows [item]'s.
  final MediaItem? ratingsItem;
  final double scale;
  final Color color;

  /// Caller-owned extra fact appended to the first line.
  final Widget? trailing;

  /// Fixed height of each line; null lets the lines size themselves.
  final double? lineHeight;
  final double gap;

  /// Keeps the second line's height when there are no ratings, so what sits
  /// below does not move between items.
  final bool reserveRatingsLine;

  List<String> _facts() {
    final facts = <String>[];
    if (item.isEpisode && item.index != null) {
      facts.add(item.parentIndex != null ? 'S${item.parentIndex} · E${item.index}' : 'E${item.index}');
    }
    if (item.isEpisode && item.originallyAvailableAt != null) {
      facts.add(formatAbbreviatedDate(item.originallyAvailableAt!));
    } else if (item.year != null) {
      facts.add(item.year.toString());
    }
    if (item.durationMs != null) facts.add(formatDurationTextual(item.durationMs!));
    if (item.contentRating != null) facts.add(formatContentRating(item.contentRating!));
    return facts;
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: color, fontSize: 18 * scale, fontWeight: FontWeight.w700, letterSpacing: 0.1);
    final facts = _facts();
    final ratings = mediaRatingsFor(ratingsItem ?? item);
    final extra = trailing;
    // Scores read as a footnote to the facts line.
    final ratingStyle = style.copyWith(fontSize: 13.5 * scale, fontWeight: FontWeight.w600);

    Widget line(Widget child) {
      final aligned = Align(alignment: Alignment.centerLeft, child: child);
      return lineHeight == null ? aligned : SizedBox(height: lineHeight, width: double.infinity, child: aligned);
    }

    final factsLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0) SizedBox(width: 20 * scale),
          // The first facts keep their width; the last one gives way.
          if (i == facts.length - 1 && extra == null)
            Flexible(
              child: Text(facts[i], maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: style),
            )
          else
            Text(facts[i], maxLines: 1, softWrap: false, style: style),
        ],
        if (extra != null) ...[if (facts.isNotEmpty) SizedBox(width: 20 * scale), Flexible(child: extra)],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(factsLine),
        if (ratings.isNotEmpty) ...[
          SizedBox(height: gap),
          line(
            FittedMetadataLine(
              textStyle: ratingStyle,
              parts: [MetadataLineRatings(ratings, dropPriority: 0)],
              ratingIconSize: ratingStyle.fontSize,
              ratingSpacing: 4 * scale,
              ratingEntrySpacing: 16 * scale,
            ),
          ),
        ] else if (reserveRatingsLine && lineHeight != null)
          SizedBox(height: gap + lineHeight!),
      ],
    );
  }
}

/// [StreamerMetaLines] for the home hero. Rails only carry a title's headline
/// scores, so this fetches the full item once the hero has rested on it for a
/// moment and then shows every score (Rotten Tomatoes included). An episode or
/// a season shows its series' scores.
class StreamerHeroMetaLines extends StatefulWidget {
  const StreamerHeroMetaLines({
    super.key,
    required this.item,
    required this.client,
    required this.scale,
    required this.color,
    this.trailing,
    this.lineHeight,
    this.gap = 0,
  });

  final MediaItem item;
  final MediaServerClient? client;
  final double scale;
  final Color color;
  final Widget? trailing;
  final double? lineHeight;
  final double gap;

  @override
  State<StreamerHeroMetaLines> createState() => _StreamerHeroMetaLinesState();
}

class _StreamerHeroMetaLinesState extends State<StreamerHeroMetaLines> {
  static const _cacheLimit = 80;
  static final Map<String, MediaItem> _cache = <String, MediaItem>{};

  Timer? _timer;
  MediaItem? _ratingsItem;

  /// Id of the item whose scores are shown: the series for an episode or a
  /// season, the item itself otherwise. Null when it cannot be fetched.
  String? get _ratingsId {
    final item = widget.item;
    if (item.catalogItem != null) return null;
    if (item.isEpisode) return item.grandparentId;
    if (item.isSeason) return item.parentId;
    return item.id;
  }

  String? get _cacheKey {
    final id = _ratingsId;
    return id == null ? null : '${widget.item.serverId}|$id';
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(StreamerHeroMetaLines oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.globalKey != widget.item.globalKey) _resolve();
  }

  void _resolve() {
    _timer?.cancel();
    final key = _cacheKey;
    final id = _ratingsId;
    _ratingsItem = key == null ? null : _cache[key];
    final client = widget.client;
    if (_ratingsItem != null || key == null || id == null || client == null) return;
    _timer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final full = await client.fetchItem(id);
        if (full == null) return;
        if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
        _cache[key] = full;
        if (mounted && _cacheKey == key) setState(() => _ratingsItem = full);
      } catch (_) {
        // Scores are a nicety: keep whatever the rail already carried.
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    // Until the series is fetched an episode shows no scores, so its own
    // never flash in first.
    final own = item.isEpisode || item.isSeason ? item.copyWith(ratings: const [], rating: null) : item;
    return StreamerMetaLines(
      item: item,
      ratingsItem: _ratingsItem ?? own,
      scale: widget.scale,
      color: widget.color,
      trailing: widget.trailing,
      lineHeight: widget.lineHeight,
      gap: widget.gap,
      reserveRatingsLine: true,
    );
  }
}
