# CLAUDE.md

<!--
Golden Test: "Would removing this rule cause Claude to make mistakes?"
If not — cut it. Don't restate defaults Claude already knows.
-->

---

# Section A — General Engineering Rules

## 1) Architecture & Separation of Concerns (YOU MUST FOLLOW)
- Follow the project's architecture layer boundaries strictly: presentation → domain → data
- Never bypass layers or mix responsibilities
- UI/presentation layer has ZERO business logic — only rendering, interaction, and state observation
- Business logic lives in the domain layer
- Data access (APIs, databases, storage) lives in the data layer
- Do not introduce new abstractions or patterns without justification

## 2) Shared Code (IMPORTANT)
- Any reusable logic, utility, constant, extension, or helper used in 2+ places goes in `core/`
- Check `core/` before creating new shared code — never duplicate across features

## 3) Error Handling
- Errors flow cleanly across layers — never skip layers
- Handle null, empty, loading, and error states explicitly — no silent failures
- Catch errors at the boundary (data layer), not deep inside business logic

## 4) Change Discipline
- Make the smallest change that solves the problem
- Fix root causes, not symptoms
- Don't refactor unrelated code unless explicitly requested
- Never break existing functionality, APIs, flows, or UX unless explicitly instructed
- Read relevant code before modifying it — state assumptions when unclear

## 5) Dependencies
- Don't add new packages without justification
- Any new package must be: latest stable, well-maintained, production-grade

## 6) Security
- Never hardcode secrets, tokens, or credentials
- Never log sensitive information
- Validate all external and API input
- Proactively flag security risks when spotted

## 7) Testing
- Write tests for domain and data layer logic
- Bug fixes must include a reproducing test
- Tests must be deterministic — no flaky or timing-dependent tests
- One behavior per test case

## 8) Workflow (Mandatory)
- Before creating any new feature → invoke the `/flutter-feature` skill first for scaffolding and architecture reference
- Before marking any task done → run the `/flutter-code-review` skill
- After task approved → use the `@git-expert` agent for branch, commit, and PR output

## 9) Agents — Proactively Suggest (YOU MUST FOLLOW)
You MUST proactively suggest the appropriate agent when the situation matches. Do not wait for the user to ask.

- `@debugger` — When a bug, crash, error, or unexpected behavior is encountered
- `@code-reviewer` — After `/flutter-code-review` passes, ALWAYS suggest running `@code-reviewer` for a deeper independent review before proceeding to PR
- `@test-writer` — When code is changed or added without corresponding tests, or when test coverage is missing
- `@git-expert` — When it's time to create a branch, commit, or PR. Also for merge conflicts, rebases, or any complex git situation

---

# Section B — Flutter / Dart Specific Rules

<!--
Follow official Dart style guide, Effective Dart, and flutter_lints defaults.
Rules below only cover things that OVERRIDE defaults or encode project decisions.
-->

## 1) State Management
- Use **Cubit/Bloc** for feature and application state — not Riverpod, Provider, or GetX
- Cubits depend ONLY on use cases — never directly on repositories or data sources
- `setState` is allowed ONLY for local UI state (e.g., toggles, form focus) — never for business logic
- Keep `setState` scoped to the smallest widget possible to avoid redundant rebuilds up the tree

## 2) No Code Generation
- **No Freezed. No build_runner**, with one exception: `hive_ce_generator` for Hive adapters (see Section C). Use Dart 3+ native features instead:
  - `sealed class` for state unions with exhaustive pattern matching
  - `switch` expressions and records for lightweight data

## 3) Domain Layer Purity
- Domain layer must have ZERO Flutter imports
- No `package:flutter/...` in any file under `domain/`

## 4) Feature Folder Structure
- `features/{feature_name}/data/`
- `features/{feature_name}/domain/`
- `features/{feature_name}/presentation/`

## 5) Error Handling Contract
- Data layer: catch exceptions and map to typed `Failure` classes
- Domain layer: return `ApiResult<T>` from use cases and repositories
- Presentation layer: map failures to user-friendly messages and UI states

## 6) Dependency Injection
- Use **`get_it`** as the service locator
- Register dependencies in a single `core/di/` setup file
- Cubits, use cases, and repositories are resolved via `get_it`, not instantiated manually

## 7) Build Method Discipline (IMPORTANT)
- Prefer `const` constructors wherever possible
- NEVER create `TextEditingController`, `AnimationController`, `FocusNode`, or other expensive objects inside `build()`
- Avoid heavy work inside `build()` methods
- Dispose controllers and focus nodes in `StatefulWidget.dispose()`
- Prefer small, composed widgets to minimize rebuild scope
- Use `BlocBuilder`/`BlocSelector` on the smallest widget that needs the state — never at the top of the tree

---

# Section C — GainIt Project Specifics

