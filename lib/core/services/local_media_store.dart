import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/services/media_store.dart';
import '../result/api_result.dart';
import '../result/failures.dart';
import 'id_generator.dart';

/// [MediaStore] backed by `image_picker`, keeping copies in [directory]
/// (`<app documents>/media`, resolved once at startup).
class LocalMediaStore implements MediaStore {
  LocalMediaStore(
    this._ids, {
    required this.directory,
    this.pickerCacheDirectory,
    ImagePicker? picker,
  }) : _picker = picker ?? ImagePicker();

  final IdGenerator _ids;
  final ImagePicker _picker;

  /// Absolute path of the media folder.
  final String directory;

  /// Where the picker leaves its temporary copies; they are removed after
  /// being kept so no stray personal photos remain.
  final String? pickerCacheDirectory;

  static const _maxImageSide = 1024.0;
  static const _imageQuality = 85;

  @override
  Future<ApiResult<String?>> pickImage(MediaSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: switch (source) {
          MediaSource.camera => ImageSource.camera,
          MediaSource.gallery => ImageSource.gallery,
        },
        maxWidth: _maxImageSide,
        maxHeight: _maxImageSide,
        imageQuality: _imageQuality,
      );
      if (picked == null) return const ApiSuccess(null);
      return ApiSuccess(await _keep(picked));
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('LocalMediaStore.pickImage: $error');
      return const ApiFailure(
        UnexpectedFailure(
          'Could not open the camera or gallery. Check app permissions.',
        ),
      );
    } on FileSystemException catch (error) {
      if (kDebugMode) debugPrint('LocalMediaStore.pickImage: $error');
      return const ApiFailure(StorageFailure('Could not save the photo.'));
    }
  }

  @override
  String? resolve(String fileName) {
    final file = File(_pathOf(fileName));
    return file.existsSync() ? file.path : null;
  }

  @override
  Future<VoidResult> delete(String fileName) async {
    try {
      final file = File(_pathOf(fileName));
      if (await file.exists()) await file.delete();
      return voidSuccess;
    } on FileSystemException catch (error) {
      if (kDebugMode) debugPrint('LocalMediaStore.delete: $error');
      return const ApiFailure(StorageFailure('Could not remove the file.'));
    }
  }

  @override
  Future<VoidResult> clearAll() async {
    try {
      final folder = Directory(directory);
      if (await folder.exists()) await folder.delete(recursive: true);
      return voidSuccess;
    } on FileSystemException catch (error) {
      if (kDebugMode) debugPrint('LocalMediaStore.clearAll: $error');
      return const ApiFailure(StorageFailure('Could not remove saved media.'));
    }
  }

  /// Only the last path segment is used, so a stored value can never point
  /// outside the media folder.
  String _pathOf(String fileName) {
    final name = fileName.split(RegExp(r'[/\\]')).last;
    return '$directory${Platform.pathSeparator}$name';
  }

  Future<String> _keep(XFile picked) async {
    await Directory(directory).create(recursive: true);
    final original = picked.name;
    final dot = original.lastIndexOf('.');
    final name = '${_ids.next()}${dot == -1 ? '' : original.substring(dot)}';
    await picked.saveTo(_pathOf(name));
    await _removePickerCopy(picked.path);
    return name;
  }

  Future<void> _removePickerCopy(String path) async {
    final cache = pickerCacheDirectory;
    // Only ever delete the picker's own temporary copy, never an original.
    if (cache == null || !path.startsWith(cache)) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Best effort: the OS clears its cache eventually.
    }
  }
}
