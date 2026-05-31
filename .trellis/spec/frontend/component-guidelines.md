# Component Guidelines

> Flutter components should be typed, callback-driven, responsive, and consistent with existing Material-style UI.

## Overview

Components are regular Flutter `StatelessWidget` or `StatefulWidget` classes. Most reusable UI lives in `lib/widgets/`; TV-specific components live in `lib/tv_app/widgets/`. Components receive data and callbacks through constructors and delegate business logic to services or parent screens.

## Component Structure

Use the existing structure:

- Imports first, with package imports before relative imports when practical.
- Public enum/type definitions near the top when tightly coupled to the widget, as in `VideoFitType` and `ProgressDisplayMode`.
- Widget class with `final` fields.
- `const` constructor when fields allow it.
- `build` method before private helper builders.
- Private helper methods prefixed with `_build...` for repeated sections.

Example: `lib/widgets/player_settings_panel.dart` defines typed enums, immutable constructor fields, a `build` method, then helper builders for selectors and sliders.

## Props Conventions

- Use `required` for values the widget cannot render without.
- Prefer strongly typed callbacks: `ValueChanged<T>`, `VoidCallback`, or `Function(T)` matching local style.
- Keep nullable props only for optional behavior or visual overrides.
- Pass `ThemeData` when the component is designed to render inside overlays detached from the main theme context.
- Avoid passing raw maps into widgets; use models from `lib/models/`.

## Styling Patterns

- Use `ThemeData` and `Brightness` to branch dark/light colors when a component already follows that pattern.
- Prefer Material widgets (`Container`, `IconButton`, `SliderTheme`, `Switch`, `Text`) over custom drawing unless the existing component requires custom rendering.
- Use `const SizedBox`, `const EdgeInsets`, and `const BorderRadius` for fixed layout values.
- Keep text sizes stable; do not scale fonts directly with viewport width.
- For player overlays and panels, preserve current compact dimensions and opacity behavior unless the task is specifically redesigning them.

## Accessibility and Interaction

- Buttons and controls must have clear hit targets and callbacks.
- TV components must support focus states, remote confirm, directional navigation, and scroll-into-view through `TvFocusable` where applicable.
- Do not break mouse/touch interactions while adding remote-control behavior.
- Keep overlays dismissible through the current navigation or close-button pattern.

## Common Mistakes

- Putting async service calls into reusable components that should only render and emit callbacks.
- Rebuilding a large player subtree for small preference changes without isolating state.
- Adding TV remote behavior to normal widgets instead of using a TV-specific wrapper.
- Adding visible helper text that explains how to use common controls instead of making controls self-evident.
