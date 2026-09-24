# GainIt

A local-first hypertrophy tracker built with Flutter. Follow a weekly program, log every working set, and get a progression target for next time. No account, and everything works offline.

## Features (Release 0.1)

- **Onboarding.** Name, height, weight, goal and start date. No login.
- **Home dashboard.** Shows the next workout, body-weight trend, this week's workouts and sets, and your latest progress.
- **Weekly plan.** The seeded 4-day hypertrophy split, with each day marked done, today, upcoming, missed or rest.
- **Active workout.** Each exercise shows its target, last result, rep range and RIR. Large ± steppers. **Every completed set is saved immediately.**
- **Double progression.** When every working set reaches the top of the rep range, the next target adds weight. After three sessions without progress, it suggests a ~10% deload.
- **Rest timer.** Pause, skip, ±15 s and optional auto-start. It keeps correct time in the background and alerts with a notification.
- **Resume after interruption.** Reopening the app offers "Resume workout? · 8 of 19 sets completed".
- **Workout summary.** Duration, volume per muscle, and progress against last time.
- **History.** Filter by muscle, exercise or date range, and open any session's details.
- **Exercise progress.** Best weight, best reps, estimated 1RM, and trend charts.
- **Body weight.** Log entries and see a chart with a 7-day rolling average.
- **Settings.** Timer, sound and vibration options, workout reminders, profile editing, and deleting all local data.

## Tech

| Concern | Choice |
|---|---|
| State | `flutter_bloc` (Cubit), sealed states |
| DI | `get_it` (`lib/core/di/injection.dart`) |
| Routing | `go_router` (`lib/app/router/`) |
| Storage | `hive_ce` + `hive_ce_generator` (adapters generated; schema tracked in `hive_adapters.g.yaml`) |
| Charts | `fl_chart` |
| Notifications | `flutter_local_notifications` + `timezone` |
| Tests | `flutter_test`, `bloc_test`, `mocktail`, `integration_test` |

## Architecture

```
lib/
  app/        theme tokens, router, app shell
  core/       domain entities + pure training engines, storage, DI, shared widgets
  features/   startup · onboarding · home · program · workout · history
              progress · body_weight · settings
              each feature has data/ → domain/ → presentation/
```

A request always flows `Widget → Cubit → UseCase → Repository → local data source → Hive`. The progression, volume, schedule and session engines are pure Dart and fully unit-tested.

## Commands

```bash
flutter pub get
dart run build_runner build     # regenerate Hive adapters after entity changes
flutter run                      # Android / iOS
flutter analyze
flutter test                     # unit, storage, cubit, widget and full-app flow tests
flutter test integration_test    # full MVP flow on a device or emulator
```
