// FORK: in-app updater for the Plezy Streamer build.
//
// Looks up the latest release of [StreamerFork.githubRepo], downloads the APK
// matching the running process, hands it to Android's package installer, and
// removes the downloaded file on the next launch.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/app_icon.dart';
import '../widgets/focusable_list_tile.dart';
import '../widgets/settings_section.dart';
import 'streamer_fork.dart';

/// A published build of the fork.
class StreamerRelease {
  final int build;
  final Uri apkUrl;

  /// Size of the APK in bytes as published, or 0 when GitHub did not say.
  final int size;
  const StreamerRelease({required this.build, required this.apkUrl, this.size = 0});
}

class StreamerUpdateService {
  StreamerUpdateService._();

  static const _channel = MethodChannel('com.plezy.fork/update');
  static const _apkPrefix = 'plezy-streamer-';
  static const _tagPrefix = 'streamer-';

  /// The updater installs APKs, so it only exists on Android.
  static bool get isAvailable => Platform.isAndroid;

  /// Release asset built for the ABI this process runs as. A 32-bit system
  /// (the Google TV Streamer) therefore never picks the 64-bit APK.
  static String get _assetName =>
      Abi.current() == Abi.androidArm64 ? 'plezy-android-arm64-v8a.apk' : 'plezy-android-armeabi-v7a.apk';

  /// One file name per build, so each update reaches the installer under its
  /// own address.
  static Future<File> _apkFile(int build) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$_apkPrefix$build.apk');
  }

  /// Removes every downloaded APK except [keep].
  static Future<void> _deleteApks({String? keep}) async {
    final dir = await getTemporaryDirectory();
    if (!await dir.exists()) return;
    await for (final entry in dir.list(followLinks: false)) {
      if (entry is! File || entry.path == keep) continue;
      final name = entry.uri.pathSegments.last;
      if (name.startsWith(_apkPrefix) && name.endsWith('.apk')) await entry.delete();
    }
  }

  /// Deletes previously downloaded APKs. Called at launch, which is the first
  /// moment after an install where the file is certainly no longer needed.
  static Future<void> deleteDownloadedApk() async {
    if (!isAvailable) return;
    try {
      await _deleteApks();
    } catch (e, st) {
      appLogger.w('Streamer update: could not delete the downloaded APK', error: e, stackTrace: st);
    }
  }

  static Future<StreamerRelease> fetchLatest() async {
    final uri = Uri.https('api.github.com', '/repos/${StreamerFork.githubRepo}/releases/latest');
    final response = await http
        .get(uri, headers: const {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('GitHub a répondu ${response.statusCode}', uri: uri);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Réponse GitHub inattendue');
    final tag = decoded['tag_name'];
    final build = tag is String && tag.startsWith(_tagPrefix) ? int.tryParse(tag.substring(_tagPrefix.length)) : null;
    if (build == null) throw FormatException('Version inconnue : $tag');
    final assets = decoded['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map && asset['name'] == _assetName) {
          final url = asset['browser_download_url'];
          final size = asset['size'];
          if (url is String) {
            return StreamerRelease(build: build, apkUrl: Uri.parse(url), size: size is int ? size : 0);
          }
        }
      }
    }
    throw FormatException('Fichier $_assetName absent de la version $tag');
  }

  /// Streams the APK to the cache directory, reporting 0..1 through
  /// [onProgress] when the server announces a length.
  static Future<File> download(StreamerRelease release, {void Function(double progress)? onProgress}) async {
    final file = await _apkFile(release.build);
    // Never more than one APK on disk.
    await _deleteApks(keep: file.path);
    if (await file.exists()) {
      // Already downloaded in full (a second press after a dismissed
      // installer): reuse it instead of fetching it again.
      if (release.size > 0 && await file.length() == release.size) {
        onProgress?.call(1);
        return file;
      }
      await file.delete();
    }
    final client = http.Client();
    IOSink? sink;
    try {
      final response = await client.send(http.Request('GET', release.apkUrl)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('Téléchargement refusé (${response.statusCode})', uri: release.apkUrl);
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      var lastReported = -1;
      sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          final percent = (received * 100) ~/ total;
          if (percent != lastReported) {
            lastReported = percent;
            onProgress(received / total);
          }
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (release.size > 0 && received != release.size) {
        throw HttpException('Téléchargement incomplet ($received sur ${release.size} octets)', uri: release.apkUrl);
      }
      return file;
    } catch (_) {
      await sink?.close();
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Opens Android's installer on [apk]. Android asks the user to confirm, and
  /// the first time to allow this app as an install source.
  static Future<void> install(File apk) async {
    await _channel.invokeMethod<void>('installApk', {'path': apk.path});
  }
}

enum _UpdatePhase { idle, checking, downloading, installing }

/// Settings group with the "update Plezy Streamer" button.
class StreamerUpdateSection extends StatefulWidget {
  const StreamerUpdateSection({super.key});

  @override
  State<StreamerUpdateSection> createState() => _StreamerUpdateSectionState();
}

class _StreamerUpdateSectionState extends State<StreamerUpdateSection> {
  _UpdatePhase _phase = _UpdatePhase.idle;
  double _progress = 0;
  String? _note;

  bool get _busy => _phase != _UpdatePhase.idle;

  String get _installedLabel =>
      StreamerFork.buildNumber > 0 ? 'Version installée : ${StreamerFork.buildNumber}' : 'Version installée : inconnue';

  String get _subtitle {
    switch (_phase) {
      case _UpdatePhase.checking:
        return 'Vérification sur GitHub…';
      case _UpdatePhase.downloading:
        return 'Téléchargement… ${(_progress * 100).round()} %';
      case _UpdatePhase.installing:
        return "Ouverture de l'installation…";
      case _UpdatePhase.idle:
        final note = _note;
        return note == null ? _installedLabel : '$_installedLabel · $note';
    }
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() {
      _phase = _UpdatePhase.checking;
      _note = null;
    });
    try {
      final release = await StreamerUpdateService.fetchLatest();
      if (!mounted) return;
      if (StreamerFork.buildNumber > 0 && release.build <= StreamerFork.buildNumber) {
        setState(() {
          _phase = _UpdatePhase.idle;
          _note = 'à jour';
        });
        showAppSnackBar(context, 'Plezy Streamer est à jour (version ${StreamerFork.buildNumber}).');
        return;
      }
      setState(() {
        _phase = _UpdatePhase.downloading;
        _progress = 0;
      });
      final apk = await StreamerUpdateService.download(
        release,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      setState(() => _phase = _UpdatePhase.installing);
      await StreamerUpdateService.install(apk);
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.idle;
        _note = "version ${release.build} téléchargée, appuie de nouveau si l'installation ne s'est pas ouverte";
      });
    } catch (e, st) {
      appLogger.w('Streamer update failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.idle;
        _note = 'échec de la mise à jour';
      });
      showErrorSnackBar(context, 'Mise à jour impossible : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: 'Plezy Streamer',
      children: [
        FocusableListTile(
          leading: const AppIcon(Symbols.system_update_rounded, fill: 1),
          title: const Text('Mettre à jour Plezy Streamer'),
          subtitle: Text(_subtitle),
          trailing: _busy
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: _phase == _UpdatePhase.downloading && _progress > 0 ? _progress : null,
                  ),
                )
              : const AppIcon(Symbols.chevron_right_rounded, fill: 1),
          onTap: _busy ? null : () => unawaited(_run()),
        ),
      ],
    );
  }
}
