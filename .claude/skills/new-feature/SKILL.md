---
name: new-feature
description: Create a new Flutter feature end-to-end by first discovering and following the existing project's architecture, conventions, state management, networking, dependency injection, routing, persistence, UI, and testing patterns. Use when adding a new screen, flow, module, feature, Cubit/Bloc, repository, use case, or API integration.
allowed-tools: Read Grep Glob Write Edit Bash
---

# New Feature — General Flutter Project Skill

Create a production-ready Flutter feature under the project's existing architecture.

The goal of this skill is **not** to impose a specific architecture or package.
The goal is to inspect the project first, identify its established conventions, and
implement the new feature consistently with them.

## 0. Core Rule — Inspect Before You Implement

Before creating or editing files:

1. Inspect the project structure.
2. Read `pubspec.yaml`.
3. Identify:
   - State management approach (`Cubit`, `Bloc`, `Provider`, `Riverpod`, etc.).
   - Architecture (`feature-first`, `layer-first`, Clean Architecture, MVVM, MVC, etc.).
   - Networking approach (`Dio`, `http`, Retrofit, generated clients, etc.).
   - Dependency injection (`get_it`, Riverpod providers, manual DI, etc.).
   - Routing (`go_router`, `auto_route`, Navigator 1.0/2.0, manual routes, etc.).
   - Local persistence (`Hive`, `Hive CE`, SharedPreferences, Isar, SQLite, secure storage, etc.).
   - Model generation (`json_serializable`, Freezed, built_value, manual models, etc.).
   - Error handling conventions.
   - UI/design-system conventions.
   - Existing testing strategy.
4. Find the closest existing feature(s).
5. Read the relevant files from those features.
6. Mirror the existing pattern.

**Never introduce a new architectural pattern or dependency merely because it is
personally preferred.**

If the repository has inconsistent patterns, prefer the newest/most complete
pattern and explain the choice before implementation.

---

# 1. Understand the Feature

Before coding, identify:

- Feature name.
- User flow.
- Screens involved.
- User actions.
- API requirements.
- Request/response models.
- Business rules.
- Loading/success/error/empty states.
- Authentication requirements.
- Local persistence requirements.
- Navigation requirements.
- Dependencies on existing features.

If requirements are incomplete, inspect the repository and existing APIs first.
Do not invent backend contracts when the project already contains an API definition.

Create a short implementation plan before modifying files.

---

# 2. Decide the Architecture From the Repository

Determine whether the project uses:

- Simple feature architecture.
- Clean Architecture.
- MVVM.
- Repository pattern.
- Use cases.
- Service-driven architecture.
- Another established pattern.

Then follow it.

### Business Logic Rule

If the feature is a thin API/UI flow, do not add unnecessary abstraction.

If meaningful business rules exist, use the project's established separation
between presentation, domain/business logic, and data.

Examples of business logic that may justify a domain/use-case layer:

- Multiple repository calls must be coordinated.
- Complex validation or transformations.
- Reusable business operations.
- Non-trivial calculations.
- Business decisions independent of Flutter UI.

Do not add `domain/`, repositories, use cases, or extra layers simply for ceremony
if the project does not use them.

---

# 3. Feature Structure

Create files according to the project's existing structure.

A common feature-first structure may look like:

```text
lib/
  features/
    <feature>/
      data/
        models/
        datasources/
        repositories/
      domain/
        entities/
        repositories/
        usecases/
      presentation/
        cubits/
        blocs/
        views/
        widgets/
```

But this is only an example.

**The repository's actual structure is authoritative.**

---

# 4. Data Layer

Follow the existing networking and data conventions.

## Models

When models are needed:

- Use the project's existing serialization approach.
- Match naming conventions.
- Match nullability conventions.
- Match JSON field mapping.
- Reuse shared response/error models when available.
- Do not duplicate an existing model.

If code generation is used:

- Add the correct annotations.
- Add generated `part` files where required.
- Run the project's generator after implementation.

## API / Data Source

When an endpoint is required:

1. Search for an existing equivalent endpoint/model first.
2. Add the endpoint to the existing API client/service when that is the project convention.
3. Add constants to the project's existing constants file when applicable.
4. Match HTTP method, headers, authentication, query parameters, path parameters,
   request body, and response parsing to existing conventions.
5. Do not create a second networking service unless the architecture explicitly requires it.

## Repository

If the project uses repositories:

