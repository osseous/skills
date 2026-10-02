# Components and Paper

Read before creating or materially changing visible components. Use the game's existing library and assets; engine, renderer, and framework choices belong to the project.

## Contract and registry

Map every visible element in the affected screen to a shared component and named variant. Build only what that screen needs. Keep tokens, component specification, Paper masters, and implementation references traceable in the existing design/feature doc.

| Component contract | Define precisely |
|---|---|
| Identity | Stable name, purpose, owner/source path, variants and relevant Paper node/master IDs |
| Geometry | Internal layout, spacing, size constraints, corner treatment, icon size, hit area and content expansion |
| Typography/color | Named roles, font asset/weight, numeric alignment, semantic color tokens and state meanings |
| Surface | Fill/alpha, border/outline, shadow/blur, clipping and layers; reason for each treatment, including an explicit absence |
| Content | Label/unit rules, icon/asset provenance, text wrapping/truncation, long/localized and empty cases |
| States | Default, hover, focus, pressed, selected, disabled and relevant pending/error/open/edit/drag states |
| Behavior | Supported input, entry/exit focus, activation, logical actions, commit/cancel and feedback |
| Context | HUD/menu/overlay/projected role, readability backgrounds, UI-scale and safe-area constraints |

Screens own external placement; components own internal styling and behavior. Exact values come from approved project tokens and measured requirements. Do not assign a fresh accent, radius, font or shadow to every instance.

Example: `SettingsRow / checkbox` maps to `PanelSurface / settings`, `Text / setting-label`, `Checkbox` and `Hint`. The checkbox owns its checked/focused/disabled states; the row owns alignment and help placement. Another screen reuses that contract or adds a documented density variant.

## Coverage checklist

Use only the entries present in the requested UI:

- Title, section, body, value, unit and hint typography roles.
- Buttons/menu items/tabs: default, focus, selection, press, disable and pending behavior.
- Panel/border/divider/backdrop variants with explicit surface purposes.
- Checkbox/toggle: unchecked, checked, focus, disabled and indeterminate if needed.
- Slider: track, thumb, value, steps, controller adjustment and dragging.
- Selector: closed face, open list, rows, selection, scrolling, focus and dismissal.
- Text/numeric field: caret, selection, editing, commit/cancel, invalid/pending states.
- Scroll region: thumb/track, scroll-following, clipping and input behavior.
- Hint/action prompt: current device glyph, placement, delay, dismissal and owner lifetime.
- Settings group, HUD readout, status meter, inventory row/tile and notification.
- Projected label/indicator: anchor, readability treatment, size/distance and overlap policy.

Style the whole control; a custom closed selector with a native open popup is incomplete. Keep real platform text editing/IME and semantic behavior where needed, under the game's designed presentation. Honor the host's accessibility requirements instead of inheriting browser chrome or imposing another game's exceptions.

## Surface decisions

| Treatment | Use only when it solves |
|---|---|
| No fill/container | Direct legible readout without unnecessary scene coverage |
| Translucent fill | Readability while retaining useful scene context; check changing backgrounds |
| Opaque panel | Sustained reading, comparison, settings, or intentional scene occlusion |
| Border/divider | Ambiguous grouping, a real control boundary, selection/focus, or evidenced art direction |
| Outline/shadow | Text/icon separation against changing backgrounds, or a meaningful layer distinction |
| Blur/texture | A verified readability/material need within the renderer's actual capability and performance budget |
| Motion | State transition, urgency, progress or interaction feedback with specified duration and dismissal |

Focus, hover, and selection are separate states. A border used for focus should not become permanent decoration on every value. Make each surface/token variant's reason explicit in the contract.

## Paper workflow

Use [Paper's official MCP documentation](https://paper.design/docs/mcp) to establish the connection and available operations; discover tools in the actual session instead of guessing names.

1. Inspect the target file, existing artboards/library, fonts, assets and current selection. Resolve the correct project before editing.
2. Create/update a named foundations and components sheet. Show affected variants and states over representative game-scene backgrounds.
3. Compose screen artboards from those definitions. Name instances and record their component/variant association; preserve edge anchors and content insets.
4. Prefer linked instances if the installed Paper version/tools support them. Verify propagation instead of assuming it.
5. If only groups/copies are available, keep named canonical masters plus an instance registry. Update all affected copies from one definition and compare them after every component change. In implementation, reuse actual code components; copied Paper groups alone do not establish reuse.
6. Inspect screenshots at the intended game dimensions and relevant states. Compare sibling instances for geometry, type, colors, opacity, borders, shadows and state consistency.
7. Carry the same tokens/component IDs into implementation and document intentional differences. Validate in the composed game; do not treat Paper HTML/CSS as proof of engine output.

Paper's [roadmap](https://paper.design/roadmap) lists component/slot and code-component work separately from MCP availability. Capabilities can change: verify the installed version rather than freezing that status into an assumed API.

If unavailable, continue research and the shared contract/library; report that no Paper artifact was authored. If the requested deliverable specifically requires Paper, leave that part pending and identify the connection needed. Installing this skill does not install/connect Paper or authorize unrelated canvas edits.
