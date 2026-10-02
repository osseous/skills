# Research and game layout

Use this reference when choosing a new direction or composing a substantial screen. The examples demonstrate different decisions, not one universal game aesthetic.

## Research protocol

Search by genre plus screen/function: racing telemetry, strategy resource bar, controller settings, inventory comparison, projected interaction prompt. Include games with similar camera, pace, information load, and input context. Search both galleries before choosing a new direction; use official captures when gallery coverage is weak.

For a new direction, usually inspect 3–5 useful screenshots across at least two games, including a contrasting treatment. A focused revision can use fewer images covering the affected component and state. Complete any larger research count explicitly requested by the user; count only inspected images.

Evaluate the game-image rectangle, excluding gallery margins and controls. Record:

| Field | Required evidence |
|---|---|
| Source | Detail URL, game, screen/state, platform if known |
| Observation | Visible grouping, edge relationship, hierarchy, typography, palette, opacity, border/shadow and state cues |
| Interpretation | Player need this could serve; mark inference explicitly |
| Transfer | Adopt/adapt/reject, affected component, reason, and what this game's context changes |
| Unknowns | Focus movement, hit areas, timing and input behavior a still image cannot prove |

Measure geometry relative to the reference image dimensions. Label sampled colors or estimated opacity as estimates; a composited screenshot cannot reliably recover the original alpha or shader. Use project assets/tokens for production precision.

## How the pipelines differ

These are tendencies, not claims that every website or game follows one layout.

| Decision | Common web starting point | Game UI starting point |
|---|---|---|
| Canvas | Document flow, page sections, scrolling content | A viewport containing a changing world plus screen or world overlays |
| Attention | The interface is usually the main reading/task area | UI competes with play, aiming, navigation and scene visibility; menus change that balance |
| Placement | Content containers, gutters, responsive page grids | Screen/corner anchors, safe areas, focal sightlines and intentional docked regions |
| Density | Group tasks into sections and content containers | Choose density by pace: glanceable action HUD, richer strategy control panel, deliberate inventory comparison |
| Input | Pointer/touch and keyboard document navigation | Game/UI ownership, directional focus, device glyphs, rebinding and return-to-play behavior |
| Readability | Evaluate against designed surfaces | Check the lowest-contrast moving scene behind text, camera motion and actual viewing distance |
| Components | Shared controls and states | Also share readouts, selection/target cues, action prompts, spatial labels and contextual visibility rules |
| Adaptation | Reflow across browser widths | Preserve gameplay anchors at supported aspect ratios, UI scale, safe zones and local-player viewports |
| Validation | Browser appearance and task flows | Final game composition, scene occlusion, input transitions, state changes and packaged/runtime rendering |

Retain useful web disciplines such as tokens, component reuse and responsive constraints. Translate their layout assumptions to the game rather than copying a page template. An HTML/CSS renderer remains a valid game implementation.

## Screen-specific decisions

- **Action/racing HUD:** reserve aiming/forward sightlines; prioritize immediate values and signals; move secondary detail into contextual states.
- **Strategy/MOBA/management HUD:** persistent resource and command regions may be dense and interactive. Define where clicks control UI versus the world; do not assume opening UI pauses the simulation.
- **Menus/settings/inventory:** prioritize deliberate choices, consistent state feedback and the relevant navigation model. Allow justified opaque panels and readable labels.
- **Editor:** dock tool/library/inspector regions deliberately; keep camera/gizmo ownership distinct from focused controls.
- **Projected UI:** classify world attachment versus screen-space placement, visibility and interaction before choosing art. Record overlap/occlusion/offscreen decisions.
- **Results/loading:** show actual outcomes and progress. A decorative progress bar must not imply measured progress.

For each screen define: attachment anchor, background extent, content inset, safe-area source, UI-scale policy, critical glance region, and local-player viewport. Do not hardcode a universal gutter or declare an untested resolution supported.

## Inspected examples

Visually inspected on 2026-10-02 using the actual game images on Interface In Game. These five examples are a starter comparison, not a substitute for researching the current task.

| Screenshot | Visible observation | Transfer decision |
|---|---|---|
| [Valorant — Buy phase](https://interfaceingame.com/screenshots/valorant-buy-phase/) | Minimap near upper-left; team/time across top; health and abilities near lower center; much of the world remains visible. A translucent phase cue occupies the upper middle. | Use distinct stable information zones and state-specific notices for an action HUD. Do not turn every readout into a card or copy the notice into permanent chrome. |
| [League of Legends — Tower](https://interfaceingame.com/screenshots/league-of-legends-tower/) | Target information at upper-left; stats at upper-right; abilities/resources along the bottom; minimap at bottom-right; world health bars attached near entities. | Design several anchor families and distinguish screen HUD from spatial labels. Do not import its ornamental gold frames or copy its tiny screenshot text. |
| [Dota 2 — Game stats](https://interfaceingame.com/screenshots/dota-2-game-stats/) | A spectator scene has a left score table, upper team status, lower hero/ability region and bottom-right minimap. The table has consistent columns and row treatments. | Use a reusable row contract and contextual dense overlay. This spectator screenshot does not establish the live player's input behavior. |
| [Civilization VI — Great people](https://interfaceingame.com/screenshots/sid-meiers-civilization-vi-great-people/) | Top resources remain visible while a broad decision overlay repeats aligned category columns with common content/action placement. | A deliberate strategy decision can justify density and a stronger surface. Reuse one column/component contract; do not impose the overlay on a fast-action HUD or adopt embossed decoration. |
| [Trackmania Turbo — Countdown](https://interfaceingame.com/screenshots/trackmania-turbo-countdown-2/) | Corner time panels and lower readouts frame the racing scene; a large countdown is central during this state. | Prioritize timing and scene visibility. Central cues can be appropriate for a temporary state; do not infer that the same cue persists throughout the race. |

[Game UI Database](https://www.gameuidatabase.com/) could not be fetched by the text browser during this pass; no visual findings are attributed to it.

## Primary guidance

- [Xbox text-display guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101): rendered text and viewing context matter. Choose and verify the host's actual scale rather than treating a CSS size as sufficient evidence.
- [Xbox contrast guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102): evaluate against the least favorable underlying background. Transparent UI needs scene checks; a token pair alone does not establish readability.
- [Unreal safe-zone documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/umg-safe-zones-in-unreal-engine): an engine-specific example of device safe areas. Check the current host/platform contract instead of copying fixed percentages into a portable design.