Product spec: `specs/GainIt_Project_Plan.md` (the spec's Riverpod/Drift choices were replaced by Cubit/get_it/Hive CE — Sections A/B win).

## Commands
- `flutter analyze` · `flutter test` · `dart format lib test integration_test`
- `dart run build_runner build` — regenerate Hive adapters after changing any stored entity or enum (build_runner 2.15+ has no `--delete-conflicting-outputs`)
- `flutter test integration_test` — full MVP flow on a device/emulator

## Storage (Hive CE + hive_ce_generator)
- Adapters are generated from the `@GenerateAdapters` list in `lib/core/storage/adapters/hive_adapters.dart`. Domain entities carry no Hive annotations. Only append new `AdapterSpec`s at the end of the list.
- `hive_adapters.g.yaml` is the schema history (type IDs and field indices). Commit it along with the `.g.dart` files, and never hand-edit or delete it. CI fails if the generated files are stale.
- New fields on stored entities must be nullable or have a constructor default, so older records still load.
- Stored enums are written by index: only append values, never reorder or remove them.
- Adapters are registered with the generated `registerAdapters()` (inside `HiveStorage.open`).
- Hive has no constraints/transactions: validate with `core/domain/validation/validators.dart` before every write, and order multi-box writes children-first / parent-last (`StorageIntegrityCheck` removes orphans at startup).
- Real data transformations go in `StorageMigrator.steps` (bump `latestVersion`); never clear boxes to migrate.
- Settings-box keys only in `core/storage/settings_keys.dart`.

## Layering conventions used here
- Shared entities + pure training engines (progression, volume, schedule, session rules) live in `lib/core/domain/`; feature `domain/` holds repo contracts, feature entities and use cases.
- Repositories wrap every call in `guardStorage` / `guardStream` (`core/storage/storage_guard.dart`) — exceptions never reach use cases.
- Read-mostly screens extend `StreamViewCubit` / `FutureViewCubit` (`core/presentation/view_state.dart`) and render with `ViewStateBuilder`; one-off actions return `ActionOutcome`.
- Time comes from the injected `Clock` (tests use `test/helpers/fixed_clock.dart`); IDs from `IdGenerator`.
- Use cases whose output depends on today (dashboard, plan, weekly volume) wrap their stream with `rebuildOn(…, DayChangeSource.changes, build)` so they refresh at midnight and on app resume.
- Queries spanning many sessions take one `WorkoutLocalDataSource.snapshot()` (`WorkoutIndex`) — never call `setsOf`/`exercisesOf`/`performances` in a loop over sessions.
- Routes: paths only via `RoutePaths`; cubits provided at the route in `app/router/app_router.dart`.
- Widget tests that need storage use `HiveStorage.open(inMemory: true)` (file IO doesn't complete in fake-async).

## Localization (easy_localization, English + Arabic)
- Every user-facing text is a key in `assets/translations/{en,ar}.json`, used with `'key'.tr()` / `.plural(n)` in presentation. Add each key to both files (`test/core/l10n/translations_test.dart` checks keys, placeholders and plural forms).
- Domain and data code never produce display text: validators, failures and exceptions carry message keys (`validation.*`, `errors.*`), translated by `Failure.userMessage` / `translateMessage` with `Validators.messageArgs`.
- Built-in program, day and exercise names are stored in English; show them with `seedName(name)` (`core/l10n/seed_names.dart`). Enum names come from `core/l10n/enum_labels.dart`.
- Numbers use Western digits in both languages; dates follow the app language (`Formatters`).
- Layout must work right to left: use `EdgeInsetsDirectional` / `AlignmentDirectional` for anything one-sided.
- The language lives in the settings box (`SettingsKeys.languageCode`, `null` = phone language). Tests load English texts globally (`test/flutter_test_config.dart`); full-app tests wrap the app with `pumpLocalizedApp`.

## Motion, navigation bar, icon and splash
- Shared animations live in `core/widgets/motion.dart` (`entrance`, `pop`, `bump`, `EntranceGroup`). They use implicit animations (tickers), never timers or `flutter_animate`, so widget tests never leave timers pending. Every one respects `MediaQuery.disableAnimations` without changing the widget tree, so toggling the setting never resets state.
- Page transitions come from the theme (`animations` package: shared-axis scaled on Android, Cupertino on iOS); tabs fade through in `FadingBranchContainer`. Don't add per-route transitions.
- The bottom bar floats over the pages (`extendBody`). Scrolling content must pad its end by `MediaQuery.paddingOf(context).bottom`. `PageBody` already does, and shell pages use `SafeArea(bottom: false)`. Bottom sheets open with `useRootNavigator: true` so they cover the bar. A list above a bottom button that has its own `SafeArea` removes the bottom padding (`MediaQuery.removePadding`). In widget tests, `ensureVisible` an item before tapping it near the bottom.
- The icon and native splash are generated from `assets/icon/` (a placeholder drawn by a script): `dart run flutter_launcher_icons`, then `dart run flutter_native_splash:create`. They generate platform files, not Dart code. After running them, revert `ios/Runner.xcodeproj/project.pbxproj`, because flutter_launcher_icons rewrites an unrelated build setting there.
