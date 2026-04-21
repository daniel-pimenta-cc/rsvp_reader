import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as ga;

import '../../domain/repositories/sync_folder_gateway.dart';

const _folderMime = 'application/vnd.google-apps.folder';

/// Google Drive-backed sync gateway. Uses the `drive.file` OAuth scope, so
/// it can only see files and folders this app has created.
///
/// The "folder path" passed to each method is the Drive file ID of the
/// root folder (cached in [SyncConfig.driveFolderId]). Relative paths are
/// walked segment by segment; folders are created on demand during writes.
class DriveSyncFolderGateway implements SyncFolderGateway {
  final Future<ga.AuthClient?> Function() _clientFactory;
  final Map<String, String> _folderIdCache = {};

  DriveSyncFolderGateway(this._clientFactory);

  Future<drive.DriveApi?> _api() async {
    final client = await _clientFactory();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  List<String> _split(String path) =>
      path.split('/').where((p) => p.isNotEmpty).toList();

  /// Escape single quotes for Drive query strings.
  String _esc(String v) => v.replaceAll("'", r"\'");

  /// Walk [segments] starting at [rootId], resolving each folder. When
  /// [create] is true, missing folders are created; otherwise returns null
  /// as soon as a segment isn't found. Results are cached by the full
  /// relative path so repeat calls within a session are cheap.
  Future<String?> _resolveFolder(
    drive.DriveApi api,
    String rootId,
    List<String> segments, {
    bool create = false,
  }) async {
    if (segments.isEmpty) return rootId;
    final cacheKey = segments.join('/');
    final cached = _folderIdCache[cacheKey];
    if (cached != null) return cached;

    String parentId = rootId;
    for (final seg in segments) {
      final q = "'${_esc(parentId)}' in parents "
          "and name='${_esc(seg)}' "
          "and mimeType='$_folderMime' "
          'and trashed=false';
      final res =
          await api.files.list(q: q, $fields: 'files(id,name)');
      final files = res.files ?? <drive.File>[];
      if (files.isNotEmpty) {
        parentId = files.first.id!;
      } else if (create) {
        final created = await api.files.create(drive.File()
          ..name = seg
          ..mimeType = _folderMime
          ..parents = [parentId]);
        parentId = created.id!;
      } else {
        return null;
      }
    }
    _folderIdCache[cacheKey] = parentId;
    return parentId;
  }

  Future<drive.File?> _findFile(
    drive.DriveApi api,
    String parentId,
    String name,
  ) async {
    final q = "'${_esc(parentId)}' in parents "
        "and name='${_esc(name)}' "
        'and trashed=false';
    final res =
        await api.files.list(q: q, $fields: 'files(id,name,mimeType)');
    final files = res.files ?? <drive.File>[];
    if (files.isEmpty) return null;
    return files.first;
  }

  @override
  Future<bool> isReadable(String folderPath) async {
    try {
      final api = await _api();
      if (api == null) return false;
      await api.files.get(folderPath, $fields: 'id');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> readText(String folderPath, String relativePath) async {
    final bytes = await readBytes(folderPath, relativePath);
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  @override
  Future<Uint8List?> readBytes(
    String folderPath,
    String relativePath,
  ) async {
    final api = await _api();
    if (api == null) return null;
    final parts = _split(relativePath);
    if (parts.isEmpty) return null;
    final dirSegments = parts.sublist(0, parts.length - 1);
    final fileName = parts.last;
    final parentId = await _resolveFolder(api, folderPath, dirSegments);
    if (parentId == null) return null;
    final file = await _findFile(api, parentId, fileName);
    if (file == null) return null;
    final media = await api.files.get(
      file.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  @override
  Future<void> writeText(
    String folderPath,
    String relativePath,
    String content,
  ) async {
    await writeBytes(
      folderPath,
      relativePath,
      Uint8List.fromList(utf8.encode(content)),
    );
  }

  @override
  Future<void> writeBytes(
    String folderPath,
    String relativePath,
    Uint8List bytes,
  ) async {
    final api = await _api();
    if (api == null) {
      throw StateError('Drive client unavailable — not signed in');
    }
    final parts = _split(relativePath);
    if (parts.isEmpty) {
      throw ArgumentError('Cannot write to an empty relative path');
    }
    final dirSegments = parts.sublist(0, parts.length - 1);
    final fileName = parts.last;
    final parentId =
        await _resolveFolder(api, folderPath, dirSegments, create: true);
    if (parentId == null) {
      throw StateError('Failed to resolve/create folder for $relativePath');
    }
    final existing = await _findFile(api, parentId, fileName);
    final media = drive.Media(Stream.value(bytes), bytes.length);
    if (existing != null) {
      await api.files.update(
        drive.File()..name = fileName,
        existing.id!,
        uploadMedia: media,
      );
    } else {
      await api.files.create(
        drive.File()
          ..name = fileName
          ..parents = [parentId],
        uploadMedia: media,
      );
    }
  }

  @override
  Future<bool> fileExists(String folderPath, String relativePath) async {
    final api = await _api();
    if (api == null) return false;
    final parts = _split(relativePath);
    if (parts.isEmpty) return false;
    final dirSegments = parts.sublist(0, parts.length - 1);
    final fileName = parts.last;
    final parentId = await _resolveFolder(api, folderPath, dirSegments);
    if (parentId == null) return false;
    final file = await _findFile(api, parentId, fileName);
    return file != null;
  }

  @override
  Future<void> deleteFile(String folderPath, String relativePath) async {
    final api = await _api();
    if (api == null) return;
    final parts = _split(relativePath);
    if (parts.isEmpty) return;
    final dirSegments = parts.sublist(0, parts.length - 1);
    final fileName = parts.last;
    final parentId = await _resolveFolder(api, folderPath, dirSegments);
    if (parentId == null) return;
    final file = await _findFile(api, parentId, fileName);
    if (file == null) return;
    await api.files.delete(file.id!);
  }

  @override
  Future<List<String>> listFiles(
    String folderPath,
    String relativePath,
  ) async {
    final api = await _api();
    if (api == null) return const [];
    final parts = _split(relativePath);
    final parentId = await _resolveFolder(api, folderPath, parts);
    if (parentId == null) return const [];
    final names = <String>[];
    String? pageToken;
    final q = "'${_esc(parentId)}' in parents "
        'and trashed=false '
        "and mimeType!='$_folderMime'";
    do {
      final res = await api.files.list(
        q: q,
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,name)',
        pageSize: 200,
      );
      for (final f in res.files ?? <drive.File>[]) {
        final name = f.name;
        if (name != null && name.isNotEmpty) names.add(name);
      }
      pageToken = res.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return names;
  }

  /// Find or create the root app folder in the user's Drive. Called once
  /// during the connect flow; the returned ID is persisted in [SyncConfig]
  /// so subsequent sessions skip this lookup.
  ///
  /// With the `drive.file` scope we only see folders created by this app,
  /// so the lookup is safe even if the user also has unrelated folders
  /// with the same name.
  Future<String> ensureRootFolder({String name = 'RSVP Reader'}) async {
    final api = await _api();
    if (api == null) {
      throw StateError('Drive client unavailable — not signed in');
    }
    final q = "mimeType='$_folderMime' "
        "and name='${_esc(name)}' "
        'and trashed=false '
        "and 'root' in parents";
    final res = await api.files.list(q: q, $fields: 'files(id,name)');
    final files = res.files ?? <drive.File>[];
    if (files.isNotEmpty) return files.first.id!;
    final created = await api.files.create(drive.File()
      ..name = name
      ..mimeType = _folderMime
      ..parents = ['root']);
    return created.id!;
  }

  /// Drop cached folder IDs — useful after disconnect so the next sign-in
  /// starts from a clean slate even on the same gateway instance.
  void clearCache() => _folderIdCache.clear();
}
