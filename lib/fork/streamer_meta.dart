// FORK: Plex-style facts under a title, shared by the home hero and the TV
// detail page:
//
//   S2 · E3    15 sept. 2024    42min    TV-MA
//   (ratings)

import 'package:flutter/material.dart';

import '../media/media_item.dart';
import '../media/media_item_types.dart';
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
    this.ratingsFallback,
    this.trailing,
    this.lineHeight,
    this.gap = 0,
    this.reserveRatingsLine = false,
  });

  /// The item the facts describe (the focused episode, or the show or movie).
  final MediaItem item;

  /// Where the ratings come from when [item] carries none (the show of an episode).
  final MediaItem? ratingsFallback;
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
    final ratings = mediaRatingsFor(item, fallbackItem: ratingsFallback);
    final extra = trailing;

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
              textStyle: style,
              parts: [MetadataLineRatings(ratings, dropPriority: 0)],
              ratingIconSize: style.fontSize,
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