- Keep API/data access inside the repository/data layer.
- Return the project's established result/error type.
- Follow the project's exception/error handling convention.
- Do not leak raw networking exceptions into presentation unless that is already the project's pattern.

If the project does not use repositories, do not introduce them unnecessarily.

---

# 5. Business / Domain Layer

Only create domain entities, repositories, and use cases when the project's
architecture or the feature's business complexity requires them.

If use cases exist:

- One use case should represent one meaningful business operation.
- Keep Flutter/UI dependencies out of the domain layer.
- The presentation layer should depend on the appropriate abstraction used by the project.
- Keep business rules testable independently of widgets.

Do not create a use case that only forwards one method unless that is an established
project convention.

---

# 6. State Management

Use the project's existing state-management solution.

Examples:

- `Cubit`
- `Bloc`
- `Riverpod`
- `Provider`
- `ChangeNotifier`
- another established approach

## If the project uses Cubit/Bloc

Follow the project's state conventions exactly.

Check:

- Base state type.
- Equatable usage.
- Sealed states.
- Loading states.
- Success states.
- Error states.
- Pagination states.
- Form states.
- Event naming if using Bloc.
- Existing status/listener abstractions.

Do not create a custom state architecture if one already exists.

## General State Rules

Every asynchronous flow should explicitly handle the states relevant to it:

```text
Initial
Loading
Success
Error
Empty
```

Only add states that are meaningful for the feature.

Avoid:

- Boolean state explosions.
- Multiple independent loading booleans when one structured state is clearer.
- Putting business logic inside widgets.
- Calling APIs directly from UI widgets when the project separates state/data logic.

---

# 7. UI Layer

Follow the project's design system.

Before creating UI:

- Search for reusable widgets.
- Search for existing buttons, text fields, dialogs, cards, loaders, app bars, etc.
- Reuse theme colors.
- Reuse typography.
- Reuse spacing/dimensions.
- Reuse localization.
- Reuse responsive utilities.

Do not hardcode values when the project already has design tokens.

Prefer:

- Small composable widgets.
- `const` constructors where possible.
- Clear widget responsibilities.
- Responsive layouts.
- Accessible interactions.
- Proper keyboard/focus handling.
- Proper controller disposal.

Never create controllers, focus nodes, animation controllers, or other disposable
objects inside `build()`.

---

# 8. Loading / Error / Empty / Success UX

For every API-driven screen, explicitly consider:

### Loading
- Initial page loading.
- Button/action loading.
- Refresh loading.
- Pagination loading if applicable.

### Error
- Network error.
- Server/API error.
- Validation error.
- Unauthorized/session-expired behavior if relevant.

### Empty
- Empty list.
- No search results.
- No available data.

### Success
- Update UI correctly.
- Show feedback only when appropriate.
- Navigate only when the flow requires it.

Reuse the project's existing status listeners, dialogs, snackbars, or result
components instead of creating duplicates.

---

# 9. Routing

Follow the project's routing solution.

When the feature introduces a screen:

1. Find the existing routing pattern.
2. Add the route using the project's naming convention.
3. Pass parameters using the established mechanism.
4. Inject state management at the appropriate layer.
5. Do not bury route-level dependency creation inside the screen unless the project does that.

Verify:

- Direct navigation.
- Back navigation.
- Required parameters.
- Deep-link behavior if the project supports it.
- Authentication guards if applicable.

---

# 10. Dependency Injection

Follow the project's existing DI mechanism.

Possible approaches include:

- `get_it`
- Riverpod providers
- Injectable
- Manual constructor injection
- Another project-specific solution.

Register only dependencies that actually require registration.

Do not register presentation objects globally if the existing architecture creates
them at route/screen scope.

Follow the existing lifecycle:

```text
Singleton
Lazy Singleton
Factory
Route/Screen scoped
```

Do not change dependency lifetimes without a reason.

---

# 11. Local Storage / Persistence

If the feature needs persistence:

1. Inspect the project's existing storage solution.
2. Reuse it.
3. Search for existing keys/models/adapters.
4. Follow existing serialization and migration patterns.

Examples:

- Hive / Hive CE
- SharedPreferences
- Secure Storage
- Isar
- SQLite
- Drift

Never inline storage keys if the project centralizes them.

Never create a second persistence solution for a feature without a strong architectural reason.

---

# 12. Authentication and Authorization

Before implementing protected API calls:

