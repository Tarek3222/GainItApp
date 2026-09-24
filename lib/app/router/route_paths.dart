/// Route map (spec §31). Build paths with these helpers — never inline.
abstract final class RoutePaths {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const plan = '/plan';
  static const progress = '/progress';
  static const settings = '/settings';
  static const history = '/history';
  static const bodyWeight = '/body-weight';

  static String planDay(String dayId) => '/plan/day/$dayId';
  static String workout(String sessionId) => '/workout/$sessionId';
  static String workoutSummary(String sessionId) =>
      '/workout/$sessionId/summary';
  static String historySession(String sessionId) => '/history/$sessionId';
  static String exercise(String exerciseId) => '/exercises/$exerciseId';
}
