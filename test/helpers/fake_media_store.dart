import 'package:gainit/core/domain/services/media_store.dart';
import 'package:gainit/core/result/api_result.dart';

/// In-memory [MediaStore]: returns a scripted pick result, "stores" files
/// by name and records deletions.
class FakeMediaStore implements MediaStore {
  FakeMediaStore({
    this.pickResult = const ApiSuccess(null),
    this.clearAllResult = voidSuccess,
    Set<String>? files,
  }) : files = files ?? {};

  ApiResult<String?> pickResult;
  VoidResult clearAllResult;
  final Set<String> files;
  final deleted = <String>[];
  var clearAllCalls = 0;

  @override
  Future<ApiResult<String?>> pickImage(MediaSource source) async {
    if (pickResult case ApiSuccess(:final data?)) files.add(data);
    return pickResult;
  }

  @override
  Future<ApiResult<String?>> pickVideo(MediaSource source) async {
    if (pickResult case ApiSuccess(:final data?)) files.add(data);
    return pickResult;
  }

  @override
  String? resolve(String fileName) =>
      files.contains(fileName) ? '/media/$fileName' : null;

  @override
  Future<VoidResult> delete(String fileName) async {
    deleted.add(fileName);
    files.remove(fileName);
    return voidSuccess;
  }

  @override
  Future<VoidResult> clearAll() async {
    clearAllCalls++;
    return clearAllResult;
  }
}
