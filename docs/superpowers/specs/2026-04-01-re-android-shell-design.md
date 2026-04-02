# Re-Android Shell Design

## Context
- We are bootstrapping a completely self-contained Android-only app under `re-android/` without referencing any existing Flutter or root Android modules.
- Task 1 must deliver the Gradle parents, a Compose-based shell app, and a navigation definition that satisfies the failing `SeleneDestinationTest` first.

## Goals
1. Create a standalone Gradle project that compiles with Compose/Hilt/etc dependencies declared via `gradle/libs.versions.toml`.
2. Implement the navigation shell (`SeleneDestination`, `SeleneNavGraph`, `SeleneApp`, `MainActivity`) so the unit test can assert stable routes for every primary tab and confirm the benchmark route is hidden from the default bottom list.
3. Follow TDD: add the test first, confirm it fails, then implement the minimal shell.

## Constraints
- Keep the new `re-android` tree isolated; only the files listed in Task 1 are created.
- Navigation must be lightweight: `SeleneDestination` will expose each route via a sealed interface, and `SeleneNavGraph` will differentiate between bottom tabs and hidden destinations.
- `MainActivity`/`SeleneApp` should just host a Compose `Surface` and invoke the navigation graph.

## Architecture
- Dependencies: Compose (UI + Material3 + Navigation), Hilt (for future DI), Room/Retrofit/Media3/WorkManager (declared in `libs.versions.toml`) so the Gradle project can expand later without migrating later.
- `SeleneDestination`: sealed class with properties `route`, `label`, `icon?` and an indicator whether to include the destination in `bottomDestinations`. The benchmark destination will exist but set `showInBottomBar = false`.
- `SeleneNavGraph`: exposes `bottomDestinations` and `hiddenDestinations` lists derived from `SeleneDestination`. It also exposes a Compose `@Composable` function stub (e.g., `SeleneNavHost`) that will later connect to actual screens.
- `SeleneApp`: hosts the `SeleneNavGraph`, sets up `MaterialTheme`, and wires the root `Scaffold`. `MainActivity` simply calls `setContent { SeleneApp() }`.

## Testing
- `SeleneDestinationTest`: asserts each required route exists with a stable string, ensures `benchmark` is present but not included in the default bottom list. The test is the initial failing driver, and after implementation it must pass via `./gradlew :app:testDebugUnitTest --tests "org.moontechlab.selene.app.navigation.SeleneDestinationTest"`.

## Next Steps
- Once this design is approved, we will commit the spec file, dispatch the spec-document-reviewer (if available) with the same context, implement the file set, and then run the targeted unit test to confirm success.
