# Plezy Streamer (personal fork)

Unofficial build of [Plezy](https://github.com/edde746/plezy) with a lighter,
Plex-like interface on Android TV / Google TV. Phones, tablets and desktop
behave like stock Plezy: every change is gated on Android TV.

This file is the map for carrying the changes onto a newer Plezy release.

## How the changes are organised

| Where | What |
| --- | --- |
| `lib/fork/streamer_fork.dart` | Every switch, size and colour of the fork. |
| `lib/fork/streamer_update.dart` | In-app updater (Settings > Plezy Streamer). |
| `android/.../fork/StreamerUpdateChannel.kt` | Native half of the updater. |
| `.github/workflows/streamer-apk.yml` | Builds the APKs and publishes a release. |
| Upstream files | Short hooks only, each marked with a `FORK:` comment. |

List every hook with:

```bash
git grep -n "FORK:" -- lib android
```

## What the fork changes (Android TV only)

- Downloads UI hidden (tab, buttons, menu entries, settings section).
- Whole interface drawn at `StreamerFork.tvUiScale` (smaller text and cards).
- Image-only cards and corner artwork on by default (still adjustable in
  Settings > Appearance).
- Watch Together and Companion Remote buttons removed from the home top bar.
- Side rail in Plex order: Search, Home, one row per library, Settings at the
  bottom; no "Libraries" header or server groups.
- Show page: one row of season tabs and a single episode rail, instead of one
  stacked rail per season.
- Plex orange for progress bars, the selected tab and the selected rail icon.
- Titles as plain text instead of each item's logo artwork (home hero and
  detail page).
- Detail page laid out like Plex (`lib/screens/media_detail/fork_tv_detail.dart`):
  season tabs at the top, title and summary, the episodes, then the action
  buttons with the stream details as chips on the same row, and the cast rail
  peeking at the bottom; it slides up when the D-pad reaches it.
- Plex-style facts under titles (`lib/fork/streamer_meta.dart`): episode name,
  then season/episode, date, duration and rating, then the scores on their own
  line. Taller rail headings.
- A show's theme music plays once on its detail page (`lib/fork/streamer_theme.dart`,
  native player in `android/.../fork/StreamerThemeChannel.kt`).
- Round cast portraits, an "E7" badge on episode thumbnails, wider gutters
  between cards.
- Own application id (`com.edde746.plezy.streamer`) and label, so it installs
  next to the official app.
- Settings > Plezy Streamer: downloads the latest APK from this repository's
  releases and opens Android's installer.

## Updating to a newer Plezy release

The `streamer` branch is the upstream release tag plus the fork commits.

```bash
git remote add upstream https://github.com/edde746/plezy.git   # once
git fetch upstream tag <new-tag>
git checkout streamer
git rebase --onto <new-tag> <old-tag> streamer
```

Conflicts can only appear in the hooked upstream files. For each one, keep
upstream's new code and re-apply the one- or few-line `FORK:` hook around it;
the logic itself lives in `lib/fork/` and does not conflict. Then:

1. `git grep -n "FORK:" -- lib android` and compare with the list from the
   previous version: every hook should still be there.
2. Push `streamer`. The workflow analyses the code first, so a hook that no
   longer compiles fails within a few minutes.
3. Largest hooked areas, most likely to need attention: the TV detail screen
   (`lib/screens/media_detail_screen.dart`, season tabs) and the side rail
   (`lib/widgets/side_navigation_rail.dart`).

## Releases and signing

Each push to `streamer` publishes a release tagged `streamer-<run number>` with
`plezy-android-armeabi-v7a.apk` (Google TV Streamer, 32-bit) and
`plezy-android-arm64-v8a.apk`. The run number is compiled in as
`STREAMER_BUILD`, which the in-app updater compares with the latest release.

APKs are signed with the keystore stored in the `ANDROID_KEYSTORE_BASE64`
repository secret, so a new build installs over the previous one.
