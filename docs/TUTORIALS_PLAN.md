# Tutorials IA and Structure Plan

## Goals
- Provide platform-specific, end-to-end learning paths without mixing into reference docs.
- Reduce onboarding friction by separating "how to build" from "how it works."
- Keep a consistent structure across platforms so users can compare and adapt quickly.

## Scope
- Platforms: Web/WASM, iOS, Android, macOS, Linux, Windows.
- Each tutorial is self-contained and links to reference docs for deep dives.

## Entry Points (IA)
- Primary nav: add top-level "Tutorials" link (`/tutorials/`).
- Docs landing: add a "Tutorials" card in `site/content/docs/_index.*`.
- Getting Started: add "Platform Tutorials" link near the prerequisites section.
- Platform guides: add "Start the tutorial" CTA at top of each platform page.

## Tutorial Template (applies to every platform)
1. Overview (what you will build, expected time, prerequisites)
2. Environment setup (tools, SDKs, platform-specific requirements)
3. Project bootstrap (clone or scaffold, minimal config)
4. Hello Counter UI (first render, state read)
5. Events and state updates (dispatch, observe, UI update)
6. Build and run (device/emulator, debug/release)
7. Troubleshooting (top 5 errors and fixes)
8. Next steps (links to core concepts, API reference, samples)

## Page Structure (site content)
- /tutorials/
  - _index.md (overview, choose platform, CTA to docs)
  - web.md
  - ios.md
  - android.md
  - macos.md
  - linux.md
  - windows.md

## Consistency Rules
- Same section order and headings across platforms.
- Use the same example app (counter) for parity.
- One code snippet per step to reduce cognitive load.
- Always include a "What changed in state?" callout after events.

## Cross-Links
- Core Concepts: state, events, diff, ABI.
- API Reference: state/events modules.
- Samples: link to the equivalent sample project.

## Ownership
- Source of truth for tutorial steps: platform-specific docs in `site/content/tutorials/`.
- Code examples: keep in `samples/` or `examples/` and embed in tutorials.
