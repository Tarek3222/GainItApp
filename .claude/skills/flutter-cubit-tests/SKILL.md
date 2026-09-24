---
name: flutter-cubit-tests
description: Use this skill when the user asks to write, generate, or add unit tests for a Cubit in this Flutter Clean Architecture codebase. Triggers include "write tests for X cubit", "add unit tests for the Y feature", "test the login cubit", "cover this cubit with tests". Do not use for widget tests (UI rendering tests) — use the flutter-widget-tests skill for those instead.
---

# Flutter Cubit Unit Tests (bloc_test + mocktail)

## When to use this
Trigger for **Cubit-level logic tests** — testing state emissions in response to use case results. Not for widget/UI tests (see the widget-tests skill for that).

## Required inputs before generating
1. The target Cubit's source file (states + cubit class).
2. The use case(s) it depends on (at minimum, the `call()` method signatures).
3. A reference test file from this repo if one exists, to match existing mock/assertion style. If AGENTS.md is present, its testing conventions take precedence over anything below.

## Conventions
- Use `bloc_test` for state emission testing.
- Use `mocktail` for mocks — never `mockito`.
- Structure: arrange in `setUp`, act via `blocTest`'s `build`/`act`, assert via `expect` on emitted states.
- Test descriptions follow given/when/then phrasing:
  `"emits [Loading, Success] when usecase returns Right(data)"`
- Register fallback values in `setUpAll` if a use case takes a complex parameter object.
- Group related tests with `group()`.
- Minimum coverage per Cubit: initial state, loading→success path, loading→error path, plus any cubit-specific edge case (empty result, validation failure, etc.)

## Output format
1. Full imports
2. Mock class declarations (`extends Mock implements X`)
3. `setUpAll` for fallback registration (if needed)
4. `setUp` with mock + cubit instantiation
5. Full test file, grouped by scenario

## Constraints
- Test only observable state emissions — never internal implementation details
- Don't write tests for scenarios the use case's return type can't actually produce
- Keep mock stubs minimal — only stub what that specific test exercises
