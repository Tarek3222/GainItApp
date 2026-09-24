import 'package:uuid/uuid.dart';

/// Generates record IDs (UUID v4 — sync-ready, no central sequence needed).
class IdGenerator {
  const IdGenerator();

  static const _uuid = Uuid();

  String next() => _uuid.v4();
}
