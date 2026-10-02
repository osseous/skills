# Using DESIGN.md for a game

Read when creating/updating a persistent design-system document or integrating an existing DESIGN.md.

Google's [DESIGN.md repository](https://github.com/google-labs-code/design.md) and [format specification](https://github.com/google-labs-code/design.md/blob/main/docs/spec.md) describe tokens paired with rationale. That documentation approach can describe UI rendered by a game engine as well as HTML/CSS. Its example palettes, shapes, and web units are not this game's design.

## When it helps

Use it for a new shared design system, repeated screen work, or handoff between agents/tools when a persistent contract will prevent drift. A small component fix in a documented library does not require a new DESIGN.md or a Stitch integration.

Find the existing source of truth first. Update that document or add a linked compatible summary; avoid a second token system that disagrees with code. Keep exact values synchronized with canonical project tokens and explain any pending implementation difference.

## What to record

Use the current Google specification if tooling compatibility is required; verify it rather than copying an old Stitch template.

- **Overview:** game identity, genre, relevant screen contexts, references and explicit user constraints.
- **Colors:** semantic roles, exact values and alpha where known, palette/state meanings and context-specific surface variants.
- **Typography:** packaged fonts/weights, readable roles, numbers/units and scale/localization behavior.
- **Layout:** screen and world anchors, content insets versus safe area, glance/sightline regions, aspect-ratio and local-player adaptation.
- **Elevation/depth and shapes:** purposeful layers, opacity, border/outline/shadow treatments and their reasons.
- **Components:** named variants and states, contract/source/Paper links and shared interaction behavior.
- **Do/don't rules:** this game's evidence-backed constraints and rejected treatments.

Add game-specific prose for input ownership, projected visibility, scene contrast checks and runtime acceptance. Do not invent machine-readable schema fields and claim a Google tool supports them.

Google's tokens can use CSS-like values. For a native renderer, document how those measurements map to the host's actual layout units, UI scale, color space and font metrics; do not equate CSS pixels with final game pixels.

## Validation and boundaries

If using Google's parser/exporter, validate against the current specification and the tools already available. Never claim a generic design-token or contrast check validates projected placement, contrast over changing game scenes, focus navigation, renderer effects or packaged fonts.

The document is optional documentation, not a prerequisite to design, a mandatory engine dependency, or a reason to import Material Design, web gutters, rounded cards, or Stitch's example styling. Keep game rules and component contracts authoritative.