- Inspect how authentication tokens are stored.
- Inspect how authenticated requests are configured.
- Inspect unauthorized/expired-token handling.
- Reuse existing interceptors/middleware.
- Reuse existing auth state.

Do not manually attach tokens in every repository if the project already handles this centrally.

For role-specific features, verify authorization at the appropriate backend/UI layers
without assuming that hiding a button is sufficient security.

---

# 13. Forms and Validation

If the feature contains a form:

- Follow the project's existing form architecture.
- Reuse validators where available.
- Keep validation rules consistent.
- Handle keyboard/focus correctly.
- Prevent duplicate submissions.
- Disable or show loading on submit when appropriate.
- Preserve user input when recoverable from an error.

Do not put complex validation/business rules directly inside widget `build()` methods.

---

# 14. Pagination / Search / Filtering

If the feature contains lists:

Determine whether it needs:

- Pagination.
- Infinite scroll.
- Pull-to-refresh.
- Search.
- Debouncing.
- Filtering.
- Sorting.
- Local caching.

Inspect existing list features before implementing.

For pagination, explicitly handle:

```text
Initial load
Loading next page
Next page success
Next page error
No more data
Refresh
Retry
```

Avoid duplicate requests caused by repeated scroll callbacks or rebuilds.

---

# 15. Performance and Lifecycle

Before marking the feature complete, check:

- No unnecessary rebuilds.
- No duplicate API calls.
- Controllers are disposed correctly.
- Streams/subscriptions are cancelled where required.
- Large lists use appropriate builders.
- Images use the project's image/caching approach.
- Expensive work is not performed inside `build()`.
- Async operations do not update disposed widgets/state objects.
- Pagination/search does not trigger uncontrolled requests.

---

# 16. Testing

Follow the project's existing testing stack.

If tests exist, add tests at the appropriate levels.

Possible tests:

### Presentation
- Initial state.
- Loading state.
- Success state.
- Error state.
- Empty state.
- User action/state transition.
- Navigation branch when applicable.

### Repository / Data
- Successful response mapping.
- API error mapping.
- Exception handling.
- Request parameters/body when the project tests them.

### Domain
- Business rules.
- Validation.
- Use-case behavior.

### Widget
Only add widget tests when they provide meaningful coverage or the project already
uses them for similar screens.

Do not mock everything unnecessarily.

---

# 17. Code Generation

If the project uses code generation:

- Identify the generators from `pubspec.yaml`.
- Run the project's standard generator command.
- Resolve generated-code errors.
- Do not manually edit generated files unless the project explicitly requires it.

Common examples:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Only run commands that match the project's tooling.

---

# 18. Verification

Before marking the feature complete, run the project's relevant checks.

At minimum, when available:

```bash
flutter analyze
flutter test
```

Also run:

- Formatter.
- Code generation.
- Build checks.
- Linter.
- Integration tests.

Only use commands supported by the repository.

Fix errors instead of merely reporting them.

---

# 19. Final Review

Before completion, inspect the diff and verify:

- No duplicated existing code.
- No unnecessary dependencies.
- No unused imports.
- No dead code.
- No debug prints/logging left accidentally.
- No hardcoded secrets.
- No hardcoded API URLs if the project uses configuration.
- No architecture violations.
- No missing localization.
- No missing route.
- No missing DI registration.
- No missing generated files.
- No missing tests where appropriate.

Then compare the new feature with the closest existing feature again.

The final implementation should feel like it was written by the existing project
team, not added from an unrelated template.

---

# 20. Handoff

After implementation:

1. Summarize what was created.
2. List the important files changed.
3. Mention any architectural decision and why it follows the repository.
4. Report verification commands and their results.
5. Mention any remaining backend/API dependency.
6. If the project has additional skills such as code review, run them according
   to the project's workflow before declaring the feature complete.

---

# Non-Negotiable Rules

1. **Inspect first, implement second.**
2. **Existing project conventions beat generic best practices.**
3. **Do not introduce architecture/package/dependency without justification.**
4. **Search for reusable code before creating new code.**
5. **Keep business logic out of UI widgets.**
6. **Handle loading, success, error, and empty states intentionally.**
7. **Do not invent API contracts when the repository already defines them.**
8. **Do not expose secrets or hardcode credentials.**
9. **Do not mark the feature complete while analyzer/tests are failing.**
10. **Keep the implementation production-oriented, not a demo scaffold.**
