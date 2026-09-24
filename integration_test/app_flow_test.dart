import 'package:integration_test/integration_test.dart';

import '../test/app/app_flow_smoke_test.dart' as app_flow;

/// Runs the full MVP flow (spec §27) on a real device or emulator:
/// `flutter test integration_test`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  app_flow.main();
}
