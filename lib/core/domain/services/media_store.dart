import '../../result/api_result.dart';

enum MediaSource { camera, gallery }

/// Picks photos and keeps a private copy in the app's media folder, so
/// saved references stay valid even if the original leaves the gallery.
///
/// Stored entities keep only the file **name**: the folder's absolute path
/// changes on iOS after an app update or restore, so it is resolved at
/// runtime with [resolve].
abstract interface class MediaStore {
  /// File name of the picked image, or `null` when the user cancelled.
  Future<ApiResult<String?>> pickImage(MediaSource source);

  /// File name of the picked video, or `null` when the user cancelled.
  Future<ApiResult<String?>> pickVideo(MediaSource source);

  /// Absolute path for displaying [fileName], or `null` when the file is
  /// missing.
  String? resolve(String fileName);

  /// Removes a stored file. Missing files are ignored.
  Future<VoidResult> delete(String fileName);

  /// Removes every stored file (used by "Delete local data").
  Future<VoidResult> clearAll();
}
