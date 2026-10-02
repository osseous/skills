---
name: game-ui-design
description: Designs and reviews game UI from actual game references and a shared component system. Use for HUDs, menus, settings, inventories, strategy panels, game editors, projected UI, visual polish, and game UI prototypes in any engine or renderer.
---

# Game UI design

Build the interface for this game's player, world, art direction, and input devices. A web renderer or Paper's HTML/CSS canvas is an implementation surface; it does not make the product a website. User instructions and the host's documented requirements take precedence.

## 1. Discover the game

Read project instructions, the documentation index, relevant feature docs, and the existing design/component library before asking questions or choosing a style. Identify genre, art direction, screen purpose, gameplay pace, camera, target displays, viewing distance, input devices, and whether play continues underneath.

Classify the changed context: passive HUD, interactive gameplay HUD, menu, settings, inventory, editor, modal, results, loading, or projected/world UI. Strategy and MOBA HUDs can contain controls during play; racing and shooter readouts often remain passive. Determine input ownership per region instead of declaring every HUD noninteractive.

Preserve settled user decisions, existing game actions, and intentional assets. Ask only about material gaps that research and project files cannot resolve. Keep engine/framework/build details in the host's docs, not in this shared design skill.

## 2. Research before designing

For every task that changes visual or UX decisions, search [Game UI Database](https://www.gameuidatabase.com/) and [Interface In Game](https://interfaceingame.com/) for real games matching the screen's purpose, genre, and input context. Open and visually inspect actual screenshots; snippets, covers, the gallery website, and AI mockups do not establish game UI style.

For a new direction, compare several relevant screens and a contrasting example. For a small edit, search and inspect the relevant component/reference rather than repeating a full mood board. Read [research and game layout](references/research-and-game-layout.md) when establishing composition.

Record source URL, game, screen/state, observed pattern, and an adopt/adapt/reject decision tied to a player need. Distinguish visible evidence from inferred behavior. References guide hierarchy, density, geometry, palette, and material treatment; do not copy copyrighted assets or import mechanics absent from this game.

If an image is inaccessible, try the other gallery, the available browser, or an official gameplay capture. Do not claim inspection from text or guess the missing style. Continue discovery/specification and identify any design decision still lacking evidence.

## 3. Compose in game space

- Use the complete game scene as the canvas. Define the focal play area, permanent information zones, transient overlays, and relevant screen/world anchors before arranging controls.
- Dock bars, minimaps, catalogs, and inspectors to edges/corners when the context supports it. Never add a universal website gutter, centered max-width page, mobile-first shell, or card grid by habit.
- Separate background attachment, content padding, and platform/player safe area. A panel may bleed to the edge while text and controls remain inset. Do not interpret edge anchoring as clipping content.
- Adapt to supported aspect ratios, UI scale, localization, and viewing distance. Keep critical related readouts within a comfortable glance region on ultrawide displays. Reduce optional content or use deliberate paging/scrolling before shrinking readable type.
- Treat menus and deliberate decision screens independently from moment-to-moment HUDs. Higher density or a readable solid panel can be appropriate there. Do not impose minimal racing telemetry on strategy, RPG, or management interfaces.

## 4. Give every visual treatment a job

Never use stock web-template styling: embossed/neumorphic edges, glossy or rounded gradient buttons, decorative gradient borders, indiscriminate pills/cards, or generic purple/indigo accent palettes. Derive colors, type, and geometry from this game's authored identity and inspected references. A game whose documented palette includes purple keeps its meaningful colors; purple is not an automatic theme.

Start with hierarchy, alignment, type, and spacing. Add fill, transparency, border, outline, shadow, blur, texture, or motion only for a named purpose: scene readability, separation, state, interaction, spatial attachment, or evidenced game identity. No fake gauges, ornamental accent rules, or permanent animation without a purpose.

Specify treatments per component and state. A floating value can have no container, a settings panel can need an opaque surface, and a projected label can need a restrained contrast outline. Do not make everything glass, transparent, bordered, or shadowed. Test the treatment over actual scene content.

## 5. Establish components before composing screens

Read [components and Paper](references/components-and-paper.md). Reuse or extend one project-owned library. Define semantic tokens and exact component variants before assembling the affected screen; do not scaffold unrelated controls.

Cover every visible element used: titles/type roles, colors, buttons, borders, hints, scrollbars, checkboxes, sliders, selectors, fields, settings panels, in-game readouts, notifications, and projected UI. Components own their internal geometry and states; screens own placement and composition.

Create a component contract with token references, geometry, surface rationale, content rules, states, input behavior, and action outcomes. Repeated elements must use it consistently. Fix the shared definition or add a named justified variant instead of overriding arbitrary colors, radii, opacity, and typography at individual call sites.

Use Paper Design MCP for visual authoring when connected. Inspect its actual file, tools, and existing library; build a component/state sheet, then compose named instances and inspect screenshots. Verify whether linked components are supported. If not, maintain named masters, a component-to-instance registry, and synchronize copies from the canonical definition; do not call duplicated groups linked components.

If Paper is not connected, report it and continue authorized research, contracts, and code components. Do not invent a Paper result or silently substitute another design service. An explicitly requested Paper artifact remains pending until access exists.

For a durable design system, consider Google's [DESIGN.md](https://github.com/google-labs-code/design.md). Read [using DESIGN.md](references/using-design-md.md) only when creating/updating that artifact or integrating an existing one. Use its token/rationale approach across renderers; never inherit web layout or Material styling from its examples. Reuse the host's existing design document instead of creating a competing source.

## 6. Design behavior and verify the result

Specify focus, hover, selection, pressed, disabled, pending/error, and relevant open/edit/drag states. Design mouse, keyboard, gamepad, or touch journeys for the actual supported devices. Include entry focus, directional movement, activation, Back/cancel, modal containment, scrolling, and focus restoration where applicable.

Hints and device glyphs follow current actions and input ownership. A shared action-hint bar is useful in a navigable menu; permanent HUD legends are not mandatory. Style complete controls, including popup rows, thumb/track, caret, checks, and validation. A browser-native tooltip or popup must not choose the game's presentation.

Projected UI needs attachment, distance/size policy, overlap priority, occlusion/offscreen behavior, and input rules. Follow the host's rendering contract; do not swap renderers or fake a world-space solution to avoid a pipeline limitation.

Review affected component instances over bright, dark, and busy game scenes; target sizes/aspect ratios and UI scale; long/localized text; and the changed states and input transitions. Verify the return to play. A Paper/browser screenshot establishes design appearance, not runtime behavior.

Update the host's feature/component docs in the same change. Report sources and transfer decisions, components reused/extended, reasons for new treatments, checks actually performed, and remaining limitations. For implementation, use the host's integration workflow and preserve game-state authority.
