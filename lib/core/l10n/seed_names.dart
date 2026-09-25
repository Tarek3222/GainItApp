import 'package:easy_localization/easy_localization.dart';

/// The built-in program, its days and exercises are stored with English
/// names, and workout history keeps those names. They are shown in the
/// current language by looking up the English name; names the user typed
/// have no entry and are shown as written.
String seedName(String name) {
  final key = 'seedNames.$name';
  // Keys are split on dots, so a name with one can't be a built-in name.
  if (name.contains('.') || !key.trExists()) return name;
  return key.tr();
}
