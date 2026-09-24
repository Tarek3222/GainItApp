---
name: flutter-widget-tests
description: Use this skill when the user asks to write, generate, or add widget tests for a screen or widget that consumes a Cubit in this Flutter Clean Architecture codebase. Triggers include "write widget tests for X screen", "test the UI for Y", "add widget tests for the home page", "test this widget's states". Do not use for pure Cubit logic tests (no widget/UI involved) — use the flutter-cubit-tests skill for those instead.
---

# Flutter Widget Tests (MockCubit + flutter_test)

## When to use this
Trigger for tests that verify **UI rendering and interaction** in response to Cubit states — not for testing the Cubit's internal logic.

## Required inputs before generating
1. The widget/screen source file, including its `BlocBuilder`/`BlocConsumer` usage.
2. The Cubit + State classes it consumes.
3. A reference widget test file from this repo if one exists. If AGENTS.md is present, its testing conventions take precedence over anything below.

## Conventions
- Create a `MockCubit` (`extends Mock implements Cubit<State>`) via mocktail.
- Stub the Cubit's stream + initial state with `whenListen()` from bloc_test.
- Wrap the widget under test in `MaterialApp` + `BlocProvider.value(value: mockCubit, child: ...)`.
- Do not use GetIt in widget tests — inject mocks directly via BlocProvider, bypassing DI entirely.
- Use `find.byKey` over `find.text` when text may be dynamic or repeated; use `find.byType` for widget structure checks.
- Use `pumpWidget` then `pump()`/`pumpAndSettle()` depending on whether animations/async are involved.
- Verify Cubit method calls via `verify(() => mockCubit.methodName()).called(1)`.
- Minimum coverage: loading state shows loading indicator, success state renders data correctly, error state shows error UI, and any user interaction (tap/scroll) that should trigger a Cubit method call.
- If the widget uses lazy list/tab rendering, include a test verifying only the initially visible items are built (not the entire list).

## Output format
1. Full imports
2. `MockCubit` class declaration
3. Test-helper widget wrapper function, if the reference file uses one
4. `setUp` with mock instantiation
5. Full test file grouped by scenario (`group()` per state/interaction)

## Constraints
- Don't test the Cubit's internal logic — only widget rendering and interaction
- Don't over-mock — only stub `cubit.state` and `cubit.stream`, not unrelated dependencies
